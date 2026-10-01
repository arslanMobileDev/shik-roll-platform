import { Injectable, Logger } from '@nestjs/common';
import {
  YANDEX_GEOCODER_API_KEY,
  YANDEX_GEOCODER_API_URL,
  YANDEX_GEOCODER_TIMEOUT_MS,
  isGeocoderEnabled,
} from './geo.config';

export interface GeocodedPoint {
  latitude: number;
  longitude: number;
}

/**
 * Optional hint that biases the search towards a region.
 *
 * Without it, Yandex Geocoder returns the first match globally —
 * "ул. Баумана, 58" is ambiguous (Казань vs Екатеринбург) and the
 * wrong city may win. Pass the branch coordinates to force the
 * geocoder to look near the branch.
 */
export interface GeocodeBias {
  latitude: number;
  longitude: number;
  /**
   * Search area half-width/half-height around the bias point.
   * Default: ~2 degrees (~200 km) — wide enough to cover a city
   * and its suburbs but not the whole country.
   */
  spanDegrees?: number;
}

interface YandexGeocoderResponse {
  response?: {
    GeoObjectCollection?: {
      featureMember?: Array<{
        GeoObject?: {
          Point?: {
            // "longitude latitude" — space-separated, lon FIRST
            pos?: string;
          };
        };
      }>;
    };
  };
}

const DEFAULT_SPAN_DEGREES = 2;

/**
 * Thin wrapper around the Yandex Geocoder HTTP API. Used to translate a
 * free-form delivery address into (lat, lon) so the courier app can drop
 * a marker on the map (ADR-1621).
 *
 * Failure policy: every error is logged and returned as `null` — a broken
 * geocoder must never block order creation. Addressless or geocoder-disabled
 * environments also return `null` and the order is stored with NULL
 * coordinates.
 */
@Injectable()
export class GeoService {
  private readonly logger = new Logger(GeoService.name);

  async geocode(
    address: string,
    bias?: GeocodeBias,
  ): Promise<GeocodedPoint | null> {
    const trimmed = address.trim();
    if (trimmed.length === 0) return null;

    if (!isGeocoderEnabled()) {
      this.logger.debug(
        'YANDEX_GEOCODER_API_KEY is not set — skipping geocoding',
      );
      return null;
    }

    const url = new URL(YANDEX_GEOCODER_API_URL);
    url.searchParams.set('apikey', YANDEX_GEOCODER_API_KEY);
    url.searchParams.set('geocode', trimmed);
    url.searchParams.set('format', 'json');
    url.searchParams.set('results', '1');
    url.searchParams.set('lang', 'ru_RU');

    if (bias) {
      const span = bias.spanDegrees ?? DEFAULT_SPAN_DEGREES;
      // Yandex expects "lon,lat" order for ll and "width,height" for spn.
      url.searchParams.set('ll', `${bias.longitude},${bias.latitude}`);
      url.searchParams.set('spn', `${span},${span}`);
      // rspn=1: restrict the search to the ll+spn bounding box.
      url.searchParams.set('rspn', '1');
    }

    let response: Response;
    try {
      response = await fetch(url.toString(), {
        signal: AbortSignal.timeout(YANDEX_GEOCODER_TIMEOUT_MS),
      });
    } catch (error) {
      this.logger.warn(
        `Geocoder unreachable for "${trimmed}": ${String(error)}`,
      );
      return null;
    }

    if (!response.ok) {
      this.logger.warn(
        `Geocoder rejected "${trimmed}": HTTP ${response.status}`,
      );
      return null;
    }

    try {
      const data = (await response.json()) as YandexGeocoderResponse;
      const pos =
        data.response?.GeoObjectCollection?.featureMember?.[0]?.GeoObject
          ?.Point?.pos;
      if (!pos) {
        this.logger.debug(`Geocoder returned no match for "${trimmed}"`);
        return null;
      }
      // "longitude latitude" — Yandex returns lon first
      const [lonStr, latStr] = pos.split(' ');
      const latitude = Number(latStr);
      const longitude = Number(lonStr);
      if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
        this.logger.warn(
          `Geocoder returned malformed coordinates for "${trimmed}": "${pos}"`,
        );
        return null;
      }
      return { latitude, longitude };
    } catch (error) {
      this.logger.warn(
        `Geocoder malformed response for "${trimmed}": ${String(error)}`,
      );
      return null;
    }
  }
}
