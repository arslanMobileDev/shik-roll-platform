#!/usr/bin/env bash
# =============================================================================
# SHIK Platform — деплой/обновление production на VPS Timeweb Cloud в 1 команду:
#   ./deploy/scripts/deploy.sh
#
# Что делает: git pull → рендер nginx.conf → (разово) self-signed SSL-заглушка →
#             build → up. Миграции Prisma накатываются автоматически
#             entrypoint'ом бэкенда (prisma migrate deploy).
#
# Первичная выдача боевого SSL-сертификата (один раз, после первого деплоя):
#   cd deploy
#   docker compose -f docker-compose.production.yml \
#     run --rm certbot certonly --webroot -w /var/www/certbot \
#     -d <DOMAIN> --email <LETSENCRYPT_EMAIL> --agree-tos --no-eff-email
#   docker compose -f docker-compose.production.yml exec nginx nginx -s reload
# =============================================================================
set -euo pipefail

DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DEPLOY_DIR"

COMPOSE="docker compose -f docker-compose.production.yml --env-file .env.production"
PROJECT="shik-production"

if [ ! -f .env.production ]; then
  echo "✗ Не найден deploy/.env.production — скопируйте .env.production.example и заполните значения."
  exit 1
fi

DOMAIN="$(grep -E '^DOMAIN=' .env.production | cut -d= -f2-)"
if [ -z "$DOMAIN" ]; then
  echo "✗ В .env.production не задан DOMAIN."
  exit 1
fi

echo "→ Рендер nginx.conf для домена ${DOMAIN}..."
mkdir -p nginx/.rendered
sed "s/__DOMAIN__/${DOMAIN}/g" nginx/nginx.conf > nginx/.rendered/nginx.conf

# Если боевого сертификата ещё нет — кладём временный self-signed,
# чтобы nginx мог стартовать (server-блок 443 требует файлы сертификата).
CONF_VOLUME="${PROJECT}_certbot_conf"
if ! docker run --rm -v "${CONF_VOLUME}":/etc/letsencrypt alpine \
      test -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" 2>/dev/null; then
  echo "→ SSL-сертификат для ${DOMAIN} не найден — создаю временный self-signed..."
  docker run --rm -v "${CONF_VOLUME}":/etc/letsencrypt alpine sh -c "\
    apk add --no-cache openssl >/dev/null && \
    mkdir -p /etc/letsencrypt/live/${DOMAIN} && \
    openssl req -x509 -nodes -newkey rsa:2048 -days 1 \
      -keyout /etc/letsencrypt/live/${DOMAIN}/privkey.pem \
      -out /etc/letsencrypt/live/${DOMAIN}/fullchain.pem \
      -subj '/CN=${DOMAIN}'"
  echo "  ⚠ После деплоя выпустите боевой сертификат (команды — в шапке скрипта)."
fi

echo "→ git pull..."
git pull --ff-only

echo "→ Сборка образа backend..."
$COMPOSE build backend

echo "→ Запуск сервисов..."
$COMPOSE up -d --remove-orphans

echo "→ Миграции применяются автоматически (docker-entrypoint.sh → prisma migrate deploy)."
$COMPOSE ps
echo "✓ Деплой завершён."
