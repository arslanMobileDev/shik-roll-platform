import { ConflictException } from '@nestjs/common';
import { resolveLoginRow } from './resolve-login-row';

const ROW = { id: 'row-1', phone: '+79990000000' };

describe('resolveLoginRow', () => {
  it('looks the key up inside the declared tenant only', async () => {
    const byKey = jest.fn();
    const scoped = jest.fn().mockResolvedValue(ROW);

    const row = await resolveLoginRow({ id: 'tenant-1', code: 'SHIK_ROLL' }, byKey, scoped);

    expect(row).toBe(ROW);
    expect(scoped).toHaveBeenCalledWith('tenant-1');
    expect(byKey).not.toHaveBeenCalled();
  });

  it('falls back to the sole owner when the client declared no tenant', async () => {
    const row = await resolveLoginRow(
      undefined,
      jest.fn().mockResolvedValue([ROW]),
      jest.fn(),
    );

    expect(row).toBe(ROW);
  });

  it('returns null for an unknown key, leaving the caller its uniform 401', async () => {
    const row = await resolveLoginRow(
      undefined,
      jest.fn().mockResolvedValue([]),
      jest.fn(),
    );

    expect(row).toBeNull();
  });

  it('409s when several tenants own the key — the PIN cannot be checked yet', async () => {
    const scoped = jest.fn();

    await expect(
      resolveLoginRow(undefined, jest.fn().mockResolvedValue([ROW, ROW]), scoped),
    ).rejects.toBeInstanceOf(ConflictException);
    expect(scoped).not.toHaveBeenCalled();
  });
});
