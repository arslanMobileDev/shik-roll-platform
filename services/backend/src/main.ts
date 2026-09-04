import { ValidationPipe, BadRequestException } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      transformOptions: { enableImplicitConversion: false },
      // API-706 error contract: validation failures carry VALIDATION_ERROR.
      exceptionFactory: (errors) =>
        new BadRequestException({
          statusCode: 400,
          code: 'VALIDATION_ERROR',
          message: errors
            .map((error) => Object.values(error.constraints ?? {}).join(', '))
            .filter(Boolean)
            .join('; '),
        }),
    }),
  );

  const config = new DocumentBuilder()
    .setTitle('SHIK Platform — Menu & Product API')
    .setDescription('Menu & Product catalog, Order management and guest auth API (API-706, DB-607, DB-608, BE-906, BE-907)')
    .setVersion('0.1.0')
    .addTag('menus')
    .addTag('categories')
    .addTag('menu-items')
    .addTag('orders')
    .addTag('payments')
    .addTag('auth')
    .addBearerAuth()
    .build();
  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api/docs', app, document);

  const port = Number(process.env.PORT ?? 3000);
  await app.listen(port);
}

void bootstrap();
