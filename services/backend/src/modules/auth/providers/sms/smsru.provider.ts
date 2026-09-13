import { Injectable, Logger } from '@nestjs/common';
import { SmsProvider } from './sms.provider';

/**
 * SMS.ru HTTP API implementation (https://sms.ru/api).
 *
 * Sent via GET with `json=1`, so the response is a JSON object. Success is
 * `status: "OK"` (status_code 100). Any other status, a non-2xx HTTP code,
 * or a malformed payload throws — the caller logs and answers 5xx so the
 * client can retry with a fresh code.
 *
 * `SHIKROLL` sender id is registered in the SMS.ru cabinet; until the
 * operators approve it, the message goes out under the shared SMS.ru name
 * (same code, only the sender label differs).
 */
const SMSRU_API_URL = 'https://sms.ru/sms/send';
const SMSRU_REQUEST_TIMEOUT_MS = 10_000;

interface SmsRuResponse {
  status?: string;
  status_code?: number;
  status_text?: string;
}

@Injectable()
export class SmsRuProvider implements SmsProvider {
  private readonly logger = new Logger(SmsRuProvider.name);

  constructor(private readonly apiId: string) {}

  async send(phone: string, code: string, ip?: string): Promise<void> {
    const url = new URL(SMSRU_API_URL);
    url.searchParams.set('api_id', this.apiId);
    // SMS.ru expects the bare 11-digit number without the leading '+'.
    url.searchParams.set('to', phone.replace(/^\+/, ''));
    url.searchParams.set('msg', `Ваш код для входа в SHIK ROLL: ${code}`);
    url.searchParams.set('json', '1');
    // SMS.ru expects the end-user IP for anti-fraud. Pass -1 when the
    // request originates from a trusted server-side flow.
    url.searchParams.set('ip', ip ?? '-1');

    let response: Response;
    try {
      response = await fetch(url, {
        method: 'GET',
        signal: AbortSignal.timeout(SMSRU_REQUEST_TIMEOUT_MS),
      });
    } catch (error) {
      this.logger.error(`SMS.ru request failed for ${maskPhone(phone)}: ${String(error)}`);
      throw new Error('SMS delivery transport failure');
    }

    if (!response.ok) {
      this.logger.error(`SMS.ru HTTP ${response.status} for ${maskPhone(phone)}`);
      throw new Error(`SMS gateway responded with HTTP ${response.status}`);
    }

    const body = (await response.json()) as SmsRuResponse;
    if (body.status !== 'OK' || body.status_code !== 100) {
      // Never log the response body verbatim — it may echo the phone.
      this.logger.error(
        `SMS.ru rejected the message for ${maskPhone(phone)}: ${body.status_code ?? 'unknown'}`,
      );
      throw new Error(`SMS gateway rejected the message (${body.status_code ?? 'no code'})`);
    }

    this.logger.log(`OTP dispatched via SMS.ru for ${maskPhone(phone)}`);
  }
}

/** 152-FZ hygiene: production logs never carry the full phone. */
function maskPhone(phone: string): string {
  return phone.length > 4 ? `${phone.slice(0, 2)}******${phone.slice(-2)}` : '***';
}
