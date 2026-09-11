import { NestExpressApplication } from '@nestjs/platform-express';
import { join, resolve } from 'node:path';

/**
 * Serves only the published menu images (never UPLOADS_ROOT/.staging) for
 * local development. The production equivalent is the Nginx
 * `location ^~ /uploads/menu/` block backed by the shared read-only volume
 * (ADR-008). Files are content-named (UUID), so they are cached immutably.
 */
export function serveMenuUploads(app: NestExpressApplication): void {
  const root = resolve(process.env.UPLOADS_ROOT ?? 'uploads');
  app.useStaticAssets(join(root, 'menu'), {
    prefix: '/uploads/menu/',
    index: false,
    immutable: true,
    maxAge: '365d',
    setHeaders: (res) => {
      // serve-static does not set this on its own; Nginx adds it in production.
      res.setHeader('X-Content-Type-Options', 'nosniff');
    },
  });
}
