#!/usr/bin/env bash
# =============================================================================
# SHIK Platform — деплой/обновление production на VPS Timeweb Cloud в 1 команду:
#   ./deploy/scripts/deploy.sh
#
# Что делает: git pull → preflight → build → ACME bootstrap → up.
# Миграции Prisma накатываются автоматически
#             entrypoint'ом бэкенда (prisma migrate deploy).
#
# Первый сертификат выпускается автоматически для DOMAIN, API_DOMAIN и
# KDS_DOMAIN после запуска временного HTTP-only Nginx.
# =============================================================================
set -euo pipefail

DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DEPLOY_DIR"

COMPOSE="docker compose -f docker-compose.server.yml --env-file .env.production"
PROJECT="shik-production"

if [ ! -f .env.production ]; then
  echo "✗ Не найден deploy/.env.production — скопируйте .env.production.example и заполните значения."
  exit 1
fi

echo "→ git pull..."
git pull --ff-only

env_value() {
  sed -n "s/^$1=//p" .env.production | tail -n 1
}

DOMAIN="$(env_value DOMAIN)"
API_DOMAIN="$(env_value API_DOMAIN)"
KDS_DOMAIN="$(env_value KDS_DOMAIN)"
LETSENCRYPT_EMAIL="$(env_value LETSENCRYPT_EMAIL)"
YOOKASSA_MOCK="$(env_value YOOKASSA_MOCK)"

required_vars="DOMAIN API_DOMAIN KDS_DOMAIN LETSENCRYPT_EMAIL POSTGRES_USER POSTGRES_PASSWORD POSTGRES_DB DATABASE_URL JWT_SECRET API_BASE_URL BRAND_ID BRANCH_ID YOOKASSA_SHOP_ID YOOKASSA_SECRET_KEY"
for name in $required_vars; do
  value="$(env_value "$name")"
  if [ -z "$value" ]; then
    echo "✗ В .env.production не задан $name."
    exit 1
  fi
  case "$value" in
    *CHANGE_ME*|*example*)
      echo "✗ $name содержит шаблонное значение."
      exit 1
      ;;
  esac
done

if [ "$API_DOMAIN" != "api.$DOMAIN" ] || [ "$KDS_DOMAIN" != "kds.$DOMAIN" ]; then
  echo "✗ API_DOMAIN/KDS_DOMAIN не соответствуют шаблону Nginx для $DOMAIN."
  exit 1
fi
if [ "$YOOKASSA_MOCK" != "false" ]; then
  echo "✗ YOOKASSA_MOCK должен быть false в production."
  exit 1
fi

echo "→ Проверка compose..."
$COMPOSE config --quiet

mkdir -p nginx/.rendered
CONF_VOLUME="${PROJECT}_certbot_conf"
HAS_CERT=false
if docker run --rm -v "${CONF_VOLUME}":/etc/letsencrypt alpine \
    test -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" 2>/dev/null; then
  HAS_CERT=true
fi

if [ "$HAS_CERT" = true ]; then
  sed "s/__DOMAIN__/${DOMAIN}/g" nginx/nginx.conf > nginx/.rendered/nginx.conf
else
  echo "→ Сертификат отсутствует: запуск HTTP ACME bootstrap..."
  sed "s/__DOMAIN__/${DOMAIN}/g" nginx/bootstrap.conf > nginx/.rendered/nginx.conf
fi

echo "→ Сборка образа backend..."
COMPOSE_PARALLEL_LIMIT=1 $COMPOSE build backend customer-web kds-web

echo "→ Запуск сервисов..."
$COMPOSE up -d --remove-orphans --wait --wait-timeout 240

if [ "$HAS_CERT" = false ]; then
  echo "→ Выпуск Let's Encrypt для ${DOMAIN}, ${API_DOMAIN}, ${KDS_DOMAIN}..."
  $COMPOSE run --rm --entrypoint certbot certbot certonly \
    --webroot -w /var/www/certbot \
    -d "$DOMAIN" -d "$API_DOMAIN" -d "$KDS_DOMAIN" \
    --email "$LETSENCRYPT_EMAIL" --agree-tos --no-eff-email --non-interactive
  sed "s/__DOMAIN__/${DOMAIN}/g" nginx/nginx.conf > nginx/.rendered/nginx.conf
  $COMPOSE up -d --force-recreate nginx --wait --wait-timeout 120
fi

$COMPOSE --profile certbot up -d certbot

echo "→ Миграции применяются автоматически (docker-entrypoint.sh → prisma migrate deploy)."
$COMPOSE ps
curl --fail --silent --show-error "https://${API_DOMAIN}/health/ready"
echo "✓ Деплой завершён."
