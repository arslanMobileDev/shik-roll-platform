import { Injectable, OnModuleDestroy } from '@nestjs/common';
import Redis from 'ioredis';
import { buildRedisConnection } from '../queues/queues.module';

/**
 * OTP storage port (BE: cache access through the Redis abstraction — rule 4).
 * Redis is used when REDIS_URL / REDIS_HOST is configured; otherwise an
 * in-memory map backs local development and tests.
 *
 * Each entry is TTL-bounded (default 5 minutes) and tracks failed verify
 * attempts (max 5 per issued code). A separate send-lock key enforces the
 * resend cooldown (1 code per minute per phone).
 */
export const OTP_STORE = Symbol('OTP_STORE');

export interface OtpEntry {
  code: string;
  /** Number of failed verify attempts against this code. */
  attempts: number;
}

export interface OtpStore {
  set(phone: string, code: string, ttlSeconds: number): Promise<void>;
  get(phone: string): Promise<OtpEntry | null>;
  /** Increments the failed-attempt counter, preserving the TTL. Null when the entry is gone. */
  incrementAttempts(phone: string): Promise<number | null>;
  delete(phone: string): Promise<void>;
  /**
   * Resend cooldown: returns true when the caller may send now (and takes the
   * slot), false while the previous send is still within the cooldown window.
   */
  acquireSendSlot(phone: string, cooldownSeconds: number): Promise<boolean>;
}

interface MemoryEntry extends OtpEntry {
  expiresAt: number;
}

@Injectable()
export class InMemoryOtpStore implements OtpStore {
  private readonly entries = new Map<string, MemoryEntry>();
  private readonly sendLocks = new Map<string, number>();

  set(phone: string, code: string, ttlSeconds: number): Promise<void> {
    this.entries.set(phone, {
      code,
      attempts: 0,
      expiresAt: Date.now() + ttlSeconds * 1000,
    });
    return Promise.resolve();
  }

  get(phone: string): Promise<OtpEntry | null> {
    const entry = this.entries.get(phone);
    if (!entry) return Promise.resolve(null);
    if (entry.expiresAt <= Date.now()) {
      this.entries.delete(phone);
      return Promise.resolve(null);
    }
    return Promise.resolve({ code: entry.code, attempts: entry.attempts });
  }

  incrementAttempts(phone: string): Promise<number | null> {
    const entry = this.entries.get(phone);
    if (!entry || entry.expiresAt <= Date.now()) {
      this.entries.delete(phone);
      return Promise.resolve(null);
    }
    entry.attempts += 1;
    return Promise.resolve(entry.attempts);
  }

  delete(phone: string): Promise<void> {
    this.entries.delete(phone);
    return Promise.resolve();
  }

  acquireSendSlot(phone: string, cooldownSeconds: number): Promise<boolean> {
    const lockedUntil = this.sendLocks.get(phone);
    if (lockedUntil !== undefined && lockedUntil > Date.now()) {
      return Promise.resolve(false);
    }
    this.sendLocks.set(phone, Date.now() + cooldownSeconds * 1000);
    return Promise.resolve(true);
  }
}

@Injectable()
export class RedisOtpStore implements OtpStore, OnModuleDestroy {
  private readonly client: Redis;

  constructor() {
    this.client = new Redis(buildRedisConnection());
  }

  private key(phone: string): string {
    return `auth:otp:${phone}`;
  }

  private sendLockKey(phone: string): string {
    return `auth:otp:send-lock:${phone}`;
  }

  async set(phone: string, code: string, ttlSeconds: number): Promise<void> {
    const entry: OtpEntry = { code, attempts: 0 };
    await this.client.set(this.key(phone), JSON.stringify(entry), 'EX', ttlSeconds);
  }

  async get(phone: string): Promise<OtpEntry | null> {
    const raw = await this.client.get(this.key(phone));
    return raw ? (JSON.parse(raw) as OtpEntry) : null;
  }

  async incrementAttempts(phone: string): Promise<number | null> {
    const key = this.key(phone);
    const raw = await this.client.get(key);
    if (!raw) return null;
    const entry = JSON.parse(raw) as OtpEntry;
    entry.attempts += 1;
    // KEEPTTL: the code still expires on the original schedule.
    await this.client.set(key, JSON.stringify(entry), 'KEEPTTL');
    return entry.attempts;
  }

  async delete(phone: string): Promise<void> {
    await this.client.del(this.key(phone));
  }

  async acquireSendSlot(phone: string, cooldownSeconds: number): Promise<boolean> {
    // SET NX EX: atomic "take the slot only when no lock exists".
    const result = await this.client.set(
      this.sendLockKey(phone),
      '1',
      'EX',
      cooldownSeconds,
      'NX',
    );
    return result === 'OK';
  }

  async onModuleDestroy(): Promise<void> {
    await this.client.quit();
  }
}

/** Factory: Redis when configured, in-memory otherwise (dev/test). */
export function createOtpStore(): OtpStore {
  return process.env.REDIS_URL || process.env.REDIS_HOST
    ? new RedisOtpStore()
    : new InMemoryOtpStore();
}
