import { Module } from '@nestjs/common';
import { BackofficeMediaGuard } from './backoffice-media.guard';
import { ImageService } from './image.service';
import { MenuFileInterceptor } from './menu-file.interceptor';
import { UploadAdmissionInterceptor } from './upload-admission.interceptor';
import { UploadsController } from './uploads.controller';

/**
 * Menu media uploads (ADR-008). JwtModule is registered globally by
 * AuthModule, so BackofficeMediaGuard verifies tokens without extra imports.
 */
@Module({
  controllers: [UploadsController],
  providers: [
    ImageService,
    BackofficeMediaGuard,
    UploadAdmissionInterceptor,
    MenuFileInterceptor,
  ],
})
export class UploadsModule {}
