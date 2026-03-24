#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

ENV_FILE=".env.local"
CERTS_DIR=".certs"

# Reset volumes if --fresh flag is passed
if [ "${1:-}" = "--fresh" ]; then
  echo "Removing existing containers and volumes..."
  docker compose --env-file "$ENV_FILE" down -v 2>/dev/null || true
  rm -f "$ENV_FILE"
  rm -rf "$CERTS_DIR"
fi

# Generate .env.local on first run
if [ ! -f "$ENV_FILE" ]; then
  # New secrets won't match old database volumes — wipe them
  docker compose down -v 2>/dev/null || true

  echo "Generating secrets..."

  # Detect HTTPS capability
  PROTOCOL="http"
  if command -v mkcert &>/dev/null; then
    PROTOCOL="https"
    echo "Found mkcert — enabling trusted HTTPS"
    mkdir -p "$CERTS_DIR"
    if [ ! -f "$CERTS_DIR/localhost.pem" ]; then
      mkcert -install 2>/dev/null || true
      mkcert -cert-file "$CERTS_DIR/localhost.pem" -key-file "$CERTS_DIR/localhost-key.pem" localhost 127.0.0.1 ::1
    fi
  else
    echo "mkcert not found — using HTTP (install mkcert for trusted HTTPS)"
  fi

  cat > "$ENV_FILE" <<EOF
DB_PASSWORD=$(openssl rand -hex 32)
AUTH_SECRET=$(openssl rand -hex 32)
AUTH_CLIENT_ID=$(openssl rand -hex 16)
AUTH_CLIENT_SECRET=$(openssl rand -hex 32)
PROTOCOL=$PROTOCOL
EOF
  echo "Created $ENV_FILE"
fi

# Read protocol from env
PROTOCOL=$(grep -oP '(?<=PROTOCOL=)\S+' "$ENV_FILE" 2>/dev/null || echo "http")

# Generate Caddyfile based on TLS mode
if [ "$PROTOCOL" = "https" ] && [ -f "$CERTS_DIR/localhost.pem" ]; then
  cat > Caddyfile <<'CADDY'
# Auto-generated — trusted HTTPS via mkcert
https://localhost:{$APP_PORT:443} {
	tls /certs/localhost.pem /certs/localhost-key.pem
	reverse_proxy app:3000
}

https://localhost:{$AUTH_PORT:3001} {
	tls /certs/localhost.pem /certs/localhost-key.pem
	reverse_proxy auth:3000
}

https://localhost:{$API_PORT:4000} {
	tls /certs/localhost.pem /certs/localhost-key.pem
	reverse_proxy api:4000
}
CADDY
else
  cat > Caddyfile <<'CADDY'
# Auto-generated — HTTP mode (install mkcert for trusted HTTPS)
http://localhost:{$APP_PORT:80} {
	reverse_proxy app:3000
}

http://localhost:{$AUTH_PORT:3001} {
	reverse_proxy auth:3000
}

http://localhost:{$API_PORT:4000} {
	reverse_proxy api:4000
}
CADDY
fi

# Resolve URLs
if [ "$PROTOCOL" = "https" ]; then
  APP_URL="https://localhost"
  AUTH_URL="https://localhost:3001"
  API_URL="https://localhost:4000"
  APP_PORT_MAP="443:443"
else
  APP_URL="http://localhost"
  AUTH_URL="http://localhost:3001"
  API_URL="http://localhost:4000"
  APP_PORT_MAP="80:80"
fi

echo "🌙 Starting Runa..."
BASE_URL="$APP_URL" \
AUTH_BASE_URL="$AUTH_URL" \
API_BASE_URL="$API_URL" \
APP_PORT_MAP="$APP_PORT_MAP" \
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

# Seed OAuth client in Gatekeeper (idempotent)
source "$ENV_FILE"
REDIRECT_URI="$APP_URL/api/auth/oauth2/callback/omni"
HASHED_SECRET=$(echo -n "$AUTH_CLIENT_SECRET" | openssl dgst -sha256 -binary | openssl base64 -A | tr '+/' '-_' | tr -d '=')
docker compose --env-file "$ENV_FILE" exec -T auth-db psql -U "${DB_USER:-postgres}" -d "${AUTH_DB_NAME:-auth}" -c "
INSERT INTO oauth_client (
  id, client_id, client_secret, name, redirect_uris,
  skip_consent, require_pkce, grant_types, response_types,
  token_endpoint_auth_method, created_at, updated_at
) SELECT
  gen_random_uuid(), '$AUTH_CLIENT_ID', '$HASHED_SECRET', 'default',
  ARRAY['$REDIRECT_URI'],
  true, true,
  ARRAY['authorization_code', 'refresh_token'],
  ARRAY['code'],
  'client_secret_post', NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM oauth_client WHERE client_id = '$AUTH_CLIENT_ID');
" >/dev/null 2>&1

echo ""
echo "🌙 Runa is running at $APP_URL"
if [ "$PROTOCOL" = "http" ]; then
  echo "Install mkcert (https://github.com/FiloSottile/mkcert) and run ./start.sh --fresh for trusted HTTPS"
fi
