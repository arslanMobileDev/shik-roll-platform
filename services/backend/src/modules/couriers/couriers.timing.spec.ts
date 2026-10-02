import * as bcrypt from 'bcryptjs';

jest.mock('bcryptjs', () => {
  const actual = jest.requireActual('bcryptjs');
  return { ...actual, compare: jest.fn(actual.compare) };
});

import { JwtService } from '@nestjs/jwt';
import { CouriersService } from './couriers.service';
import { CouriersEventsService } from './couriers-events.service';

describe('CouriersService.authenticateByPin timing (C3)', () => {
  it('calls bcrypt.compare even when the courier is unknown', async () => {
    const prisma: any = {
      courier: { findUnique: jest.fn(), findMany: jest.fn().mockResolvedValue([]) },
      branch: { findFirst: jest.fn() },
      brand: { findFirst: jest.fn() },
      order: {
        findUnique: jest.fn(),
        findUniqueOrThrow: jest.fn(),
        findMany: jest.fn(),
        count: jest.fn(),
        updateMany: jest.fn(),
      },
      orderStatusHistory: { create: jest.fn() },
    };
    prisma.$transaction = jest.fn(async (arg: unknown) =>
      Array.isArray(arg)
        ? Promise.all(arg)
        : (arg as (tx: any) => unknown)(prisma),
    );
    const jwt = new JwtService({ secret: 'timing-test' });
    const events = {} as CouriersEventsService;
    const loyalty = {} as never;
    const service = new CouriersService(prisma, jwt, events, loyalty);

    (bcrypt.compare as jest.Mock).mockClear();

    await expect(
      service.authenticateByPin({ phone: '+79990000000', pin: '1234' }),
    ).rejects.toThrow();

    expect(bcrypt.compare).toHaveBeenCalledTimes(1);
  });
});
