import {
  assertKitchenConfig,
  kdsStatusEmulationEnabled,
} from './kitchen.config';

describe('kitchen config — ADR-1618 emulation guard', () => {
  const originalNodeEnv = process.env.NODE_ENV;

  afterEach(() => {
    delete process.env.KDS_STATUS_EMULATION_ENABLED;
    process.env.NODE_ENV = originalNodeEnv;
  });

  it('emulation is off unless explicitly enabled', () => {
    delete process.env.KDS_STATUS_EMULATION_ENABLED;
    expect(kdsStatusEmulationEnabled()).toBe(false);
    process.env.KDS_STATUS_EMULATION_ENABLED = 'false';
    expect(kdsStatusEmulationEnabled()).toBe(false);
    process.env.KDS_STATUS_EMULATION_ENABLED = 'true';
    expect(kdsStatusEmulationEnabled()).toBe(true);
  });

  it('stops startup when emulation is enabled in production', () => {
    process.env.KDS_STATUS_EMULATION_ENABLED = 'true';
    process.env.NODE_ENV = 'production';
    expect(() => assertKitchenConfig()).toThrow(/forbidden in production/);
  });

  it('allows emulation outside production', () => {
    process.env.KDS_STATUS_EMULATION_ENABLED = 'true';
    process.env.NODE_ENV = 'development';
    expect(() => assertKitchenConfig()).not.toThrow();
  });

  it('allows production without emulation', () => {
    delete process.env.KDS_STATUS_EMULATION_ENABLED;
    process.env.NODE_ENV = 'production';
    expect(() => assertKitchenConfig()).not.toThrow();
  });
});
