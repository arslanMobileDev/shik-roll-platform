import { CallHandler, ExecutionContext } from '@nestjs/common';
import { delay, lastValueFrom, of, throwError } from 'rxjs';
import {
  MAX_CONCURRENT_UPLOADS,
  UploadAdmissionInterceptor,
} from './upload-admission.interceptor';

const context = {} as ExecutionContext;

describe('UploadAdmissionInterceptor (ADR-008)', () => {
  it('admits up to the limit, rejects the next one with 503, releases on completion', async () => {
    const interceptor = new UploadAdmissionInterceptor();
    const slow: CallHandler = { handle: () => of('ok').pipe(delay(60)) };

    const pending = Array.from({ length: MAX_CONCURRENT_UPLOADS }, () =>
      lastValueFrom(interceptor.intercept(context, slow)),
    );
    try {
      interceptor.intercept(context, slow);
      throw new Error('admission above the limit must throw');
    } catch (error) {
      expect(error).toMatchObject({ response: { code: 'IMAGE_BUSY' } });
    }

    await Promise.all(pending);
    // Slots are released after termination; a new upload is admitted again.
    await expect(
      lastValueFrom(interceptor.intercept(context, { handle: () => of('ok') })),
    ).resolves.toBe('ok');
  });

  it('releases the slot when the handler errors', async () => {
    const interceptor = new UploadAdmissionInterceptor();
    const failing: CallHandler = {
      handle: () => throwError(() => new Error('boom')),
    };
    for (let i = 0; i < MAX_CONCURRENT_UPLOADS + 3; i++) {
      await expect(
        lastValueFrom(interceptor.intercept(context, failing)),
      ).rejects.toThrow('boom');
    }
    // Never saturated: every attempt above was admitted, failed and released.
  });
});
