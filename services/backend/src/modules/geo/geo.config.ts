/**
 * Geo bounded context configuration (env-driven, read once at module load —
 * same convention as payments/auth/queues).
 *
 *   YANDEX_GEOCODER_API_KEY    API key of the Yandex Geocoder (Bitwarden:
 *                              "Yandex Geocoder API key — DOSTERRA").
 *                              When unset, GeoService is a no-op and orders
 *                              are stored without coordinates.
 *   YANDEX_GEOCODER_API_URL    default https://geocode-maps.yandex.ru/1.x
 *   YANDEX_GEOCODER_TIMEOUT_MS request timeout, default 5000 ms
 */
export const YANDEX_GEOCODER_API_KEY =
  process.env.YANDEX_GEOCODER_API_KEY ?? '';

export const YANDEX_GEOCODER_API_URL =
  process.env.YANDEX_GEOCODER_API_URL ?? 'https://geocode-maps.yandex.ru/1.x';

export const YANDEX_GEOCODER_TIMEOUT_MS = Number(
  process.env.YANDEX_GEOCODER_TIMEOUT_MS ?? 5_000,
);

export function isGeocoderEnabled(): boolean {
  return YANDEX_GEOCODER_API_KEY.length > 0;
}
