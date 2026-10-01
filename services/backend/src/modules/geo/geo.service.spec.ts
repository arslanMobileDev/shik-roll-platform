import { GeoService } from './geo.service';

describe('GeoService', () => {
  const originalEnv = process.env.YANDEX_GEOCODER_API_KEY;
  const originalFetch = global.fetch;

  afterEach(() => {
    process.env.YANDEX_GEOCODER_API_KEY = originalEnv;
    global.fetch = originalFetch;
    jest.resetModules();
  });

  /**
   * Re-import GeoService after changing env: config module reads env once
   * at module load (same convention as payments/queues).
   */
  function importFresh(): typeof GeoService {
    let cls!: typeof GeoService;
    jest.isolateModules(() => {
      // eslint-disable-next-line @typescript-eslint/no-require-imports
      cls = require('./geo.service').GeoService;
    });
    return cls;
  }

  it('returns null when API key is not configured', async () => {
    delete process.env.YANDEX_GEOCODER_API_KEY;
    const Service = importFresh();
    const service = new Service();
    global.fetch = jest.fn();

    const result = await service.geocode('ул. Баумана, 58');

    expect(result).toBeNull();
    expect(global.fetch).not.toHaveBeenCalled();
  });

  it('returns null for empty / whitespace address', async () => {
    process.env.YANDEX_GEOCODER_API_KEY = 'test-key';
    const Service = importFresh();
    const service = new Service();
    global.fetch = jest.fn();

    expect(await service.geocode('')).toBeNull();
    expect(await service.geocode('   ')).toBeNull();
    expect(global.fetch).not.toHaveBeenCalled();
  });

  it('parses lon-first "pos" into latitude/longitude', async () => {
    process.env.YANDEX_GEOCODER_API_KEY = 'test-key';
    const Service = importFresh();
    const service = new Service();
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        response: {
          GeoObjectCollection: {
            featureMember: [
              { GeoObject: { Point: { pos: '49.1221 55.7893' } } },
            ],
          },
        },
      }),
    });

    const result = await service.geocode('ул. Баумана, 58');

    expect(result).toEqual({ latitude: 55.7893, longitude: 49.1221 });
  });

  it('returns null when geocoder returns no match', async () => {
    process.env.YANDEX_GEOCODER_API_KEY = 'test-key';
    const Service = importFresh();
    const service = new Service();
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        response: { GeoObjectCollection: { featureMember: [] } },
      }),
    });

    expect(await service.geocode('ул. Несуществующая')).toBeNull();
  });

  it('returns null on non-OK HTTP response', async () => {
    process.env.YANDEX_GEOCODER_API_KEY = 'test-key';
    const Service = importFresh();
    const service = new Service();
    global.fetch = jest.fn().mockResolvedValue({
      ok: false,
      status: 403,
    });

    expect(await service.geocode('ул. Баумана, 58')).toBeNull();
  });

  it('returns null when fetch throws (network down)', async () => {
    process.env.YANDEX_GEOCODER_API_KEY = 'test-key';
    const Service = importFresh();
    const service = new Service();
    global.fetch = jest.fn().mockRejectedValue(new Error('network down'));

    expect(await service.geocode('ул. Баумана, 58')).toBeNull();
  });

  it('returns null when response is malformed JSON', async () => {
    process.env.YANDEX_GEOCODER_API_KEY = 'test-key';
    const Service = importFresh();
    const service = new Service();
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => {
        throw new Error('not json');
      },
    });

    expect(await service.geocode('ул. Баумана, 58')).toBeNull();
  });

  it('adds ll/spn/rspn when bias is provided', async () => {
    process.env.YANDEX_GEOCODER_API_KEY = 'test-key';
    const Service = importFresh();
    const service = new Service();
    let capturedUrl = '';
    global.fetch = jest.fn().mockImplementation((url: string) => {
      capturedUrl = url;
      return Promise.resolve({
        ok: true,
        json: async () => ({
          response: {
            GeoObjectCollection: {
              featureMember: [
                { GeoObject: { Point: { pos: '49.1221 55.7893' } } },
              ],
            },
          },
        }),
      });
    });

    await service.geocode('ул. Баумана, 58', {
      latitude: 55.7887,
      longitude: 49.1221,
    });

    expect(capturedUrl).toContain('ll=49.1221%2C55.7887');
    expect(capturedUrl).toContain('spn=2%2C2');
    expect(capturedUrl).toContain('rspn=1');
  });

  it('respects custom spanDegrees', async () => {
    process.env.YANDEX_GEOCODER_API_KEY = 'test-key';
    const Service = importFresh();
    const service = new Service();
    let capturedUrl = '';
    global.fetch = jest.fn().mockImplementation((url: string) => {
      capturedUrl = url;
      return Promise.resolve({
        ok: true,
        json: async () => ({
          response: { GeoObjectCollection: { featureMember: [] } },
        }),
      });
    });

    await service.geocode('ул. Баумана, 58', {
      latitude: 55.7887,
      longitude: 49.1221,
      spanDegrees: 0.5,
    });

    expect(capturedUrl).toContain('spn=0.5%2C0.5');
  });

  it('omits ll/spn/rspn when bias is not provided', async () => {
    process.env.YANDEX_GEOCODER_API_KEY = 'test-key';
    const Service = importFresh();
    const service = new Service();
    let capturedUrl = '';
    global.fetch = jest.fn().mockImplementation((url: string) => {
      capturedUrl = url;
      return Promise.resolve({
        ok: true,
        json: async () => ({
          response: { GeoObjectCollection: { featureMember: [] } },
        }),
      });
    });

    await service.geocode('ул. Баумана, 58');

    expect(capturedUrl).not.toContain('ll=');
    expect(capturedUrl).not.toContain('rspn=');
  });

  it('returns null when coordinates are NaN', async () => {
    process.env.YANDEX_GEOCODER_API_KEY = 'test-key';
    const Service = importFresh();
    const service = new Service();
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        response: {
          GeoObjectCollection: {
            featureMember: [{ GeoObject: { Point: { pos: 'abc def' } } }],
          },
        },
      }),
    });

    expect(await service.geocode('ул. Баумана, 58')).toBeNull();
  });
});
