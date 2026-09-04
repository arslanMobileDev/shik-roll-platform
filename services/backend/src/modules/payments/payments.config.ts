/**
 * Payments bounded context configuration (env-driven, read once at module
 * load — same convention as the auth/queues modules).
 *
 *   PAYMENTS_PROVIDER          'yookassa' | 'mock'; when unset, YooKassa is
 *                              used only if both API keys are present,
 *                              otherwise the dev Mock provider is selected
 *   YOOKASSA_SHOP_ID           shopId of the ЮKassa shop (Банк ВТБ)
 *   YOOKASSA_SECRET_KEY        secret key for Basic auth
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
  process.env.YOOKASSA_RETURN_URL ?? 'https://shik-roll.ru/payments/return';
export const YOOKASSA_VAT_CODE = Number(process.env.YOOKASSA_VAT_CODE ?? 1);
export const YOOKASSA_TAX_SYSTEM_CODE = process.env.YOOKASSA_TAX_SYSTEM_CODE
  ? Number(process.env.YOOKASSA_TAX_SYSTEM_CODE)
  : null;

export function paymentsProviderMode(): PaymentsProviderMode {
  const explicit = process.env.PAYMENTS_PROVIDER;
  if (explicit === 'mock' || explicit === 'yookassa') return explicit;
  return YOOKASSA_SHOP_ID && YOOKASSA_SECRET_KEY ? 'yookassa' : 'mock';
}
