#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

ENV_FILE=".env.local"

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

echo "Starting Runa..."
docker compose up -d

echo ""
echo "Waiting for services to be healthy..."
# Poll until app is healthy or timeout after 90s
elapsed=0
while [ $elapsed -lt 90 ]; do
  if docker compose ps --format json | grep -q '"Health":"healthy"' 2>/dev/null; then
    health=$(docker compose ps --format '{{.Name}} {{.Health}}' 2>/dev/null)
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
echo "Runa is running at https://localhost"
echo "Accept the self-signed certificate in your browser to get started."
