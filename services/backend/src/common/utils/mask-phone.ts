/**
 * 152-FZ hygiene: application logs carry the masked phone only, never the
 * full number.
 *
 * Every phone that reaches a log has been through a DTO validator that
 * normalises it to E.164 `+7XXXXXXXXXX` (see PHONE_PATTERN and
 * normalizeCourierPhone), so the mask keeps the country/operator prefix and
 * the last four digits: `+79822681958` becomes `+7982***1958`.
 *
 * A value in any other shape is masked away entirely rather than guessed at —
 * an unparseable phone must not leak because a validator was bypassed.
 */
export function maskPhone(phone: string): string {
  return /^\+7\d{10}$/.test(phone) ? `${phone.slice(0, 5)}***${phone.slice(-4)}` : '***';
}
