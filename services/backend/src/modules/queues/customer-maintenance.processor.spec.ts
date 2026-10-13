import { Job, Queue } from 'bullmq';
import { PrismaService } from '../../prisma/prisma.service';
import { PHONE_RELEASE_WINDOW_DAYS } from '../customers/customers.config';
import {
  CustomerMaintenanceProcessor,
  RELEASE_PENDING_PHONES_JOB,
} from './customer-maintenance.processor';

describe('CustomerMaintenanceProcessor', () => {
  let processor: CustomerMaintenanceProcessor;
  let prisma: { customer: { updateMany: jest.Mock } };
  let queue: { upsertJobScheduler: jest.Mock };

  beforeEach(() => {
    prisma = { customer: { updateMany: jest.fn().mockResolvedValue({ count: 0 }) } };
    queue = { upsertJobScheduler: jest.fn().mockResolvedValue(undefined) };
    processor = new CustomerMaintenanceProcessor(
      prisma as unknown as PrismaService,
      queue as unknown as Queue,
    );
  });

  it('registers the daily sweep under a stable scheduler id', async () => {
    processor.onModuleInit();
    await Promise.resolve();

    expect(queue.upsertJobScheduler).toHaveBeenCalledWith(
      RELEASE_PENDING_PHONES_JOB,
      { every: 24 * 60 * 60 * 1000 },
      { name: RELEASE_PENDING_PHONES_JOB },
    );
  });

  it('does not let a Redis failure during scheduling break application boot', async () => {
    queue.upsertJobScheduler.mockRejectedValue(new Error('redis down'));

    expect(() => processor.onModuleInit()).not.toThrow();
    await Promise.resolve();
  });

  it('erases parked numbers only once the freeze window has closed', async () => {
    prisma.customer.updateMany.mockResolvedValue({ count: 2 });
    const before = Date.now();

    await expect(processor.releasePendingPhones()).resolves.toBe(2);

    const { where } = prisma.customer.updateMany.mock.calls[0][0];
    expect(where.phonePendingRelease).toEqual({ not: null });
    const expected = PHONE_RELEASE_WINDOW_DAYS * 24 * 60 * 60 * 1000;
    expect(where.deletedAt.lt.getTime()).toBeGreaterThanOrEqual(before - expected);
    expect(where.deletedAt.lt.getTime()).toBeLessThanOrEqual(Date.now() - expected);
    expect(prisma.customer.updateMany.mock.calls[0][0].data).toEqual({
      phonePendingRelease: null,
    });
  });

  it('routes the scheduled job name to the sweep', async () => {
    const job = { name: RELEASE_PENDING_PHONES_JOB } as Job;

    await processor.process(job);

    expect(prisma.customer.updateMany).toHaveBeenCalled();
  });

  it('ignores an unknown job name instead of failing', async () => {
    await processor.process({ name: 'nope' } as Job);

    expect(prisma.customer.updateMany).not.toHaveBeenCalled();
  });
});
