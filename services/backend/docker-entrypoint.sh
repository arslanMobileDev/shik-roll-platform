#!/bin/sh
# SHIK Backend — production entrypoint:
# 1) автоматически накатывает миграции Prisma на БД
# 2) запускает NestJS
set -e

echo "[entrypoint] Applying Prisma migrations (prisma migrate deploy)..."
npx prisma migrate deploy

echo "[entrypoint] Migrations applied. Starting NestJS..."
exec node dist/main.js
