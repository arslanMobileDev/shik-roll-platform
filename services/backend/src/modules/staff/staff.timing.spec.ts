import * as bcrypt from 'bcryptjs';

jest.mock('bcryptjs', () => {
  const actual = jest.requireActual('bcryptjs');
  return { ...actual, compare: jest.fn(actual.compare) };
});

import { JwtService } from '@nestjs/jwt';
import { StaffService } from './staff.service';

describe('StaffService.authenticateByPin timing (C3)', () => {
  it('calls bcrypt.compare even when the phone is unknown', async () => {
    const prisma = {
      staff: {
        findUnique: jest.fn(),
        findMany: jest.fn().mockResolvedValue([]),
      },
    };
    const jwt = new JwtService({ secret: 'timing-test' });
    const service = new StaffService(prisma as never, jwt);

    (bcrypt.compare as jest.Mock).mockClear();

    await expect(
      service.authenticateByPin({ phone: '+79990000000', pin: '4321' }),
    ).rejects.toThrow();

    expect(bcrypt.compare).toHaveBeenCalledTimes(1);
  });
});
