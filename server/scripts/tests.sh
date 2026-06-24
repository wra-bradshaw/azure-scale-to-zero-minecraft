#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TMPDIR}"' EXIT

export PATH="${TMPDIR}:$PATH"

cat > "${TMPDIR}/java" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${JAVA_LOG}"
exit "${JAVA_EXIT_STATUS:-0}"
STUB
chmod +x "${TMPDIR}/java"

cat > "${TMPDIR}/envsubst" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
awk '{
  while (match($0, /\$\{[A-Za-z_][A-Za-z0-9_]*\}/)) {
    name = substr($0, RSTART + 2, RLENGTH - 3)
    $0 = substr($0, 1, RSTART - 1) ENVIRON[name] substr($0, RSTART + RLENGTH)
  }
  print
}'
STUB
chmod +x "${TMPDIR}/envsubst"

cat > "${TMPDIR}/file" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
echo "$2: us-ascii"
STUB
chmod +x "${TMPDIR}/file"

MC_DATA_DIR="${TMPDIR}/mc-data"
MANAGED_DIR="${TMPDIR}/managed"
mkdir -p "${MC_DATA_DIR}/world" "${MC_DATA_DIR}/plugins/RuntimePlugin" "${MANAGED_DIR}" "${TMPDIR}/sources"
printf 'world-state\n' > "${MC_DATA_DIR}/world/level.dat"
printf 'runtime-state\n' > "${MC_DATA_DIR}/plugins/RuntimePlugin/database.db"
printf 'manual=true\n' > "${MC_DATA_DIR}/server.properties"
printf 'plugin jar\n' > "${TMPDIR}/sources/TestPlugin.jar"
printf 'secret=${VELOCITY_FORWARDING_SECRET}\nlegacy=@VELOCITY_FORWARDING_SECRET@\n' > "${TMPDIR}/sources/server.properties"
printf 'plugins/TestPlugin.jar\t%s\n' "${TMPDIR}/sources/TestPlugin.jar" > "${MANAGED_DIR}/symlinks.tsv"
printf 'server.properties\t%s\n' "${TMPDIR}/sources/server.properties" > "${MANAGED_DIR}/files.tsv"
touch "${MANAGED_DIR}/manifest" "${TMPDIR}/server.jar"

export VELOCITY_FORWARDING_SECRET="velocity-secret"
export MC_EULA="true"
export MC_DATA_DIR
export MANAGED_DIR
export SERVER_JAR="${TMPDIR}/server.jar"
export JAVA_LOG="${TMPDIR}/java.log"

"${ROOT}/server/scripts/entrypoint.sh"

if [[ ! -L "${MC_DATA_DIR}/plugins/TestPlugin.jar" ]]; then
  echo "managed plugin jar was not symlinked" >&2
  exit 1
fi
if ! rg -q "secret=velocity-secret" "${MC_DATA_DIR}/server.properties" ||
  ! rg -q "legacy=velocity-secret" "${MC_DATA_DIR}/server.properties"; then
  echo "managed config did not receive expected env substitution" >&2
  exit 1
fi
if ! rg -q "manual=true" "${MC_DATA_DIR}/server.properties.bak"; then
  echo "existing unmanaged config was not moved to .bak" >&2
  exit 1
fi
if ! rg -q "world-state" "${MC_DATA_DIR}/world/level.dat" ||
  ! rg -q "runtime-state" "${MC_DATA_DIR}/plugins/RuntimePlugin/database.db"; then
  echo "unmanaged world or plugin runtime data was not preserved" >&2
  exit 1
fi
printf 'manual edit\n' > "${MC_DATA_DIR}/server.properties"
printf 'secret=changed\n' > "${TMPDIR}/sources/server.properties"
"${ROOT}/server/scripts/entrypoint.sh"
if ! rg -q "secret=changed" "${MC_DATA_DIR}/server.properties"; then
  echo "managed config was not overwritten on restart" >&2
  exit 1
fi
if rg -q "manual edit" "${MC_DATA_DIR}/server.properties"; then
  echo "manual edit to managed config persisted across restart" >&2
  exit 1
fi

if ! rg -q "SCALER_MODE: local" "${ROOT}/docker-compose.local.yml" ||
  ! rg -q "ghcr.io/local/mc-server/gate-scale:dev" "${ROOT}/docker-compose.local.yml" ||
  ! rg -q "ghcr.io/local/mc-server/minecraft:dev" "${ROOT}/docker-compose.local.yml" ||
  ! rg -q "ghcr.io/local/mc-server/picolimbo:dev" "${ROOT}/docker-compose.local.yml"; then
  echo "local compose file does not define the expected full-stack services" >&2
  exit 1
fi

echo "script tests passed"
