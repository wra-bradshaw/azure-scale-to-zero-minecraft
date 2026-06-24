#!/usr/bin/env bash
set -euo pipefail

PICOLIMBO_BIND_PORT="${PICOLIMBO_BIND_PORT:-25565}"
export PICOLIMBO_BIND_PORT

if [[ -z "${VELOCITY_FORWARDING_SECRET:-}" ]]; then
  echo "VELOCITY_FORWARDING_SECRET is required" >&2
  exit 1
fi

mkdir -p /usr/src/app
envsubst < /opt/picolimbo/server.toml.template > /usr/src/app/server.toml
cd /usr/src/app

exec /bin/pico_limbo
