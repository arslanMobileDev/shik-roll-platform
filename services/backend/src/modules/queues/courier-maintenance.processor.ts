import { InjectQueue, OnWorkerEvent, Processor, WorkerHost } from '@nestjs/bullmq';
import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { Job, Queue } from 'bullmq';
import { PrismaService } from '../../prisma/prisma.service';
import { COURIER_RESTORE_WINDOW_DAYS } from '../couriers/couriers.config';

export const COURIER_MAINTENANCE_QUEUE = 'courier-maintenance';
export const EXPIRE_DELETED_COURIERS_JOB = 'expire-deleted-couriers';

/** Daily is ample for a 7-day window: the sweep is one indexed DELETE. */
const SWEEP_INTERVAL_MS = 24 * 60 * 60 * 1000;

/**
 * 'courier-maintenance' worker: hard-deletes the row of every courier whose
 * self-deletion is past the restore window.
 *
 * Unlike the customer sweep, which writes a pending phone back to NULL, this one
 * deletes the row outright. A courier row carries a name, a phone and a PIN
 * hash, all of which the deletion deliberately keeps alive for the 7 days a
 * restore can still use them (see deleteOwnAccount). Overwriting them one by one
 * would need the row to stay for nothing — order history is the only thing
 * pointing at it, and orders.courier_id is ON DELETE SET NULL — so the deletion
 * is what closes the window, and the retained PII goes with it. Apple 5.1.1(v)
 * is satisfied by that, and only by that: until this job exists, a deleted
 * courier's data is kept indefinitely.
 *
 * Deliberately scheduled rather than lazy — same reasoning as the customer
 * sweep: a deleted courier who does not come back would never trigger a lazy
 * variant, which is exactly the case the retention rule is about. The restore
 * lookup keeps its own `deletedAt > cutoff` filter as the correctness backstop
 * when this job is not running (DISABLE_QUEUES, Redis down).
 */
@Injectable()
@Processor(COURIER_MAINTENANCE_QUEUE)
export class CourierMaintenanceProcessor extends WorkerHost implements OnModuleInit {
  private readonly logger = new Logger(CourierMaintenanceProcessor.name);

  constructor(
    private readonly prisma: PrismaService,
    @InjectQueue(COURIER_MAINTENANCE_QUEUE)
    private readonly queue: Queue,
  ) {
    super();
  }

  onModuleInit(): void {
    // Not awaited: upsertJobScheduler talks to Redis, and a Redis hiccup must
    // not hold up application boot. It is idempotent, so the next restart
    // registers the sweep again if this attempt failed.
    this.queue
      .upsertJobScheduler(
        EXPIRE_DELETED_COURIERS_JOB,
        { every: SWEEP_INTERVAL_MS },
        { name: EXPIRE_DELETED_COURIERS_JOB },
      )
      .then(() => this.logger.log('Courier expiry sweep scheduled'))
      .catch((error: Error) =>
        this.logger.error(`Could not schedule the courier expiry sweep: ${error.message}`),
      );
  }

  async process(job: Job): Promise<void> {
    switch (job.name) {
      case EXPIRE_DELETED_COURIERS_JOB:
        await this.expireDeletedCouriers();
        return;
      default:
        this.logger.warn(`Unknown job name: ${job.name}`);
    }
  }

  @OnWorkerEvent('failed')
  onFailed(job: Job, error: Error): void {
    const terminal = job.attemptsMade >= (job.opts.attempts ?? 1);
    this.logger.error(
      `Job ${job.name} (${job.id}) failed at attempt ${job.attemptsMade}` +
        `${terminal ? ' — attempts exhausted' : ', will retry'}: ${error.message}`,
      error.stack,
    );
  }

  /**
   * Deletes every courier whose restore window has closed. Returns the number of
   * rows burned.
   */
  async expireDeletedCouriers(): Promise<number> {
    const windowMs = COURIER_RESTORE_WINDOW_DAYS * 24 * 60 * 60 * 1000;
    const cutoff = new Date(Date.now() - windowMs);

    // Read first, delete second: deleteMany answers with a count only, and each
    // burned account has to leave a log line behind. `deletedAt < cutoff` is
    // also the whole filter for "self-deleted, and no longer restorable": NULL
    // never satisfies it, so a staff block (isActive false, deletedAt NULL) is
    // out of reach.
    const expired = await this.prisma.courier.findMany({
      where: { deletedAt: { lt: cutoff } },
      select: { id: true, deletedAt: true },
    });

    let burned = 0;
    for (const { id, deletedAt } of expired) {
      // Unreachable through the filter above; Prisma types the column nullable.
      if (!deletedAt) continue;

      // The window predicate rides on the DELETE as well, not just on the read:
      // a restore landing between the two statements clears deletedAt, and then
      // this matches nothing instead of burning an account that just came back.
      const { count } = await this.prisma.courier.deleteMany({
        where: { id, deletedAt: { lt: cutoff } },
      });
      if (count === 0) continue;

      burned += 1;
      this.logger.log(
        `Burned courier ${id} — deleted at ${deletedAt.toISOString()}, ` +
          `expiring at ${new Date(deletedAt.getTime() + windowMs).toISOString()}`,
      );
    }

    return burned;
  }
}
