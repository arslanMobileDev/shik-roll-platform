import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
  ServiceUnavailableException,
} from '@nestjs/common';
import { finalize, Observable } from 'rxjs';

/** Concurrent multipart uploads admitted per process (ADR-008). */
export const MAX_CONCURRENT_UPLOADS = 2;

/**
 * Admits at most MAX_CONCURRENT_UPLOADS multipart uploads per process BEFORE
 * the FileInterceptor buffers the request body into MemoryStorage. It must be
 * listed before FileInterceptor in @UseInterceptors so the body is never read
 * for rejected requests. The slot is released when the request observable
 * terminates for any reason (success, error, client disconnect). There is
 * intentionally no queue: an unbounded queue of 15 MiB buffers would defeat
 * the memory limit.
 */
@Injectable()
export class UploadAdmissionInterceptor implements NestInterceptor {
  private active = 0;

  intercept(_context: ExecutionContext, next: CallHandler): Observable<unknown> {
    if (this.active >= MAX_CONCURRENT_UPLOADS) {
      throw new ServiceUnavailableException({
        statusCode: 503,
        code: 'IMAGE_BUSY',
        message: 'Too many concurrent uploads; retry later',
      });
    }
    this.active++;
    return next.handle().pipe(
      finalize(() => {
        this.active--;
      }),
    );
  }
}
