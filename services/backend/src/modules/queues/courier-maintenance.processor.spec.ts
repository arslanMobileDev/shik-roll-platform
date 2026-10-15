import { Job, Queue } from 'bullmq';
import { PrismaService } from '../../prisma/prisma.service';
import { COURIER_RESTORE_WINDOW_DAYS } from '../couriers/couriers.config';
import {
  CourierMaintenanceProcessor,
  EXPIRE_DELETED_COURIERS_JOB,
} from './courier-maintenance.processor';

describe('CourierMaintenanceProcessor', () => {
  let processor: CourierMaintenanceProcessor;
  let prisma: {
    courier: { findMany: jest.Mock; deleteMany: jest.Mock };
  };
  let queue: { upsertJobScheduler: jest.Mock };

  const windowMs = COURIER_RESTORE_WINDOW_DAYS * 24 * 60 * 60 * 1000;
  const daysAgo = (days: number) => new Date(Date.now() - days * 24 * 60 * 60 * 1000);

  beforeEach(() => {
    prisma = {
      courier: {
        findMany: jest.fn().mockResolvedValue([]),
        deleteMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
    };
    queue = { upsertJobScheduler: jest.fn().mockResolvedValue(undefined) };
    processor = new CourierMaintenanceProcessor(
      prisma as unknown as PrismaService,
      queue as unknown as Queue,
    );
  });

  it('registers the daily sweep under a stable scheduler id', async () => {
    processor.onModuleInit();
    await Promise.resolve();

    expect(queue.upsertJobScheduler).toHaveBeenCalledWith(
      EXPIRE_DELETED_COURIERS_JOB,
      { every: 24 * 60 * 60 * 1000 },
      { name: EXPIRE_DELETED_COURIERS_JOB },
    );
  });

  it('does not let a Redis failure during scheduling break application boot', async () => {
    queue.upsertJobScheduler.mockRejectedValue(new Error('redis down'));

    expect(() => processor.onModuleInit()).not.toThrow();
    await Promise.resolve();
  });

  it('selects only rows deleted longer ago than the restore window', async () => {
    const before = Date.now();

    await processor.expireDeletedCouriers();

    const { where } = prisma.courier.findMany.mock.calls[0][0];
    expect(prisma.courier.findMany.mock.calls[0][0].select).toEqual({
      id: true,
      deletedAt: true,
    });
    expect(where.deletedAt.lt.getTime()).toBeGreaterThanOrEqual(before - windowMs);
    expect(where.deletedAt.lt.getTime()).toBeLessThanOrEqual(Date.now() - windowMs);
  });

  it('burns the expired rows and spares one restored between the read and the delete', async () => {
    const expired = { id: 'expired', deletedAt: daysAgo(8) };
    // Read as expired too — its deletedAt is cleared in the database while the
    // sweep is between the two statements, which is why its DELETE matches
    // nothing and the account that just came back survives.
    const restoredMidSweep = { id: 'restored', deletedAt: daysAgo(8) };
    prisma.courier.findMany.mockResolvedValue([expired, restoredMidSweep]);
    prisma.courier.deleteMany
      .mockResolvedValueOnce({ count: 1 })
      .mockResolvedValueOnce({ count: 0 });

    await expect(processor.expireDeletedCouriers()).resolves.toBe(1);

    expect(prisma.courier.deleteMany).toHaveBeenCalledTimes(2);
    const { where } = prisma.courier.deleteMany.mock.calls[0][0];
    expect(where.id).toBe(expired.id);
    // The window predicate has to ride on the DELETE itself — without it the
    // account restored mid-sweep would be burned.
    expect(where.deletedAt.lt.getTime()).toBeLessThanOrEqual(Date.now() - windowMs);
  });

  it('leaves the rows alone when nothing is past the window', async () => {
    prisma.courier.findMany.mockResolvedValue([]);

    await expect(processor.expireDeletedCouriers()).resolves.toBe(0);
    expect(prisma.courier.deleteMany).not.toHaveBeenCalled();
  });

  it('routes the scheduled job name to the sweep', async () => {
    const job = { name: EXPIRE_DELETED_COURIERS_JOB } as Job;

    await processor.process(job);

    expect(prisma.courier.findMany).toHaveBeenCalled();
  });

  it('ignores an unknown job name instead of failing', async () => {
    await processor.process({ name: 'nope' } as Job);

    expect(prisma.courier.findMany).not.toHaveBeenCalled();
  });
});
