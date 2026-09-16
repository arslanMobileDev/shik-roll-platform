import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { JwtModule, JwtService } from '@nestjs/jwt';
import { Prisma } from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import request from 'supertest';
import { PrismaService } from '../../prisma/prisma.service';
import { StaffCouriersController } from './staff-couriers.controller';

const branchId = '904331fe-5efe-4ca8-9c17-ceccc6dd3839';
const courierId = 'bd42c97c-334b-46da-8f84-009907d58aa1';
const brandId = 'b9567a9b-fd72-482e-9c06-d6d144518f11';
const body = { name: 'Иван', phone: '89280000000', pin: '1234', branchId };

describe('StaffCouriersController HTTP contract', () => {
  let app: INestApplication;
  let jwt: JwtService;
  let actor: { id: string; role: string; phone: string; brandId: string; isActive: boolean };
  let row: Record<string, unknown>;
  let db: any;
  const safe = (select: Record<string, boolean>) => Object.fromEntries(Object.keys(select).map(key => [key, row[key]]));
  beforeEach(async () => {
    actor = { id: 'owner', role: 'OWNER', phone: '+79990000000', brandId, isActive: true };
    row = { id: courierId, name: 'Иван', phone: '+79280000000', pinHash: 'private', brandId, branchId, isActive: true, isAvailable: false, createdAt: new Date('2026-09-16T09:00:00Z') };
    db = {
      staff: { findUnique: jest.fn().mockImplementation(async () => actor) },
      branch: { findFirst: jest.fn().mockResolvedValue({ id: branchId }) },
      courier: {
        findMany: jest.fn().mockImplementation(async ({ select }) => [safe(select)]),
        findFirst: jest.fn().mockResolvedValue({ branchId }),
        create: jest.fn().mockImplementation(async ({ data, select }) => { Object.assign(row, data); return safe(select); }),
        updateMany: jest.fn().mockImplementation(async ({ data }) => { Object.assign(row, data); return { count: 1 }; }),
        findFirstOrThrow: jest.fn().mockImplementation(async ({ select }) => safe(select)),
      },
    };
    db.$transaction = jest.fn(fn => fn(db));
    const module = await Test.createTestingModule({
      imports: [JwtModule.register({ secret: 'courier-staff-test' })],
      controllers: [StaffCouriersController],
      providers: [{ provide: PrismaService, useValue: db }],
    }).compile();
    app = module.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
    jwt = module.get(JwtService);
    await app.init();
  });
  afterEach(() => app.close());
  const token = () => `Bearer ${jwt.sign({ sub: 'owner', role: 'OWNER', type: 'access', brandId: 'untrusted-brand' })}`;
  const paths = [['get', `/staff/couriers?branchId=${branchId}`], ['post', '/staff/couriers'], ['patch', `/staff/couriers/${courierId}`], ['delete', `/staff/couriers/${courierId}`]];
  it.each(paths)('%s %s rejects missing bearer', async (method, path) => {
    await (request(app.getHttpServer()) as any)[method](path).expect(401);
  });
  it.each(paths)('%s %s rejects database MANAGER even with OWNER token claim', async (method, path) => {
    actor.role = 'MANAGER';
    await (request(app.getHttpServer()) as any)[method](path).set('Authorization', token()).send(body).expect(403);
  });
  it.each([
    { ...body, name: '  ' }, { ...body, name: 'x'.repeat(101) },
    { ...body, pin: '123' }, { ...body, pin: '123456789' },
    { ...body, phone: '+12345' }, { ...body, phone: 'letters' },
    { ...body, branchId: 'invalid' }, { ...body, pin: null },
  ])('validates creation body %#', async data => {
    await request(app.getHttpServer()).post('/staff/couriers').set('Authorization', token()).send(data).expect(400);
    expect(db.courier.create).not.toHaveBeenCalled();
  });
  it.each(['89280000000', '+79280000000', '9280000000', '+7 (928) 000-00-00'])('normalizes %s and hashes PIN with cost 12', async phone => {
    const response = await request(app.getHttpServer()).post('/staff/couriers').set('Authorization', token()).send({ ...body, phone, brandId: 'forged' }).expect(200);
    expect(response.body.phone).toBe('+79280000000');
    expect(response.body).not.toHaveProperty('pinHash');
    expect(Object.keys(response.body).sort()).toEqual(['id','name','phone','branchId','isActive','isAvailable','createdAt'].sort());
    const data = db.courier.create.mock.calls[0][0].data;
    expect(data.brandId).toBe(brandId);
    expect(bcrypt.getRounds(data.pinHash)).toBe(12);
    expect(await bcrypt.compare('1234', data.pinHash)).toBe(true);
  });
  it('lists within verified brand and selected branch without PIN hashes', async () => {
    actor.role = 'DEVELOPER';
    const response = await request(app.getHttpServer()).get('/staff/couriers').query({ branchId }).set('Authorization', token()).expect(200);
    expect(response.body[0]).not.toHaveProperty('pinHash');
    expect(db.courier.findMany.mock.calls[0][0].where).toEqual({ brandId, branchId });
    expect(db.branch.findFirst.mock.calls[0][0].where.brandBranches).toEqual({ some: { brandId } });
  });
  it('updates name/PIN while preserving availability and immutable phone', async () => {
    await request(app.getHttpServer()).patch(`/staff/couriers/${courierId}`).set('Authorization', token()).send({ name: ' Новое имя ', pin: '5678', isAvailable: true, phone: '+79999999999' }).expect(200);
    expect(row.name).toBe('Новое имя'); expect(row.phone).toBe('+79280000000'); expect(row.isAvailable).toBe(false);
    expect(await bcrypt.compare('5678', row.pinHash as string)).toBe(true);
    expect(db.courier.updateMany.mock.calls[0][0].where).toEqual({ id: courierId, brandId });
  });
  it('DELETE blocks and PATCH unblocks without changing busy state', async () => {
    const response = await request(app.getHttpServer()).delete(`/staff/couriers/${courierId}`).set('Authorization', token()).expect(200);
    expect(response.body).toMatchObject({ isActive: false, isAvailable: false });
    await request(app.getHttpServer()).patch(`/staff/couriers/${courierId}`).set('Authorization', token()).send({ isActive: true }).expect(200);
    expect(row.isActive).toBe(true); expect(row.isAvailable).toBe(false);
    expect(db.courier.updateMany.mock.calls[1][0].data).toEqual({ isActive: true });
  });
  it.each([{ name: null }, { pin: null }, { isActive: null }, { isActive: 'false' }, { name: '' }])('rejects invalid optional update values %#', async data => {
    await request(app.getHttpServer()).patch(`/staff/couriers/${courierId}`).set('Authorization', token()).send(data).expect(400);
  });
  it('maps P2002 to 409', async () => {
    db.courier.create.mockRejectedValue(new Prisma.PrismaClientKnownRequestError('duplicate', { code: 'P2002', clientVersion: 'test' }));
    await request(app.getHttpServer()).post('/staff/couriers').set('Authorization', token()).send(body).expect(409);
  });
  it('rejects foreign branches and couriers before mutation', async () => {
    db.branch.findFirst.mockResolvedValue(null);
    await request(app.getHttpServer()).post('/staff/couriers').set('Authorization', token()).send(body).expect(404);
    await request(app.getHttpServer()).get('/staff/couriers').query({ branchId }).set('Authorization', token()).expect(404);
    db.courier.findFirst.mockResolvedValue(null);
    await request(app.getHttpServer()).patch(`/staff/couriers/${courierId}`).set('Authorization', token()).send({ isActive: false }).expect(404);
    expect(db.courier.create).not.toHaveBeenCalled(); expect(db.courier.updateMany).not.toHaveBeenCalled();
  });
  it('requires a valid branch UUID and courier UUID', async () => {
    await request(app.getHttpServer()).get('/staff/couriers').set('Authorization', token()).expect(400);
    await request(app.getHttpServer()).patch('/staff/couriers/bad-id').set('Authorization', token()).send({ name: 'Иван' }).expect(400);
  });
});
