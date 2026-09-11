import {
  BadRequestException,
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
  PayloadTooLargeException,
  UnsupportedMediaTypeException,
} from '@nestjs/common';
import multer, { memoryStorage, MulterError } from 'multer';
import { Observable } from 'rxjs';
import { IMAGE_MIMES, MAX_IMAGE_BYTES } from './image.service';

/**
 * Multipart boundary for POST /uploads/menu: one `file` part buffered in
 * MemoryStorage. Multer is invoked directly instead of Nest's FileInterceptor
 * because @nestjs/platform-express converts MulterError into generic
 * BadRequestException/PayloadTooLargeException without the API `code`
 * contract — and it does so before any exception filter runs. Mapping is done
 * here: LIMIT_FILE_SIZE -> 413 IMAGE_TOO_LARGE; extra files/fields/parts and
 * other multipart limit violations -> 400 UPLOAD_MULTIPART_INVALID;
 * fileFilter rejections keep their own HttpException contract (415).
 *
 * The Multer fileSize limit is one byte above the service limit so a file of
 * exactly MAX_IMAGE_BYTES passes and is accepted by the service, while
 * MAX+1 is stopped here (busboy already fires at the limit boundary).
 */
@Injectable()
export class MenuFileInterceptor implements NestInterceptor {
  private readonly parse = multer({
    storage: memoryStorage(),
    limits: {
      fileSize: MAX_IMAGE_BYTES + 1,
      files: 1,
      fields: 0,
      parts: 2,
    },
    fileFilter: (_request, file, callback) => {
      if (!IMAGE_MIMES.has(file.mimetype)) {
        callback(
          new UnsupportedMediaTypeException({
            statusCode: 415,
            code: 'IMAGE_TYPE',
            message: 'Only JPEG, PNG and WebP images are accepted',
          }),
        );
        return;
      }
      callback(null, true);
    },
  }).single('file');

  async intercept(
    context: ExecutionContext,
    next: CallHandler,
  ): Promise<Observable<unknown>> {
    const http = context.switchToHttp();
    const request = http.getRequest();
    const response = http.getResponse();
    await new Promise<void>((resolve, reject) => {
      this.parse(request, response, (error?: unknown) => {
        if (!error) {
          resolve();
          return;
        }
        if (error instanceof MulterError) {
          reject(
            error.code === 'LIMIT_FILE_SIZE'
              ? new PayloadTooLargeException({
                  statusCode: 413,
                  code: 'IMAGE_TOO_LARGE',
                  message: 'Image exceeds the 15 MiB limit',
                })
              : new BadRequestException({
                  statusCode: 400,
                  code: 'UPLOAD_MULTIPART_INVALID',
                  message:
                    'Malformed multipart upload: exactly one image file field is expected',
                }),
          );
          return;
        }
        // HttpException from fileFilter keeps its contract; anything else
        // propagates to the global error handling unchanged.
        reject(error);
      });
    });
    return next.handle();
  }
}
