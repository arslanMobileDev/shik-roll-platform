import * as bcrypt from 'bcryptjs';

jest.mock('bcryptjs', () => {
  const actual = jest.requireActual('bcryptjs');
  return {
    ...actual,
    compare: jest.fn(actual.compare),
  };
});

import { constantTimePinCheck } from './pin-timing';

describe('constantTimePinCheck', () => {
  beforeEach(() => {
    (bcrypt.compare as jest.Mock).mockClear();
  });

  it('returns true for a matching PIN', async () => {
    const hash = await bcrypt.hash('1234', 4);
    await expect(constantTimePinCheck('1234', hash)).resolves.toBe(true);
  });

  it('returns false for a wrong PIN against a real hash', async () => {
    const hash = await bcrypt.hash('1234', 4);
    await expect(constantTimePinCheck('9999', hash)).resolves.toBe(false);
  });

  it('returns false when the hash is null', async () => {
    await expect(constantTimePinCheck('1234', null)).resolves.toBe(false);
  });

  it('returns false when the hash is undefined', async () => {
    await expect(constantTimePinCheck('1234', undefined)).resolves.toBe(false);
  });

  it('always calls bcrypt.compare, even when the hash is null', async () => {
    await constantTimePinCheck('1234', null);
    expect(bcrypt.compare).toHaveBeenCalledTimes(1);
  });

  it('passes a bcrypt-shaped dummy hash when the real hash is null', async () => {
    await constantTimePinCheck('1234', null);
    const [, hashArg] = (bcrypt.compare as jest.Mock).mock.calls[0];
    expect(typeof hashArg).toBe('string');
    expect((hashArg as string).startsWith('$2')).toBe(true);
  });
});
