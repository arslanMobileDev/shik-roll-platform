import { InjectQueue, OnWorkerEvent, Processor, WorkerHost } from '@nestjs/bullmq';
import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { Job, Queue } from 'bullmq';
import { PrismaService } from '../../prisma/prisma.service';
import { PHONE_RELEASE_WINDOW_DAYS } from '../customers/customers.config';

export const CUSTOMER_MAINTENANCE_QUEUE = 'customer-maintenance';
export const RELEASE_PENDING_PHONES_JOB = 'release-pending-phones';

/** Daily is ample for a 30-day window; the sweep is one indexed UPDATE. */
const SWEEP_INTERVAL_MS = 24 * 60 * 60 * 1000;

/**
 * 'customer-maintenance' worker: erases the phone of customers whose account
 * deletion is past the restore window.
 *
 * Deliberately scheduled rather than lazy. A lazy variant ("erase the number
 * when someone next signs in on it") would never fire for a deleted customer
 * who does not come back, leaving a real phone number in phone_pending_release
 * forever — which is the case 152-FZ cares about most. The restore lookup
 * keeps its own `deletedAt > cutoff` filter as the correctness backstop if this
 * job is not running (DISABLE_QUEUES, Redis down).
 */
@Injectable()
@Processor(CUSTOMER_MAINTENANCE_QUEUE)
export class CustomerMaintenanceProcessor
  extends WorkerHost
  implements OnModuleInit
{
  private readonly logger = new Logger(CustomerMaintenanceProcessor.name);

  constructor(
    private readonly prisma: PrismaService,
    @InjectQueue(CUSTOMER_MAINTENANCE_QUEUE)
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
        RELEASE_PENDING_PHONES_JOB,
        { every: SWEEP_INTERVAL_MS },
        { name: RELEASE_PENDING_PHONES_JOB },
      )
      .then(() => this.logger.log('Phone release sweep scheduled'))
      .catch((error: Error) =>
        this.logger.error(`Could not schedule the phone release sweep: ${error.message}`),
      );
  }

  async process(job: Job): Promise<void> {
    switch (job.name) {
      case RELEASE_PENDING_PHONES_JOB:
        await this.releasePendingPhones();
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
   * Drops the parked number of every account deleted longer ago than the
   * restore window, so the number can be re-registered and does not linger.
   * Returns the number of rows cleared.
   */
  async releasePendingPhones(): Promise<number> {
    const cutoff = new Date(
      Date.now() - PHONE_RELEASE_WINDOW_DAYS * 24 * 60 * 60 * 1000,
    );
    const { count } = await this.prisma.customer.updateMany({
      where: {
        phonePendingRelease: { not: null },
        deletedAt: { lt: cutoff },
      },
      data: { phonePendingRelease: null },
    });
    if (count > 0) {
      this.logger.log(
        `Released ${count} phone number(s) past the ${PHONE_RELEASE_WINDOW_DAYS}-day freeze window`,
      );
    }
    return count;
  }
}
