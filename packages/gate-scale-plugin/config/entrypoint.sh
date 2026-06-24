#!/usr/bin/env bash
set -euo pipefail

require() {
  if [[ -z "${!1:-}" ]]; then
    echo "$1 is required" >&2
    exit 1
  fi
}

GATE_BIND_PORT="${GATE_BIND_PORT:-25565}"
MC_PORT="${MC_PORT:-25565}"
WAITING_PORT="${WAITING_PORT:-25565}"
MC_SERVER_NAME="${MC_SERVER_NAME:-minecraft}"
WAITING_SERVER_NAME="${WAITING_SERVER_NAME:-waiting}"
SCALER_MODE="${SCALER_MODE:-azure}"

require VELOCITY_FORWARDING_SECRET
require MC_HOST
require WAITING_HOST
if [[ "${SCALER_MODE}" == "azure" ]]; then
  require AZURE_SUBSCRIPTION_ID
  require AZURE_RESOURCE_GROUP
  require AZURE_CONTAINER_APP_NAME
  require AZURE_CONTAINER_APP_ENVIRONMENT
fi

export GATE_BIND_PORT
export SCALER_MODE
export MC_SERVER_NAME
export WAITING_SERVER_NAME
export MC_SERVER_ADDRESS="${MC_HOST}:${MC_PORT}"
export WAITING_SERVER_ADDRESS="${WAITING_HOST}:${WAITING_PORT}"

mkdir -p /etc/gate
envsubst < /opt/gate/config.yml.template > /etc/gate/config.yml

exec /bin/gate-scale --config /etc/gate/config.yml "$@"
