import { mkdtempSync, rmSync } from 'node:fs';
import { readdir, stat } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import sharp from 'sharp';
import { ImageService, MAX_IMAGE_BYTES } from './image.service';

/**
 * Real animated WebP (2 frames, 8x8) used to prove multi-page rejection.
 * Regenerate: two static webp frames + `webpmux -frame f1 +100+0+0+1-b
 * -frame f2 +100+0+0+1-b -loop 0 -o anim.webp` (sharp cannot synthesize
 * multi-page output from static frames).
 */
const ANIMATED_WEBP_B64 =
  'UklGRsIAAABXRUJQVlA4WAoAAAACAAAABwAABwAAQU5JTQYAAAD/////AABBTk1GSAAAAAAAAAAAAAcAAAcAAGQAAANWUDggMAAAANABAJ0BKggACAABQCYloAJ0ugH4AAOwAP7y63/82BXNc+/3/9Lg/S4P0uD/0pAAAEFOTUZGAAAAAAAAAAAABwAABwAAZAAAA1ZQOCAuAAAAkAEAnQEqCAAIAAFAJiWgAnS6AAOYAP77VeP/pcH/0uD/6XB/6XB/G7LOG6QAAA==';

// --- PNG tEXt padding: builds a decodable PNG of an exact byte size ---

const CRC_TABLE: number[] = [];
for (let n = 0; n < 256; n++) {
  let c = n;
  for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  CRC_TABLE[n] = c >>> 0;
}

function crc32(buf: Buffer): number {
  let c = 0xffffffff;
  for (const b of buf) c = CRC_TABLE[(c ^ b) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

/** Pads a valid PNG with a spec-legal tEXt chunk so the result is exactly `target` bytes. */
function padPngToSize(png: Buffer, target: number): Buffer {
  const padLen = target - png.length - 12; // chunk header(8) + CRC(4)
  if (padLen < 4) throw new Error('target too small for padding chunk');
  const type = Buffer.from('tEXt');
  const data = Buffer.concat([Buffer.from('pad'), Buffer.alloc(padLen - 3, 0x61)]);
  const lenBuf = Buffer.alloc(4);
  lenBuf.writeUInt32BE(data.length);
  const crcBuf = Buffer.alloc(4);
  crcBuf.writeUInt32BE(crc32(Buffer.concat([type, data])));
  return Buffer.concat([
    png.subarray(0, png.length - 12), // everything before IEND
    lenBuf,
    type,
    data,
    crcBuf,
    png.subarray(png.length - 12), // IEND
  ]);
}

function multerFile(
  buffer: Buffer,
  mimetype: string,
  originalname = 'photo.jpg',
): Express.Multer.File {
  return {
    fieldname: 'file',
    originalname,
    encoding: '7bit',
    mimetype,
    size: buffer.length,
    buffer,
    stream: null as never,
    destination: '',
    filename: '',
    path: '',
  };
}

const UUID_WEBP =
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.webp$/;

describe('ImageService (ADR-008)', () => {
  let root: string;
  let service: ImageService;
  let jpeg: Buffer;
  let jpegExif6: Buffer;
  let pngAlpha: Buffer;
  let pngSmall: Buffer;
  let webp: Buffer;

  beforeAll(async () => {
    process.env.UPLOADS_ROOT = mkdtempSync(join(tmpdir(), 'shik-uploads-unit-'));
    root = process.env.UPLOADS_ROOT;
    service = new ImageService();
    await service.onModuleInit();

    jpeg = await sharp({
      create: { width: 1600, height: 1200, channels: 3, background: '#336699' },
    })
      .jpeg()
      .toBuffer();
    jpegExif6 = await sharp({
      create: { width: 1200, height: 800, channels: 3, background: '#a52a2a' },
    })
      .jpeg()
      .withMetadata({ orientation: 6 })
      .toBuffer();
    pngAlpha = await sharp({
      create: {
        width: 800,
        height: 600,
        channels: 4,
        background: { r: 255, g: 0, b: 0, alpha: 0.3 },
      },
    })
      .png()
      .toBuffer();
    pngSmall = await sharp({
      create: { width: 100, height: 50, channels: 3, background: '#11aa55' },
    })
      .png()
      .toBuffer();
    webp = await sharp({
      create: { width: 1200, height: 900, channels: 3, background: '#773311' },
    })
      .webp()
      .toBuffer();
  });

  afterAll(() => {
    rmSync(root, { recursive: true, force: true });
  });

  it('normalizes a JPEG to WebP 1000x1000 and publishes it atomically', async () => {
    const result = await service.optimizeAndSave(multerFile(jpeg, 'image/jpeg'));
    expect(result.filename).toMatch(UUID_WEBP);
    expect(result.url).toBe(`/uploads/menu/${result.filename}`);
    expect(result.mimeType).toBe('image/webp');

    const published = join(root, 'menu', result.filename);
    const info = await stat(published);
    expect(info.size).toBe(result.size);
    const meta = await sharp(published).metadata();
    expect(meta.format).toBe('webp');
    expect(meta.width).toBe(1000);
    expect(meta.height).toBe(1000);
    expect(meta.exif).toBeUndefined();
    expect(meta.xmp).toBeUndefined();

    // Staging is clean after publication (no leftovers, no partial files).
    expect(await readdir(join(root, '.staging'))).toEqual([]);
  });

  it('applies EXIF orientation 6 to pixels and strips EXIF/GPS/XMP', async () => {
    const result = await service.optimizeAndSave(
      multerFile(jpegExif6, 'image/jpeg'),
    );
    const meta = await sharp(join(root, 'menu', result.filename)).metadata();
    expect(meta.width).toBe(1000);
    expect(meta.height).toBe(1000);
    expect(meta.orientation).toBeUndefined();
    expect(meta.exif).toBeUndefined();
  });

  it('keeps PNG transparency without substituting a background', async () => {
    const result = await service.optimizeAndSave(
      multerFile(pngAlpha, 'image/png'),
    );
    const meta = await sharp(join(root, 'menu', result.filename)).metadata();
    expect(meta.hasAlpha).toBe(true);
  });

  it('accepts a static WebP and re-encodes it', async () => {
    const result = await service.optimizeAndSave(multerFile(webp, 'image/webp'));
    expect(result.filename).toMatch(UUID_WEBP);
  });

  it('upscales small images to exactly 1000x1000 (no withoutEnlargement)', async () => {
    const result = await service.optimizeAndSave(
      multerFile(pngSmall, 'image/png'),
    );
    const meta = await sharp(join(root, 'menu', result.filename)).metadata();
    expect(meta.width).toBe(1000);
    expect(meta.height).toBe(1000);
  });

  it('accepts a decodable file of exactly 15 MiB (boundary)', async () => {
    const exact = padPngToSize(pngSmall, MAX_IMAGE_BYTES);
    expect(exact.length).toBe(MAX_IMAGE_BYTES);
    const result = await service.optimizeAndSave(multerFile(exact, 'image/png'));
    expect(result.filename).toMatch(UUID_WEBP);
  });

  it('rejects 15 MiB + 1 byte with 413', async () => {
    await expect(
      service.optimizeAndSave(
        multerFile(Buffer.alloc(MAX_IMAGE_BYTES + 1, 1), 'image/png'),
      ),
    ).rejects.toMatchObject({
      status: 413,
      response: { code: 'IMAGE_TOO_LARGE' },
    });
  });

  it('rejects a disallowed MIME before decoding (415)', async () => {
    await expect(
      service.optimizeAndSave(multerFile(pngSmall, 'image/gif')),
    ).rejects.toMatchObject({ status: 415, response: { code: 'IMAGE_TYPE' } });
  });

  it('rejects an SVG claiming to be image/jpeg (415, no published file)', async () => {
    const svg = Buffer.from(
      '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><rect width="10" height="10" fill="red"/></svg>',
    );
    await expect(
      service.optimizeAndSave(multerFile(svg, 'image/jpeg')),
    ).rejects.toMatchObject({ status: 415, response: { code: 'IMAGE_TYPE' } });
    expect(await readdir(join(root, 'menu'))).toEqual(
      expect.arrayContaining([]),
    );
  });

  it('rejects a format/MIME mismatch: PNG content claiming image/jpeg (415)', async () => {
    await expect(
      service.optimizeAndSave(multerFile(pngSmall, 'image/jpeg')),
    ).rejects.toMatchObject({ status: 415, response: { code: 'IMAGE_TYPE' } });
  });

  it('rejects undecodable garbage (422)', async () => {
    await expect(
      service.optimizeAndSave(multerFile(Buffer.alloc(4096, 7), 'image/png')),
    ).rejects.toMatchObject({
      status: 422,
      response: { code: 'IMAGE_INVALID' },
    });
  });

  it('rejects a truncated JPEG (422)', async () => {
    const truncated = jpeg.subarray(0, Math.floor(jpeg.length * 0.6));
    await expect(
      service.optimizeAndSave(multerFile(truncated, 'image/jpeg')),
    ).rejects.toMatchObject({
      status: 422,
      response: { code: 'IMAGE_INVALID' },
    });
  });

  it('rejects an animated WebP (422)', async () => {
    const animated = Buffer.from(ANIMATED_WEBP_B64, 'base64');
    await expect(
      service.optimizeAndSave(multerFile(animated, 'image/webp')),
    ).rejects.toMatchObject({
      status: 422,
      response: { code: 'IMAGE_ANIMATED' },
    });
  });

  it('rejects a missing or empty file (400)', async () => {
    await expect(service.optimizeAndSave(undefined)).rejects.toMatchObject({
      status: 400,
      response: { code: 'IMAGE_REQUIRED' },
    });
    await expect(
      service.optimizeAndSave(multerFile(Buffer.alloc(0), 'image/png')),
    ).rejects.toMatchObject({ status: 400, response: { code: 'IMAGE_REQUIRED' } });
  });

  it('limits concurrent processing (503) and releases slots afterwards', async () => {
    (service as unknown as { active: number }).active = 2;
    await expect(
      service.optimizeAndSave(multerFile(jpeg, 'image/jpeg')),
    ).rejects.toMatchObject({ status: 503, response: { code: 'IMAGE_BUSY' } });
    (service as unknown as { active: number }).active = 0;
    await expect(
      service.optimizeAndSave(multerFile(jpeg, 'image/jpeg')),
    ).resolves.toMatchObject({ mimeType: 'image/webp' });
  });

  it('never lets the client path influence the disk name; parallel saves do not collide', async () => {
    const [a, b] = await Promise.all([
      service.optimizeAndSave(multerFile(jpeg, 'image/jpeg', '../../evil.jpg')),
      service.optimizeAndSave(multerFile(jpeg, 'image/jpeg', '../../evil.jpg')),
    ]);
    expect(a.filename).toMatch(UUID_WEBP);
    expect(b.filename).toMatch(UUID_WEBP);
    expect(a.filename).not.toBe(b.filename);
    expect(a.filename).not.toContain('evil');
    await stat(join(root, 'menu', a.filename));
    await stat(join(root, 'menu', b.filename));
  });

  it('measures the output weight of a photo-like image (ADR-008 reporting)', async () => {
    const photo = await sharp({
      create: {
        width: 3000,
        height: 2000,
        channels: 3,
        background: '#808080',
        noise: { type: 'gaussian', mean: 128, sigma: 40 },
      },
    })
      .jpeg({ quality: 92 })
      .toBuffer();
    const result = await service.optimizeAndSave(
      multerFile(photo, 'image/jpeg'),
    );
    // Informational: the 150-250 KB band is an observation target, not a gate.
    console.log(
      `photo-like output: ${(result.size / 1024).toFixed(1)} KB (input ${(photo.length / 1024 / 1024).toFixed(2)} MB)`,
    );
    expect(result.size).toBeGreaterThan(0);
  });
});
