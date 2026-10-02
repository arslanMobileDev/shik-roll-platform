import * as bcrypt from 'bcryptjs';

jest.mock('bcryptjs', () => {
  const actual = jest.requireActual('bcryptjs');
  return { ...actual, compare: jest.fn(actual.compare) };
});

import { JwtService } from '@nestjs/jwt';
import { CouriersService } from './couriers.service';
import { CouriersEventsService } from './couriers-events.service';

describe('CouriersService.authenticateByPin timing (C3)', () => {
  function makeService(rows: unknown[]) {
    const prisma: any = {
      courier: {
        findUnique: jest.fn(),
        findMany: jest.fn().mockResolvedValue(rows),
        update: jest.fn(),
      },
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
    return new CouriersService(prisma, jwt, events, loyalty);
  }

  it('calls bcrypt.compare even when the courier is unknown', async () => {
    const service = makeService([]);

    (bcrypt.compare as jest.Mock).mockClear();

    await expect(
      service.authenticateByPin({ phone: '+79990000000', pin: '1234' }),
    ).rejects.toThrow();

    expect(bcrypt.compare).toHaveBeenCalledTimes(1);
  });

  it('pays the dummy bcrypt when a legacy plaintext row gets a wrong PIN', async () => {
    const legacy = {
      id: 'c1',
      phone: '+79990000001',
      pinHash: '1234',
      isActive: true,
    };
    const service = makeService([legacy]);

    (bcrypt.compare as jest.Mock).mockClear();

    await expect(
      service.authenticateByPin({ phone: legacy.phone, pin: '9999' }),
    ).rejects.toThrow();

    expect(bcrypt.compare).toHaveBeenCalledTimes(1);
    const [, hash] = (bcrypt.compare as jest.Mock).mock.calls[0];
    expect(hash).not.toBe(legacy.pinHash);
    expect(hash).toMatch(/^\$2[aby]\$/);
  });
});
