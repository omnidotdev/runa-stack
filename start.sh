#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

ENV_FILE=".env.local"

# Reset volumes if --fresh flag is passed
if [ "${1:-}" = "--fresh" ]; then
  echo "Removing existing containers and volumes..."
  docker compose --env-file "$ENV_FILE" down -v 2>/dev/null || true
  rm -f "$ENV_FILE"
fi

# Generate .env.local on first run
if [ ! -f "$ENV_FILE" ]; then
  echo "Generating secrets..."
  cat > "$ENV_FILE" <<EOF
DB_PASSWORD=$(openssl rand -hex 32)
AUTH_SECRET=$(openssl rand -hex 32)
AUTH_CLIENT_ID=$(openssl rand -hex 16)
AUTH_CLIENT_SECRET=$(openssl rand -hex 32)
EOF
  echo "Created $ENV_FILE"
fi

echo "🌙 Starting Runa..."
docker compose --env-file "$ENV_FILE" up -d

echo ""
echo "Waiting for services to be healthy..."
elapsed=0
while [ $elapsed -lt 90 ]; do
  if docker compose --env-file "$ENV_FILE" ps --format json | grep -q '"Health":"healthy"' 2>/dev/null; then
    health=$(docker compose --env-file "$ENV_FILE" ps --format '{{.Name}} {{.Health}}' 2>/dev/null)
    if echo "$health" | grep -q "app" && ! echo "$health" | grep -q "starting"; then
      break
    fi
  fi
  sleep 3
  elapsed=$((elapsed + 3))
  printf "."
done
echo ""

echo ""
echo "🌙 Runa is running at https://localhost"
echo "Accept the self-signed certificate in your browser to get started."
