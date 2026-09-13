import { JwtModule, JwtService } from '@nestjs/jwt';
import request from 'supertest';
import { PrismaService } from '../../prisma/prisma.service';
import { INestApplication, NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { OrderStatus } from '@prisma/client';
import { firstValueFrom, of } from 'rxjs';
import { AuthenticatedCustomer } from '../auth/auth.types';
import {
  JwtAuthGuard,
  OptionalJwtAuthGuard,
} from '../auth/guards/jwt-auth.guard';
import { KitchenJwtAuthGuard } from '../kitchen/guards/kitchen-jwt-auth.guard';
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
      .overrideGuard(KitchenJwtAuthGuard)
      .useValue({ canActivate: () => true })
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


describe('OrdersController — operational HTTP access', () => {
  let app: INestApplication;
  let jwt: JwtService;
  const service = {
    list: jest.fn(),
    getById: jest.fn(),
    updateStatus: jest.fn(),
    getKdsStream: jest.fn(),
  };
  const findUnique = jest.fn();
  const terminal = {
    id: 'terminal-id', code: 'KDS', name: 'Kitchen',
    branchId: 'authoritative-branch', isActive: true,
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    findUnique.mockResolvedValue(terminal);
    service.getKdsStream.mockReturnValue(of({ data: { orderId: ORDER_ID } }));
    const module = await Test.createTestingModule({
      imports: [JwtModule.register({ secret: 'operational-test-secret' })],
      controllers: [OrdersController],
      providers: [
        { provide: OrdersService, useValue: service },
        { provide: PrismaService, useValue: { kitchenTerminal: { findUnique } } },
      ],
    }).compile();
    app = module.createNestApplication();
    jwt = module.get(JwtService);
    await app.init();
  });

  afterEach(async () => { await app.close(); });

  it.each(['anonymous', 'COURIER', 'KITCHEN', 'missing-sub'])(
    'rejects order reads for %s', async (role) => {
      for (const path of ['/orders', `/orders/${ORDER_ID}`]) {
        const req = request(app.getHttpServer()).get(path);
        if (role !== 'anonymous') {
          const payload = role === 'missing-sub'
            ? { role: 'CUSTOMER', type: 'access' }
            : { sub: CUSTOMER.id, role, type: 'access' };
          req.set('Authorization', `Bearer ${jwt.sign(payload)}`);
        }
        await req.expect(401);
      }
      expect(service.list).not.toHaveBeenCalled();
      expect(service.getById).not.toHaveBeenCalled();
    },
  );

  it('takes ownership from the signed token instead of a query parameter', async () => {
    service.list.mockResolvedValue({ data: [] });
    service.getById.mockResolvedValue({ id: ORDER_ID });
    const token = jwt.sign({ sub: CUSTOMER.id, role: 'CUSTOMER', type: 'access' });
    await request(app.getHttpServer()).get('/orders?customerId=another-customer')
      .set('Authorization', `Bearer ${token}`).expect(200);
    expect(service.list).toHaveBeenCalledWith(expect.anything(), CUSTOMER.id);
    await request(app.getHttpServer()).get(`/orders/${ORDER_ID}`)
      .set('Authorization', `Bearer ${token}`).expect(200);
    expect(service.getById).toHaveBeenCalledWith(ORDER_ID, CUSTOMER.id);
  });

  it.each(['anonymous', 'CUSTOMER', 'COURIER', 'KITCHEN'])(
    'rejects legacy status mutation for %s without calling the service', async (role) => {
      const req = request(app.getHttpServer())
        .patch(`/orders/${ORDER_ID}/status`)
        .send({ status: 'CONFIRMED', changedBy: ORDER_ID });
      if (role !== 'anonymous') {
        req.set('Authorization', `Bearer ${jwt.sign({ sub: terminal.id, role, type: 'access' })}`);
      }
      const response = await req.expect(410);
      expect(response.body.code).toBe('LEGACY_STATUS_ENDPOINT_DISABLED');
      expect(service.updateStatus).not.toHaveBeenCalled();
    },
  );

  it.each(['anonymous', 'invalid', 'CUSTOMER', 'COURIER'])(
    'rejects KDS stream access for %s before opening a stream', async (role) => {
      const req = request(app.getHttpServer()).get('/orders/kds/stream');
      if (role !== 'anonymous') {
        const token = role === 'invalid' ? 'invalid' : jwt.sign({ sub: terminal.id, role, type: 'access' });
        req.set('Authorization', `Bearer ${token}`);
      }
      await req.expect(401);
      expect(service.getKdsStream).not.toHaveBeenCalled();
    },
  );

  it('rejects a deactivated terminal', async () => {
    findUnique.mockResolvedValue({ ...terminal, isActive: false });
    const token = jwt.sign({ sub: terminal.id, role: 'KITCHEN', type: 'access' });
    await request(app.getHttpServer()).get('/orders/kds/stream')
      .set('Authorization', `Bearer ${token}`).expect(401);
    expect(service.getKdsStream).not.toHaveBeenCalled();
  });

  it.each(['', '?branchId=another-branch'])(
    'scopes SSE to the database branch regardless of query %s', async (query) => {
      const token = jwt.sign({ sub: terminal.id, role: 'KITCHEN', type: 'access', branchId: 'stale-claim' });
      const response = await request(app.getHttpServer()).get(`/orders/kds/stream${query}`)
        .set('Authorization', `Bearer ${token}`).expect(200);
      expect(response.headers['content-type']).toContain('text/event-stream');
      expect(response.text).toContain(ORDER_ID);
      expect(service.getKdsStream).toHaveBeenCalledWith(terminal.branchId);
      expect(findUnique).toHaveBeenCalledWith({ where: { id: terminal.id } });
    },
  );
});
