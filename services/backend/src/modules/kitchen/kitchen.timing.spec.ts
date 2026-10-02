import * as bcrypt from 'bcryptjs';

jest.mock('bcryptjs', () => {
  const actual = jest.requireActual('bcryptjs');
  return { ...actual, compare: jest.fn(actual.compare) };
});

import { JwtService } from '@nestjs/jwt';
import { CouriersEventsService } from '../couriers/couriers-events.service';
import { OrdersEventsService } from '../orders/orders-events.service';
import { KitchenService } from './kitchen.service';
import { KitchenEventsService } from './kitchen-events.service';

describe('KitchenService.authenticateByPin timing (C3)', () => {
  it('calls bcrypt.compare even when the terminal is unknown', async () => {
    const prisma: any = {
      kitchenTerminal: {
        findUnique: jest.fn().mockResolvedValue(null),
        findMany: jest.fn().mockResolvedValue([]),
      },
      branch: { findUnique: jest.fn() },
    };
    const jwt = new JwtService({ secret: 'timing-test' });
    const couriersEvents = {} as CouriersEventsService;
    const ordersEvents = {} as OrdersEventsService;
    const kitchenEvents = {} as KitchenEventsService;
    const service = new KitchenService(
      prisma,
      jwt,
      kitchenEvents,
      couriersEvents,
      ordersEvents,
    );

    (bcrypt.compare as jest.Mock).mockClear();

    await expect(
      service.authenticateByPin({ terminalCode: 'KDS-99', pin: '1234' }),
    ).rejects.toThrow();

    expect(bcrypt.compare).toHaveBeenCalledTimes(1);
  });
});
