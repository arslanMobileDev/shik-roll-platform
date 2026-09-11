import {
  HttpException,
  Injectable,
  InternalServerErrorException,
  Logger,
  OnModuleInit,
  ServiceUnavailableException,
} from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { link, mkdir, readdir, stat, unlink, writeFile } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import sharp from 'sharp';

/** Maximum accepted upload size: 15 MiB, inclusive (ADR-008). */
export const MAX_IMAGE_BYTES = 15 * 1024 * 1024;

/** Client-declared MIME types accepted at the multipart boundary. */
export const IMAGE_MIMES = new Set(['image/jpeg', 'image/png', 'image/webp']);

/** Concurrent sharp pipelines per process (ADR-008 initial operational value). */
export const MAX_CONCURRENT_IMAGES = 2;

/** Decoded-pixel ceiling, independent of the compressed size limit. */
const MAX_INPUT_PIXELS = 40_000_000;

/** Age after which crash leftovers in .staging are collected at boot. */
const STAGING_MAX_AGE_MS = 24 * 60 * 60 * 1000;

/** Actual decoded format -> the MIME it is allowed to claim. */
const FORMAT_MIME: Record<string, string> = {
  jpeg: 'image/jpeg',
  png: 'image/png',
  webp: 'image/webp',
};

export interface UploadResult {
  filename: string;
  url: string;
  mimeType: 'image/webp';
  size: number;
  width: 1000;
  height: 1000;
}

function reject(statusCode: number, code: string, message: string): never {
  throw new HttpException({ statusCode, code, message }, statusCode);
}

/**
 * Menu image pipeline (ADR-008): verifies the actual decoded format against
 * the claimed MIME, normalizes orientation, crops to exactly 1000x1000 and
 * re-encodes as WebP q82 with all metadata stripped (sharp default output
 * behaviour; no keepMetadata/withMetadata is ever called). The original is
 * never stored. Publication is atomic: the file is fully written under
 * UPLOADS_ROOT/.staging and then hard-linked into UPLOADS_ROOT/menu under a
 * UUID v4 name, so the static endpoint never serves a partial file. The
 * client-supplied name, extension and path never reach the disk.
 */
@Injectable()
export class ImageService implements OnModuleInit {
  private readonly logger = new Logger(ImageService.name);
  private readonly root = resolve(process.env.UPLOADS_ROOT ?? 'uploads');
  private readonly menuDir = join(this.root, 'menu');
  // Staging shares the volume with menu (hard-link requirement) but is
  // outside the served directory.
  private readonly stagingDir = join(this.root, '.staging');
  private active = 0;

  async onModuleInit(): Promise<void> {
    // A directory problem must stop the boot, not the first request.
    await mkdir(this.menuDir, { recursive: true });
    await mkdir(this.stagingDir, { recursive: true });
    await this.reapStaging().catch((error: Error) => {
      this.logger.warn(`Staging cleanup failed: ${error.message}`);
    });
  }

  /** Removes crash leftovers from .staging; never fatal. */
  private async reapStaging(): Promise<void> {
    const threshold = Date.now() - STAGING_MAX_AGE_MS;
    for (const entry of await readdir(this.stagingDir)) {
      if (!entry.endsWith('.tmp')) continue;
      const full = join(this.stagingDir, entry);
      const info = await stat(full).catch(() => undefined);
      if (info && info.mtimeMs < threshold) {
        await unlink(full).catch(() => undefined);
      }
    }
  }

  get uploadsRoot(): string {
    return this.root;
  }

  async optimizeAndSave(file?: Express.Multer.File): Promise<UploadResult> {
    if (!file || !file.buffer || file.buffer.length === 0) {
      reject(400, 'IMAGE_REQUIRED', 'A single non-empty image file is required');
    }
    if (file.buffer.length > MAX_IMAGE_BYTES) {
      reject(413, 'IMAGE_TOO_LARGE', 'Image exceeds the 15 MiB limit');
    }
    if (!IMAGE_MIMES.has(file.mimetype)) {
      reject(415, 'IMAGE_TYPE', 'Only JPEG, PNG and WebP images are accepted');
    }
    if (this.active >= MAX_CONCURRENT_IMAGES) {
      throw new ServiceUnavailableException({
        statusCode: 503,
        code: 'IMAGE_BUSY',
        message: 'Image processing is busy; retry later',
      });
    }
    this.active++;
    try {
      let output: Buffer;
      try {
        const input = sharp(file.buffer, {
          limitInputPixels: MAX_INPUT_PIXELS,
          failOn: 'warning',
        });
        const meta = await input.metadata();
        // The client-controlled MIME is never trusted: the actual decoded
        // format must match it. SVG/GIF/HEIC/AVIF/PDF/TIFF and spoofed
        // Content-Types are rejected here.
        if (!meta.format || FORMAT_MIME[meta.format] !== file.mimetype) {
          reject(
            415,
            'IMAGE_TYPE',
            'File content does not match an allowed image format',
          );
        }
        // The result must not depend on an implicit first-frame choice.
        if ((meta.pages ?? 1) !== 1) {
          reject(
            422,
            'IMAGE_ANIMATED',
            'Animated or multi-page images are not accepted',
          );
        }
        output = await input
          .rotate()
          .resize(1000, 1000, { fit: 'cover', position: 'centre' })
          .webp({ quality: 82 })
          .toBuffer();
      } catch (error) {
        if (error instanceof HttpException) throw error;
        reject(422, 'IMAGE_INVALID', 'The image cannot be decoded');
      }

      const filename = `${randomUUID()}.webp`;
      const temporary = join(this.stagingDir, `${randomUUID()}.tmp`);
      let owned = false;
      try {
        await writeFile(temporary, output, { flag: 'wx', mode: 0o644 });
        owned = true;
        // The hard link publishes only a fully written file and never
        // replaces an existing final file on an impossible UUID collision.
        await link(temporary, join(this.menuDir, filename));
      } catch (error) {
        // Never log the buffer or the path content; only the OS reason.
        this.logger.error(
          `Image storage failed: ${error instanceof Error ? error.message : String(error)}`,
        );
        throw new InternalServerErrorException({
          statusCode: 500,
          code: 'IMAGE_STORAGE_ERROR',
          message: 'Unable to save image',
        });
      } finally {
        if (owned) {
          await unlink(temporary).catch((error: Error) => {
            this.logger.warn(`Staging unlink failed: ${error.message}`);
          });
        }
      }
      return {
        filename,
        url: `/uploads/menu/${filename}`,
        mimeType: 'image/webp',
        size: output.length,
        width: 1000,
        height: 1000,
      };
    } finally {
      this.active--;
    }
  }
}
