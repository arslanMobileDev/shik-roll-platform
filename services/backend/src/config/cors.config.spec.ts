import { allowedCorsOrigins } from './cors.config';

describe('allowedCorsOrigins', () => {
  it('accepts the three explicit production origins', () => {
    expect(
      allowedCorsOrigins({
        NODE_ENV: 'production',
        CORS_ORIGIN:
          'https://shik-roll.ru,https://api.shik-roll.ru,https://kds.shik-roll.ru',
      }),
    ).toEqual([
      'https://shik-roll.ru',
      'https://api.shik-roll.ru',
      'https://kds.shik-roll.ru',
    ]);
  });

  it.each([undefined, '', '*'])('rejects unsafe production value %s', (value) => {
    expect(() =>
      allowedCorsOrigins({ NODE_ENV: 'production', CORS_ORIGIN: value }),
    ).toThrow(/CORS_ORIGIN/);
  });

  it('supports the legacy plural variable during migration', () => {
    expect(
      allowedCorsOrigins({
        NODE_ENV: 'production',
        CORS_ORIGINS: 'https://shik-roll.ru',
      }),
    ).toEqual(['https://shik-roll.ru']);
  });

  it('remains permissive for local development without configuration', () => {
    expect(allowedCorsOrigins({ NODE_ENV: 'development' })).toBe(true);
  });
});
