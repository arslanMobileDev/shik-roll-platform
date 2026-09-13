/**
 * SMS delivery port (ADR-style bounded context: auth depends on the
 * abstraction, not on a concrete gateway). One implementation per provider
 * (SMS.ru, SMSC.ru, Telegram Gateway, ...), selected via SMS_PROVIDER.
 */
export const SMS_PROVIDER = Symbol('SMS_PROVIDER');

export interface SmsProvider {
  /**
   * Deliver the one-time code to the phone number. Must throw on transport
   * failure so the caller can surface a 5xx and the client can retry — the
   * OTP is already stored with its TTL and stays valid.
   */
  send(phone: string, code: string, ip?: string): Promise<void>;
}

/** Provider identifier for the first implementation. */
export const SMS_PROVIDER_SMSRU = 'smsru';
