import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { JwtModule, JwtService } from '@nestjs/jwt';
import request from 'supertest';
import { PrismaService } from '../../prisma/prisma.service';
import { StaffAnalyticsController } from './analytics.controller';
import { AnalyticsService } from './analytics.service';

describe('Staff analytics HTTP contract', () => {
  let app: INestApplication;
  let jwt: JwtService;
  const revenue = jest.fn();
  const actor = { id: 'staff', phone: '+79990000000', role: 'OWNER', brandId: 'verified-brand', isActive: true };
  beforeEach(async () => {
    revenue.mockReset().mockResolvedValue({ summary: { total: 0 } });
    const module = await Test.createTestingModule({
      imports: [JwtModule.register({ secret: 'analytics-test' })],
      controllers: [StaffAnalyticsController],
      providers: [
        { provide: AnalyticsService, useValue: { revenue } },
        { provide: PrismaService, useValue: { staff: { findUnique: jest.fn().mockResolvedValue(actor) } } },
      ],
    }).compile();
    app = module.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
    jwt = module.get(JwtService);
    await app.init();
  });
  afterEach(() => app.close());
  const path = '/staff/analytics/revenue';
  it('rejects anonymous and customer requests', async () => {
    await request(app.getHttpServer()).get(path).expect(401);
    await request(app.getHttpServer()).get(path).set('Authorization', `Bearer ${jwt.sign({ sub: 'c', type: 'access', role: 'CUSTOMER' })}`).expect(401);
    expect(revenue).not.toHaveBeenCalled();
  });
  it('uses the verified staff context and strips a forged brandId query', async () => {
    const token = jwt.sign({ sub: actor.id, type: 'access', role: 'OWNER', brandId: 'stale-brand' });
    await request(app.getHttpServer()).get(path + '?brandId=foreign&period=month').set('Authorization', `Bearer ${token}`).expect(200);
    expect(revenue).toHaveBeenCalledWith(expect.objectContaining({ brandId: actor.brandId }), expect.objectContaining({ period: 'month' }));
    expect(revenue.mock.calls[0][1]).not.toHaveProperty('brandId');
  });
  it.each(['branchId=invalid', 'period=invalid', 'period=custom&dateFrom=bad', 'period=custom&dateTo=2026-01-01T12:00:00Z'])(
    'rejects invalid query %s', async query => {
      const token = jwt.sign({ sub: actor.id, type: 'access', role: 'OWNER' });
      await request(app.getHttpServer()).get(path + '?' + query).set('Authorization', `Bearer ${token}`).expect(400);
      expect(revenue).not.toHaveBeenCalled();
    },
  );
});
