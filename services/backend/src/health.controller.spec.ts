import { HealthController } from './health.controller';

describe('HealthController', () => {
  it('reports liveness without external dependencies', () => {
    const controller = new HealthController({} as never);
    expect(controller.live()).toEqual({ status: 'ok' });
  });

  it('checks PostgreSQL before reporting readiness', async () => {
    const prisma = { $queryRaw: jest.fn().mockResolvedValue([{ '?column?': 1 }]) };
    const controller = new HealthController(prisma as never);
    await expect(controller.ready()).resolves.toEqual({
      status: 'ok',
      database: 'up',
    });
    expect(prisma.$queryRaw).toHaveBeenCalledTimes(1);
  });
});
