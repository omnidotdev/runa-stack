#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

ENV_FILE=".env.local"

if [ "${1:-}" = "--clean" ]; then
  echo "Stopping Runa and removing all data..."
  docker compose --env-file "$ENV_FILE" down -v 2>/dev/null || true
  rm -f "$ENV_FILE"
  rm -rf .certs
  echo "Done — all containers, volumes, secrets, and certs removed"
else
  echo "Stopping Runa..."
  docker compose --env-file "$ENV_FILE" down 2>/dev/null || true
  echo "Done — data preserved. Run ./start.sh to restart, or ./stop.sh --clean to remove everything"
fi
