import { Injectable, OnModuleDestroy } from '@nestjs/common';
import Redis from 'ioredis';
import { buildRedisConnection } from '../queues/queues.module';

/**
 * OTP storage port (BE: cache access through the Redis abstraction — rule 4).
 * Redis is used when REDIS_URL / REDIS_HOST is configured; otherwise an
 * in-memory map backs local development and tests. Codes are TTL-bounded
 * (default 3 minutes) in both implementations.
 */
export const OTP_STORE = Symbol('OTP_STORE');

export interface OtpStore {
  set(phone: string, code: string, ttlSeconds: number): Promise<void>;
  get(phone: string): Promise<string | null>;
  delete(phone: string): Promise<void>;
}

@Injectable()
export class InMemoryOtpStore implements OtpStore {
  private readonly entries = new Map<string, { code: string; expiresAt: number }>();

  set(phone: string, code: string, ttlSeconds: number): Promise<void> {
    this.entries.set(phone, { code, expiresAt: Date.now() + ttlSeconds * 1000 });
    return Promise.resolve();
  }

  get(phone: string): Promise<string | null> {
    const entry = this.entries.get(phone);
    if (!entry) return Promise.resolve(null);
    if (entry.expiresAt <= Date.now()) {
      this.entries.delete(phone);
      return Promise.resolve(null);
    }
    return Promise.resolve(entry.code);
  }

  delete(phone: string): Promise<void> {
    this.entries.delete(phone);
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

  async set(phone: string, code: string, ttlSeconds: number): Promise<void> {
    await this.client.set(this.key(phone), code, 'EX', ttlSeconds);
  }

  async get(phone: string): Promise<string | null> {
    return this.client.get(this.key(phone));
  }

  async delete(phone: string): Promise<void> {
    await this.client.del(this.key(phone));
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
