/**
 * Payments bounded context configuration (env-driven, read once at module
 * load — same convention as the auth/queues modules).
 *
 *   PAYMENTS_PROVIDER          'yookassa' | 'mock' explicit override; when
 *                              unset, the Mock (sandbox) provider is forced
 *                              whenever NODE_ENV !== 'production' — the real
 *                              acquirer is only ever touched in production,
 *                              and only when both API keys are present
 *   YOOKASSA_SHOP_ID           shopId of the ЮKassa shop (Банк ВТБ) of
 *                              ИП Хаджимуратов М. М. — the merchant of record
 *                              on every 54-ФЗ receipt (set in the shop
 *                              cabinet, not sent in the API payload)
 *   YOOKASSA_SECRET_KEY        secret key for Basic auth
 *   YOOKASSA_MOCK              force the local provider when true
 *   YOOKASSA_API_URL           default https://api.yookassa.ru/v3
 *   YOOKASSA_RETURN_URL        page the customer returns to after payment
 *   YOOKASSA_VAT_CODE          НДС code for the 54-ФЗ receipt, default 1
 *                              (без НДС) — Атол Сигма fiscalisation
 *   YOOKASSA_TAX_SYSTEM_CODE   optional СНО code (1..6) for the receipt
 */
export type PaymentsProviderMode = 'yookassa' | 'mock';

export const YOOKASSA_SHOP_ID = process.env.YOOKASSA_SHOP_ID ?? '';
export const YOOKASSA_SECRET_KEY = process.env.YOOKASSA_SECRET_KEY ?? '';
export const YOOKASSA_API_URL =
  process.env.YOOKASSA_API_URL ?? 'https://api.yookassa.ru/v3';
export const YOOKASSA_RETURN_URL =
  process.env.YOOKASSA_RETURN_URL ?? 'https://shikroll.ru/order-status';
export const YOOKASSA_VAT_CODE = Number(process.env.YOOKASSA_VAT_CODE ?? 1);
export const YOOKASSA_TAX_SYSTEM_CODE = process.env.YOOKASSA_TAX_SYSTEM_CODE
  ? Number(process.env.YOOKASSA_TAX_SYSTEM_CODE)
  : null;

export function paymentsProviderMode(): PaymentsProviderMode {
  const production = process.env.NODE_ENV === 'production';
  const mockRequested =
    process.env.YOOKASSA_MOCK === 'true' ||
    process.env.PAYMENTS_PROVIDER === 'mock';
  if (production && mockRequested) {
    throw new Error('Mock payment provider is forbidden in production');
  }
  if (mockRequested) return 'mock';

  const explicit = process.env.PAYMENTS_PROVIDER;
  const hasCredentials = Boolean(
    process.env.YOOKASSA_SHOP_ID && process.env.YOOKASSA_SECRET_KEY,
  );
  if (!hasCredentials) {
    if (production || explicit === 'yookassa') {
      throw new Error(
        'YOOKASSA_SHOP_ID and YOOKASSA_SECRET_KEY are required for YooKassa',
      );
    }
    return 'mock';
  }
  return 'yookassa';
}
