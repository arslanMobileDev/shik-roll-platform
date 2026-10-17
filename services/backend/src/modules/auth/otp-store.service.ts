import { randomUUID } from 'node:crypto';
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
   * Resend cooldown: returns an owner token when the caller may send now (and
   * takes the slot), null while the previous send is still within the cooldown
   * window.
   */
  acquireSendSlot(phone: string, cooldownSeconds: number): Promise<string | null>;
  /**
   * Gives the slot back when the send it belongs to failed, so a gateway
   * outage does not lock the phone out for the whole cooldown. The token makes
   * the release compare-and-delete: a slow, stale send can never free a slot
   * taken by a newer request.
   */
  releaseSendSlot(phone: string, token: string): Promise<void>;
}

interface MemoryEntry extends OtpEntry {
  expiresAt: number;
}

@Injectable()
export class InMemoryOtpStore implements OtpStore {
  private readonly entries = new Map<string, MemoryEntry>();
  private readonly sendLocks = new Map<string, { token: string; until: number }>();

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

  acquireSendSlot(phone: string, cooldownSeconds: number): Promise<string | null> {
    const lock = this.sendLocks.get(phone);
    if (lock !== undefined && lock.until > Date.now()) {
      return Promise.resolve(null);
    }
    const token = randomUUID();
    this.sendLocks.set(phone, { token, until: Date.now() + cooldownSeconds * 1000 });
    return Promise.resolve(token);
  }

  releaseSendSlot(phone: string, token: string): Promise<void> {
    if (this.sendLocks.get(phone)?.token === token) {
      this.sendLocks.delete(phone);
    }
    return Promise.resolve();
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

  async acquireSendSlot(phone: string, cooldownSeconds: number): Promise<string | null> {
    // SET NX EX: atomic "take the slot only when no lock exists". The value is
    // the owner token, so release can tell whose slot it is deleting.
    const token = randomUUID();
    const result = await this.client.set(
      this.sendLockKey(phone),
      token,
      'EX',
      cooldownSeconds,
      'NX',
    );
    return result === 'OK' ? token : null;
  }

  async releaseSendSlot(phone: string, token: string): Promise<void> {
    // Compare-and-delete: only the request that took the slot may free it.
    await this.client.eval(
      "if redis.call('get', KEYS[1]) == ARGV[1] then return redis.call('del', KEYS[1]) else return 0 end",
      1,
      this.sendLockKey(phone),
      token,
    );
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
