import { NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { OrderStatus } from '@prisma/client';
import { firstValueFrom, of } from 'rxjs';
import { AuthenticatedCustomer } from '../auth/auth.types';
import {
  JwtAuthGuard,
  OptionalJwtAuthGuard,
} from '../auth/guards/jwt-auth.guard';
import { OrdersController } from './orders.controller';
import { OrdersService } from './orders.service';

const ORDER_ID = '55555555-5555-5555-5555-555555555555';
const CUSTOMER: AuthenticatedCustomer = {
  id: '10101010-1010-1010-1010-101010101010',
  phone: '+79000000000',
  role: 'CUSTOMER',
};

describe('OrdersController — tracking stream', () => {
  let controller: OrdersController;
  let service: { getTrackingStream: jest.Mock };

  beforeEach(async () => {
    service = { getTrackingStream: jest.fn() };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [OrdersController],
      providers: [{ provide: OrdersService, useValue: service }],
    })
      // Token verification is covered by the auth module specs; here the
      // customer is injected straight into the request context.
      .overrideGuard(JwtAuthGuard)
      .useValue({ canActivate: () => true })
      .overrideGuard(OptionalJwtAuthGuard)
      .useValue({ canActivate: () => true })
      .compile();

    controller = module.get(OrdersController);
  });

  it('returns the tracking stream scoped to the requesting customer', async () => {
    const snapshot = {
      data: {
        orderId: ORDER_ID,
        status: OrderStatus.NEW,
        courierId: null,
        version: 1,
        estimatedReadyAt: null,
        timestamp: new Date().toISOString(),
      },
    };
    service.getTrackingStream.mockResolvedValue(of(snapshot));

    const stream = await controller.trackOrder(ORDER_ID, CUSTOMER);

    expect(service.getTrackingStream).toHaveBeenCalledWith(ORDER_ID, CUSTOMER.id);
    const first = await firstValueFrom(stream);
    expect(first.data).toMatchObject({ orderId: ORDER_ID, status: OrderStatus.NEW });
  });

  it('propagates ORDER_NOT_FOUND before the stream is opened', async () => {
    service.getTrackingStream.mockRejectedValue(
      new NotFoundException({
        statusCode: 404,
        code: 'ORDER_NOT_FOUND',
        message: `Order ${ORDER_ID} not found`,
      }),
    );

    await expect(controller.trackOrder(ORDER_ID, CUSTOMER)).rejects.toMatchObject({
      response: { code: 'ORDER_NOT_FOUND' },
    });
  });
});
