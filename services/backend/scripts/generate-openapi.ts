/**
 * Generates the static OpenAPI contract (openapi.json) without binding a port.
 * Uses the compiled dist output so decorator metadata is fully emitted.
 * Run: pnpm openapi
 */
import { writeFileSync } from 'node:fs';
import * as path from 'node:path';
import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';

async function generate(): Promise<void> {
  const { AppModule } = await import('../dist/app.module');
  const app = await NestFactory.create(AppModule, { logger: false });
  await app.init();

  const config = new DocumentBuilder()
    .setTitle('SHIK Platform — Menu & Product API')
    .setDescription('Menu & Product catalog, Order management and guest auth API (API-706, DB-607, DB-608, BE-906, BE-907)')
    .setVersion('0.1.0')
    .addTag('menus')
    .addTag('categories')
    .addTag('menu-items')
    .addTag('orders')
    .addTag('auth')
    .addBearerAuth()
    .build();
  const document = SwaggerModule.createDocument(app, config);

  const target = path.resolve(__dirname, '..', 'openapi.json');
  writeFileSync(target, JSON.stringify(document, null, 2));
  console.log(`OpenAPI contract written to ${target}`);

  await app.close();
}

void generate();
