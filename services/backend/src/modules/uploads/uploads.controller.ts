import {
  Controller,
  Post,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import {
  ApiBadRequestResponse,
  ApiBearerAuth,
  ApiBody,
  ApiConsumes,
  ApiCreatedResponse,
  ApiForbiddenResponse,
  ApiInternalServerErrorResponse,
  ApiPayloadTooLargeResponse,
  ApiServiceUnavailableResponse,
  ApiTags,
  ApiUnauthorizedResponse,
  ApiUnprocessableEntityResponse,
  ApiUnsupportedMediaTypeResponse,
} from '@nestjs/swagger';
import { BackofficeMediaGuard } from './backoffice-media.guard';
import { UploadResultDto } from './dto/upload-result.dto';
import { ImageService } from './image.service';
import { MenuFileInterceptor } from './menu-file.interceptor';
import { UploadAdmissionInterceptor } from './upload-admission.interceptor';

/**
 * Menu media uploads (ADR-008). This controller owns only the multipart
 * contract; verification, conversion and storage live in ImageService.
 * Existing JSON CRUD endpoints of the menu module are unchanged.
 */
@ApiTags('uploads')
@ApiBearerAuth()
@Controller('uploads')
@UseGuards(BackofficeMediaGuard)
export class UploadsController {
  constructor(private readonly images: ImageService) {}

  /**
   * Accepts one menu image (multipart field `file`; JPEG/PNG/WebP up to
   * 15 MiB) and publishes an optimized WebP 1000x1000. The response carries
   * the public URL; binding the image to a menu item is a separate contract.
   */
  @Post('menu')
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      required: ['file'],
      properties: { file: { type: 'string', format: 'binary' } },
    },
  })
  @ApiCreatedResponse({ type: UploadResultDto, description: 'WebP 1000x1000 saved' })
  @ApiBadRequestResponse({ description: 'Missing/empty file or malformed multipart' })
  @ApiUnauthorizedResponse({ description: 'Missing or invalid Bearer token' })
  @ApiForbiddenResponse({ description: 'No backoffice media write permission' })
  @ApiPayloadTooLargeResponse({ description: 'Image exceeds the 15 MiB limit' })
  @ApiUnsupportedMediaTypeResponse({ description: 'Unsupported or spoofed image type' })
  @ApiUnprocessableEntityResponse({
    description: 'Undecodable, animated or over the pixel limit',
  })
  @ApiInternalServerErrorResponse({ description: 'Storage failure' })
  @ApiServiceUnavailableResponse({ description: 'Too many concurrent uploads' })
  @UseInterceptors(UploadAdmissionInterceptor, MenuFileInterceptor)
  uploadMenu(@UploadedFile() file?: Express.Multer.File): Promise<UploadResultDto> {
    return this.images.optimizeAndSave(file);
  }
}
