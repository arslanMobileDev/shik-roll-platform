import { paymentsProviderMode } from './payments.config';

describe('paymentsProviderMode', () => {
  const original = { ...process.env };

  beforeEach(() => {
    process.env = { ...original };
    delete process.env.PAYMENTS_PROVIDER;
    delete process.env.YOOKASSA_MOCK;
    delete process.env.YOOKASSA_SHOP_ID;
    delete process.env.YOOKASSA_SECRET_KEY;
  });

  afterAll(() => {
    process.env = original;
  });

  it('fails fast when production credentials are missing', () => {
    process.env.NODE_ENV = 'production';
    expect(() => paymentsProviderMode()).toThrow(/YOOKASSA_SHOP_ID/);
  });

  it('rejects mock mode in production', () => {
    process.env.NODE_ENV = 'production';
    process.env.YOOKASSA_MOCK = 'true';
    expect(() => paymentsProviderMode()).toThrow(/forbidden in production/);
  });

  it('selects YooKassa in production with both credentials', () => {
    process.env.NODE_ENV = 'production';
    process.env.YOOKASSA_SHOP_ID = 'shop';
    process.env.YOOKASSA_SECRET_KEY = 'secret';
    expect(paymentsProviderMode()).toBe('yookassa');
  });

  it('keeps explicit mock mode available for tests and local development', () => {
    process.env.NODE_ENV = 'test';
    process.env.YOOKASSA_MOCK = 'true';
    expect(paymentsProviderMode()).toBe('mock');
  });
});
