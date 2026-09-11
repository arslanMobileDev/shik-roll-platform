import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { INestApplication } from '@nestjs/common';
import { JwtModule, JwtService } from '@nestjs/jwt';
import { NestExpressApplication } from '@nestjs/platform-express';
import { Test } from '@nestjs/testing';
import sharp from 'sharp';
import request from 'supertest';
import { serveMenuUploads } from '../src/modules/uploads/uploads-static';
import { UploadsModule } from '../src/modules/uploads/uploads.module';

/**
 * HTTP-level e2e of POST /uploads/menu (ADR-008): multipart contract, error
 * mapping and static serving. Only UploadsModule is booted — no database is
 * required; the backoffice guard uses the same JWT secret + env allowlist as
 * in production.
 */

const SECRET = 'uploads-e2e-secret';
const STAFF_ID = '9b5f4c4c-0f3d-4e2a-8c1d-2e3f4a5b6c7d';
const MAX_IMAGE_BYTES = 15 * 1024 * 1024;

process.env.UPLOADS_ROOT = mkdtempSync(join(tmpdir(), 'shik-uploads-e2e-'));
process.env.BACKOFFICE_STAFF_IDS = STAFF_ID;

// --- PNG tEXt padding: a decodable PNG of an exact byte size ---

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

function padPngToSize(png: Buffer, target: number): Buffer {
  const padLen = target - png.length - 12;
  if (padLen < 4) throw new Error('target too small for padding chunk');
  const type = Buffer.from('tEXt');
  const data = Buffer.concat([Buffer.from('pad'), Buffer.alloc(padLen - 3, 0x61)]);
  const lenBuf = Buffer.alloc(4);
  lenBuf.writeUInt32BE(data.length);
  const crcBuf = Buffer.alloc(4);
  crcBuf.writeUInt32BE(crc32(Buffer.concat([type, data])));
  return Buffer.concat([
    png.subarray(0, png.length - 12),
    lenBuf,
    type,
    data,
    crcBuf,
    png.subarray(png.length - 12),
  ]);
}

describe('Uploads (e2e, ADR-008)', () => {
  let app: INestApplication;
  let jwt: JwtService;
  let png: Buffer;
  let jpeg: Buffer;

  const tokenFor = (sub: string, role: string): string =>
    jwt.sign({ sub, role, type: 'access' });

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [
        UploadsModule,
        JwtModule.register({ global: true, secret: SECRET }),
      ],
    }).compile();
    app = moduleRef.createNestApplication<NestExpressApplication>();
    serveMenuUploads(app as NestExpressApplication);
    await app.init();
    jwt = new JwtService({ secret: SECRET });

    png = await sharp({
      create: { width: 800, height: 600, channels: 3, background: '#336699' },
    })
      .png()
      .toBuffer();
    jpeg = await sharp({
      create: { width: 1600, height: 1200, channels: 3, background: '#996633' },
    })
      .jpeg()
      .toBuffer();
  });

  afterAll(async () => {
    await app.close();
    rmSync(process.env.UPLOADS_ROOT as string, { recursive: true, force: true });
  });

  it('rejects an unauthenticated request before any buffering (401)', async () => {
    const res = await request(app.getHttpServer())
      .post('/uploads/menu')
      .attach('file', jpeg, { filename: 'dish.jpg', contentType: 'image/jpeg' });
    expect(res.status).toBe(401);
    expect(res.body).toMatchObject({ statusCode: 401, code: 'UNAUTHORIZED' });
  });

  it.each(['CUSTOMER', 'KITCHEN', 'COURIER'])(
    'rejects a %s token (401 TOKEN_INVALID)',
    async (role) => {
      const res = await request(app.getHttpServer())
        .post('/uploads/menu')
        .set('Authorization', `Bearer ${tokenFor('x-1', role)}`)
        .attach('file', jpeg, { filename: 'dish.jpg', contentType: 'image/jpeg' });
      expect(res.status).toBe(401);
      expect(res.body).toMatchObject({ statusCode: 401, code: 'TOKEN_INVALID' });
    },
  );

  it('rejects a backoffice subject outside the allowlist (403)', async () => {
    const res = await request(app.getHttpServer())
      .post('/uploads/menu')
      .set('Authorization', `Bearer ${tokenFor('other', 'BACKOFFICE')}`)
      .attach('file', jpeg, { filename: 'dish.jpg', contentType: 'image/jpeg' });
    expect(res.status).toBe(403);
    expect(res.body).toMatchObject({
      statusCode: 403,
      code: 'BACKOFFICE_FORBIDDEN',
    });
  });

  it('rejects a request without a file (400)', async () => {
    const res = await request(app.getHttpServer())
      .post('/uploads/menu')
      .set('Authorization', `Bearer ${tokenFor(STAFF_ID, 'BACKOFFICE')}`)
      .field('note', 'no file attached');
    expect(res.status).toBe(400);
    // fields: 0 is violated first (multipart contract) or IMAGE_REQUIRED —
    // either way the request is a client error with the API contract shape.
    expect(res.body.statusCode).toBe(400);
    expect(typeof res.body.code).toBe('string');
  });

  it('rejects an extra text field next to the file (400)', async () => {
    const res = await request(app.getHttpServer())
      .post('/uploads/menu')
      .set('Authorization', `Bearer ${tokenFor(STAFF_ID, 'BACKOFFICE')}`)
      .field('caption', 'not allowed')
      .attach('file', jpeg, { filename: 'dish.jpg', contentType: 'image/jpeg' });
    expect(res.status).toBe(400);
    expect(res.body).toMatchObject({
      statusCode: 400,
      code: 'UPLOAD_MULTIPART_INVALID',
    });
  });

  it('rejects a second file field (400)', async () => {
    const res = await request(app.getHttpServer())
      .post('/uploads/menu')
      .set('Authorization', `Bearer ${tokenFor(STAFF_ID, 'BACKOFFICE')}`)
      .attach('file', jpeg, { filename: 'dish.jpg', contentType: 'image/jpeg' })
      .attach('extra', png, { filename: 'extra.png', contentType: 'image/png' });
    expect(res.status).toBe(400);
    expect(res.body).toMatchObject({
      statusCode: 400,
      code: 'UPLOAD_MULTIPART_INVALID',
    });
  });

  it('rejects a disallowed declared MIME at the boundary (415)', async () => {
    const res = await request(app.getHttpServer())
      .post('/uploads/menu')
      .set('Authorization', `Bearer ${tokenFor(STAFF_ID, 'BACKOFFICE')}`)
      .attach('file', Buffer.from('hello'), {
        filename: 'note.txt',
        contentType: 'text/plain',
      });
    expect(res.status).toBe(415);
    expect(res.body).toMatchObject({ statusCode: 415, code: 'IMAGE_TYPE' });
  });

  it('rejects an SVG claiming to be image/jpeg (415)', async () => {
    const svg = Buffer.from(
      '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><rect width="10" height="10" fill="red"/></svg>',
    );
    const res = await request(app.getHttpServer())
      .post('/uploads/menu')
      .set('Authorization', `Bearer ${tokenFor(STAFF_ID, 'BACKOFFICE')}`)
      .attach('file', svg, { filename: 'fake.jpg', contentType: 'image/jpeg' });
    expect(res.status).toBe(415);
    expect(res.body).toMatchObject({ statusCode: 415, code: 'IMAGE_TYPE' });
  });

  it('rejects undecodable content (422)', async () => {
    const res = await request(app.getHttpServer())
      .post('/uploads/menu')
      .set('Authorization', `Bearer ${tokenFor(STAFF_ID, 'BACKOFFICE')}`)
      .attach('file', Buffer.alloc(4096, 7), {
        filename: 'broken.png',
        contentType: 'image/png',
      });
    expect(res.status).toBe(422);
    expect(res.body).toMatchObject({ statusCode: 422, code: 'IMAGE_INVALID' });
  });

  it('accepts a decodable file of exactly 15 MiB (201)', async () => {
    const exact = padPngToSize(png, MAX_IMAGE_BYTES);
    expect(exact.length).toBe(MAX_IMAGE_BYTES);
    const res = await request(app.getHttpServer())
      .post('/uploads/menu')
      .set('Authorization', `Bearer ${tokenFor(STAFF_ID, 'BACKOFFICE')}`)
      .attach('file', exact, { filename: 'big.png', contentType: 'image/png' });
    expect(res.status).toBe(201);
    expect(res.body).toMatchObject({ mimeType: 'image/webp', width: 1000, height: 1000 });
  });

  it('rejects 15 MiB + 1 byte in the service (413)', async () => {
    const over = padPngToSize(png, MAX_IMAGE_BYTES + 1);
    const res = await request(app.getHttpServer())
      .post('/uploads/menu')
      .set('Authorization', `Bearer ${tokenFor(STAFF_ID, 'BACKOFFICE')}`)
      .attach('file', over, { filename: 'big.png', contentType: 'image/png' });
    expect(res.status).toBe(413);
    expect(res.body).toMatchObject({ statusCode: 413, code: 'IMAGE_TOO_LARGE' });
  });

  it('rejects a file beyond the Multer limit via the filter (413)', async () => {
    const res = await request(app.getHttpServer())
      .post('/uploads/menu')
      .set('Authorization', `Bearer ${tokenFor(STAFF_ID, 'BACKOFFICE')}`)
      .attach('file', Buffer.alloc(MAX_IMAGE_BYTES + 64 * 1024, 1), {
        filename: 'huge.png',
        contentType: 'image/png',
      });
    expect(res.status).toBe(413);
    expect(res.body).toMatchObject({ statusCode: 413, code: 'IMAGE_TOO_LARGE' });
  });

  it('uploads, publishes and serves the WebP with immutable cache headers', async () => {
    const server = app.getHttpServer();
    const res = await request(server)
      .post('/uploads/menu')
      .set('Authorization', `Bearer ${tokenFor(STAFF_ID, 'BACKOFFICE')}`)
      .attach('file', jpeg, { filename: 'dish.jpg', contentType: 'image/jpeg' });
    expect(res.status).toBe(201);
    expect(res.body).toMatchObject({
      mimeType: 'image/webp',
      width: 1000,
      height: 1000,
    });
    expect(res.body.filename).toMatch(/\.webp$/);
    expect(res.body.url).toBe(`/uploads/menu/${res.body.filename}`);
    expect(res.body.size).toBeGreaterThan(0);

    const got = await request(server).get(res.body.url);
    expect(got.status).toBe(200);
    expect(got.headers['content-type']).toContain('image/webp');
    expect(got.headers['cache-control']).toContain('immutable');
    expect(got.headers['x-content-type-options']).toBe('nosniff');
  });

  it('never serves the staging directory or unknown files (404)', async () => {
    const server = app.getHttpServer();
    await request(server)
      .get('/uploads/.staging/anything.tmp')
      .expect(404);
    await request(server)
      .get('/uploads/menu/00000000-0000-4000-8000-000000000000.webp')
      .expect(404);
  });
});
