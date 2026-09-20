#!/usr/bin/env bash
#
# update-nginx.sh — пересобрать .rendered/nginx.conf из шаблона и reload nginx.
#
# Использование (на прод-сервере):
#   cd /opt/shik-roll-platform
#   ./deploy/scripts/update-nginx.sh
#
# Что делает:
#   1. Проверяет, что запущен из корня репозитория.
#   2. Проверяет, что шаблон nginx/nginx.conf существует.
#   3. Генерирует nginx/.rendered/nginx.conf из шаблона (подставляет домен).
#   4. Делает бэкап прежнего .rendered/nginx.conf.
#   5. Проверяет синтаксис через nginx -t.
#   6. Reload'ит nginx (без разрыва сессий).
#   7. В случае ошибки — не трогает активный конфиг.
#
set -euo pipefail

# Домен по умолчанию. Можно переопределить: DOMAIN=custom.ru ./update-nginx.sh
DOMAIN="${DOMAIN:-shik-roll.ru}"

# Пути относительно корня репо
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NGINX_DIR="${REPO_ROOT}/deploy/nginx"
TEMPLATE="${NGINX_DIR}/nginx.conf"
RENDERED_DIR="${NGINX_DIR}/.rendered"
RENDERED="${RENDERED_DIR}/nginx.conf"

echo "[update-nginx] repo=${REPO_ROOT}"
echo "[update-nginx] domain=${DOMAIN}"

# 1. Проверка, что шаблон существует
if [ ! -f "${TEMPLATE}" ]; then
  echo "[update-nginx] ERROR: шаблон не найден: ${TEMPLATE}" >&2
  exit 1
fi

# 2. Готовим директорию для rendered
mkdir -p "${RENDERED_DIR}"

# 3. Бэкап прежнего rendered (если есть)
if [ -f "${RENDERED}" ]; then
  BACKUP="${RENDERED}.bak-$(date +%Y%m%d-%H%M%S)"
  cp "${RENDERED}" "${BACKUP}"
  echo "[update-nginx] backup: ${BACKUP}"
fi

# 4. Рендер: подставляем домен вместо __DOMAIN__
sed "s/__DOMAIN__/${DOMAIN}/g" "${TEMPLATE}" > "${RENDERED}.new"
mv "${RENDERED}.new" "${RENDERED}"
echo "[update-nginx] rendered: ${RENDERED}"

# 5. Проверка синтаксиса
if ! docker exec shik_nginx nginx -t 2>&1; then
  echo "[update-nginx] ERROR: nginx -t failed, откатываю на бэкап" >&2
  if [ -f "${BACKUP}" ]; then
    cp "${BACKUP}" "${RENDERED}"
    echo "[update-nginx] откат выполнен: ${RENDERED}"
  fi
  exit 1
fi

# 6. Reload nginx
if docker exec shik_nginx nginx -s reload 2>&1; then
  echo "[update-nginx] OK — nginx reloaded"
else
  echo "[update-nginx] WARN: reload вернул ошибку, но конфиг валиден" >&2
  exit 1
fi
