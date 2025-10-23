#!/bin/sh
set -eu

POSTGRES_HOST="${DB_POSTGRESDB_HOST:-postgres}"
POSTGRES_PORT="${DB_POSTGRESDB_PORT:-5432}"
PATH="${PATH:-/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin}"

unset WEBHOOK_URL N8N_WEBHOOK_TUNNEL_URL || true

wait_for_postgres() {
  echo "Waiting for Postgres at ${POSTGRES_HOST}:${POSTGRES_PORT}..."
  attempt=0
  while [ "$attempt" -lt 60 ]; do
    if node <<'NODE' >/dev/null 2>&1
const net = require('net');
const host = process.env.POSTGRES_HOST || 'postgres';
const port = Number(process.env.POSTGRES_PORT || 5432);
const socket = net.createConnection({ host, port });
socket.setTimeout(1000);
socket.on('connect', () => { socket.destroy(); process.exit(0); });
socket.on('error', () => { process.exit(1); });
socket.on('timeout', () => { socket.destroy(); process.exit(1); });
NODE
    then
      echo "Postgres is available."
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 2
  done
  echo "Timed out waiting for Postgres" >&2
  exit 1
}

export POSTGRES_HOST POSTGRES_PORT
wait_for_postgres

resolve_public_url() {
  api_url="http://ngrok:4040/api/tunnels"
  payload=""
  if command -v curl >/dev/null 2>&1; then
    if payload=$(curl -sS --fail "$api_url"); then
      :
    else
      return 1
    fi
  elif command -v wget >/dev/null 2>&1; then
    if payload=$(wget -qO- "$api_url"); then
      :
    else
      return 1
    fi
  else
    return 1
  fi
  printf '%s' "$payload" | node <<'NODE'
const fs = require('fs');
try {
  const data = JSON.parse(fs.readFileSync(0, 'utf8'));
  const tunnel = (data.tunnels || []).find(t => t.public_url && t.public_url.startsWith('https://'));
  if (tunnel && tunnel.public_url) {
    console.log(tunnel.public_url);
  }
} catch (error) {
  process.exit(1);
}
NODE
}

if [ -z "${PUBLIC_BASE_URL:-}" ]; then
  echo "PUBLIC_BASE_URL not set, attempting to fetch from ngrok API..."
  attempt=0
  sleep 3
  while [ "$attempt" -lt 90 ]; do
    PUBLIC_URL=""
    if PUBLIC_URL=$(resolve_public_url) && [ -n "$PUBLIC_URL" ]; then
      export WEBHOOK_URL="$PUBLIC_URL"
      export N8N_WEBHOOK_TUNNEL_URL="$PUBLIC_URL"
      echo "Using ngrok public URL: $PUBLIC_URL"
      break
    fi
    attempt=$((attempt + 1))
    echo "ngrok public URL not ready (attempt $attempt/90). Retrying..."
    sleep 2
  done
  if [ -z "${WEBHOOK_URL:-}" ]; then
    echo "Unable to determine ngrok public URL; using defaults." >&2
  fi
else
  export WEBHOOK_URL="${PUBLIC_BASE_URL}"
  export N8N_WEBHOOK_TUNNEL_URL="${PUBLIC_BASE_URL}"
fi

exec /docker-entrypoint.sh "$@"
