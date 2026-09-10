import {
  assertKitchenConfig,
} from './kitchen.config';

describe('kitchen config — automatic status simulation guard', () => {
  afterEach(() => {
    delete process.env.KDS_STATUS_EMULATION_ENABLED;
    delete process.env.ORDER_AUTO_STATUS_ADVANCE_ENABLED;
  });

  it('rejects the old KDS emulation flag in every environment', () => {
    process.env.KDS_STATUS_EMULATION_ENABLED = 'true';
    expect(() => assertKitchenConfig()).toThrow(/simulation was removed/);
  });

  it('rejects the old worker auto-advance flag in every environment', () => {
    process.env.ORDER_AUTO_STATUS_ADVANCE_ENABLED = 'true';
    expect(() => assertKitchenConfig()).toThrow(/simulation was removed/);
  });

  it('allows startup when both legacy flags are absent or false', () => {
    process.env.KDS_STATUS_EMULATION_ENABLED = 'false';
    process.env.ORDER_AUTO_STATUS_ADVANCE_ENABLED = 'false';
    expect(() => assertKitchenConfig()).not.toThrow();
  });
});
