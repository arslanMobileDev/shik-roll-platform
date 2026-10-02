import * as bcrypt from 'bcryptjs';

jest.mock('bcryptjs', () => {
  const actual = jest.requireActual('bcryptjs');
  return { ...actual, compare: jest.fn(actual.compare) };
});

import { JwtService } from '@nestjs/jwt';
import { CooksService } from './cooks.service';

describe('CooksService.login timing (C3)', () => {
  it('calls bcrypt.compare even when the cook is unknown', async () => {
    const db: any = {
      branch: {
        findFirst: jest.fn(),
        findUniqueOrThrow: jest.fn(),
      },
      cook: {
        findUnique: jest.fn().mockResolvedValue(null),
        findUniqueOrThrow: jest.fn(),
        create: jest.fn(),
        findFirst: jest.fn(),
        update: jest.fn(),
      },
      kitchenTerminal: { findUniqueOrThrow: jest.fn() },
      cookShift: {
        findFirst: jest.fn(),
        create: jest.fn(),
        updateMany: jest.fn(),
        findUnique: jest.fn(),
        findUniqueOrThrow: jest.fn(),
      },
      $executeRaw: jest.fn(),
      $queryRaw: jest.fn(),
    };
    db.$transaction = jest.fn((fn: any) => fn(db));
    const jwt = new JwtService({ secret: 'timing-test' });
    const service = new CooksService(db, jwt);

    const terminal = {
      id: 'terminal',
      tenantId: 'tenant',
      branchId: 'branch',
    } as any;

    (bcrypt.compare as jest.Mock).mockClear();

    await expect(
      service.login(terminal, { phone: '+79990000000', pin: '1234' }),
    ).rejects.toThrow();

    expect(bcrypt.compare).toHaveBeenCalledTimes(1);
  });
});
