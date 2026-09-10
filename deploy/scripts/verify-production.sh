#!/usr/bin/env bash
set -euo pipefail

DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DEPLOY_DIR"

COMPOSE="docker compose -f docker-compose.server.yml --env-file .env.production"
env_value() {
  sed -n "s/^$1=//p" .env.production | tail -n 1
}

DOMAIN="$(env_value DOMAIN)"
API_DOMAIN="$(env_value API_DOMAIN)"
KDS_DOMAIN="$(env_value KDS_DOMAIN)"
POSTGRES_USER="$(env_value POSTGRES_USER)"
POSTGRES_DB="$(env_value POSTGRES_DB)"
BRAND_ID="$(env_value BRAND_ID)"
BRANCH_ID="$(env_value BRANCH_ID)"

for tool in curl jq; do
  command -v "$tool" >/dev/null || {
    echo "✗ Требуется утилита $tool"
    exit 1
  }
done

echo "→ HTTPS/health"
curl --fail --silent --show-error "https://${API_DOMAIN}/health/ready" | jq -e '.status == "ok"'
curl --fail --silent --show-error "https://${DOMAIN}/" >/dev/null
curl --fail --silent --show-error "https://${KDS_DOMAIN}/" >/dev/null

echo "→ Контейнеры и миграции"
$COMPOSE ps
$COMPOSE exec -T backend npx prisma migrate status

if [ -z "${E2E_MENU_ITEM_ID:-}" ] || [ -z "${E2E_KDS_TERMINAL_CODE:-}" ]; then
  echo "ℹ E2E пропущен: задайте E2E_MENU_ITEM_ID и E2E_KDS_TERMINAL_CODE."
  exit 0
fi

read -r -s -p "PIN терминала ${E2E_KDS_TERMINAL_CODE}: " KDS_PIN
echo
AUTH_PAYLOAD="$(jq -n \
  --arg terminalCode "$E2E_KDS_TERMINAL_CODE" \
  --arg pin "$KDS_PIN" \
  '{terminalCode: $terminalCode, pin: $pin}')"
KDS_TOKEN="$(curl --fail --silent --show-error \
  -H 'Content-Type: application/json' \
  -d "$AUTH_PAYLOAD" \
  "https://${API_DOMAIN}/kitchen/auth/pin" | jq -er '.token')"

SSE_FILE="$(mktemp)"
cleanup() {
  [ -n "${SSE_PID:-}" ] && kill "$SSE_PID" 2>/dev/null || true
  rm -f "$SSE_FILE"
}
trap cleanup EXIT

curl --silent --show-error --no-buffer --max-time 30 \
  -H "Authorization: Bearer ${KDS_TOKEN}" \
  -H 'Accept: text/event-stream' \
  "https://${API_DOMAIN}/kitchen/stream" >"$SSE_FILE" &
SSE_PID=$!
sleep 2

ORDER_PAYLOAD="$(jq -n \
  --arg brandId "$BRAND_ID" \
  --arg branchId "$BRANCH_ID" \
  --arg menuItemId "$E2E_MENU_ITEM_ID" \
  '{brandId: $brandId, branchId: $branchId, type: "TAKEAWAY", paymentMethod: "ON_DELIVERY", items: [{menuItemId: $menuItemId, quantity: 1}]}')"
ORDER_JSON="$(curl --fail --silent --show-error \
  -H 'Content-Type: application/json' \
  -d "$ORDER_PAYLOAD" \
  "https://${API_DOMAIN}/orders")"
ORDER_ID="$(printf '%s' "$ORDER_JSON" | jq -er '.id')"
printf '%s' "$ORDER_JSON" | jq -e '.status == "NEW"' >/dev/null

DB_STATUS="$($COMPOSE exec -T postgres psql \
  -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atc \
  "SELECT status FROM orders WHERE id = '${ORDER_ID}'")"
[ "$DB_STATUS" = "NEW" ] || {
  echo "✗ PostgreSQL status=$DB_STATUS, ожидался NEW"
  exit 1
}

for _ in $(seq 1 20); do
  if grep -q "$ORDER_ID" "$SSE_FILE"; then
    echo "✓ E2E: POST /orders → PostgreSQL NEW → /kitchen/stream"
    exit 0
  fi
  sleep 1
done

echo "✗ Заказ $ORDER_ID не появился в Kitchen SSE"
exit 1
