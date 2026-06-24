#!/usr/bin/env bash
set -euo pipefail

MC_DATA_DIR="${MC_DATA_DIR:-/srv/minecraft}"
SERVER_JAR="${SERVER_JAR:-/opt/minecraft/server.jar}"
JAVA_OPTS="${JAVA_OPTS:--Djava.io.tmpdir=${MC_DATA_DIR}/tmp -Xms1G -Xmx4G}"
MANAGED_DIR="${MANAGED_DIR:-/opt/minecraft/managed}"
MANAGED_STATE="${MANAGED_STATE:-${MC_DATA_DIR}/.nix-minecraft-managed}"
WORLD_SYNC_BACKEND="${WORLD_SYNC_BACKEND:-none}"
WORLD_SYNC_INTERVAL_SECONDS="${WORLD_SYNC_INTERVAL_SECONDS:-300}"
WORLD_SYNC_REMOTE_NAME="${WORLD_SYNC_REMOTE_NAME:-worldsync}"
WORLD_SYNC_REMOTE_PATH="${WORLD_SYNC_REMOTE_PATH:-current}"
SYNC_EXCLUDES=(
  "--exclude" "tmp/**"
  "--exclude" ".nix-minecraft-managed"
  "--exclude" "logs/**"
  "--exclude" "crash-reports/**"
  "--exclude" "*.tmp"
)
JAVA_PID=""
TERM_REQUESTED=0

require() {
  if [[ -z "${!1:-}" ]]; then
    echo "$1 is required" >&2
    exit 1
  fi
}

require VELOCITY_FORWARDING_SECRET

mkdir -p "${MC_DATA_DIR}"

configure_world_sync() {
  case "${WORLD_SYNC_BACKEND}" in
    none|"")
      return 0
      ;;
    azureblob)
      require AZURE_STORAGE_ACCOUNT
      require AZURE_STORAGE_KEY
      require AZURE_STORAGE_CONTAINER
      export "RCLONE_CONFIG_${WORLD_SYNC_REMOTE_NAME^^}_TYPE=azureblob"
      export "RCLONE_CONFIG_${WORLD_SYNC_REMOTE_NAME^^}_ACCOUNT=${AZURE_STORAGE_ACCOUNT}"
      export "RCLONE_CONFIG_${WORLD_SYNC_REMOTE_NAME^^}_KEY=${AZURE_STORAGE_KEY}"
      WORLD_SYNC_TARGET="${WORLD_SYNC_REMOTE_NAME}:${AZURE_STORAGE_CONTAINER}/${WORLD_SYNC_REMOTE_PATH}"
      ;;
    local)
      require WORLD_SYNC_LOCAL_PATH
      mkdir -p "${WORLD_SYNC_LOCAL_PATH}"
      export "RCLONE_CONFIG_${WORLD_SYNC_REMOTE_NAME^^}_TYPE=local"
      WORLD_SYNC_TARGET="${WORLD_SYNC_REMOTE_NAME}:${WORLD_SYNC_LOCAL_PATH}/${WORLD_SYNC_REMOTE_PATH}"
      ;;
    *)
      echo "unsupported WORLD_SYNC_BACKEND: ${WORLD_SYNC_BACKEND}" >&2
      exit 1
      ;;
  esac
}

world_sync_enabled() {
  [[ "${WORLD_SYNC_BACKEND}" != "none" && -n "${WORLD_SYNC_BACKEND}" ]]
}

restore_world() {
  world_sync_enabled || return 0

  echo "restoring Minecraft data from ${WORLD_SYNC_TARGET}"
  rclone mkdir "${WORLD_SYNC_TARGET}"
  rclone sync "${WORLD_SYNC_TARGET}" "${MC_DATA_DIR}" "${SYNC_EXCLUDES[@]}"
}

sync_world() {
  local label="$1"
  world_sync_enabled || return 0

  echo "syncing Minecraft data to ${WORLD_SYNC_TARGET} (${label})"
  rclone sync "${MC_DATA_DIR}" "${WORLD_SYNC_TARGET}" "${SYNC_EXCLUDES[@]}"
}

periodic_sync_loop() {
  world_sync_enabled || return 0

  while kill -0 "${JAVA_PID}" 2>/dev/null; do
    sleep "${WORLD_SYNC_INTERVAL_SECONDS}" || true
    kill -0 "${JAVA_PID}" 2>/dev/null || break
    if ! sync_world "periodic"; then
      echo "periodic world sync failed; continuing" >&2
    fi
  done
}

forward_signal() {
  local signal="$1"

  TERM_REQUESTED=1
  if [[ -n "${JAVA_PID}" ]] && kill -0 "${JAVA_PID}" 2>/dev/null; then
    kill "-${signal}" "${JAVA_PID}" 2>/dev/null || true
  fi
}

configure_world_sync
restore_world
mkdir -p "${MC_DATA_DIR}/tmp"
cd "${MC_DATA_DIR}"

safe_managed_path() {
  local path="$1"
  if [[ -z "${path}" || "${path}" == /* || "${path}" == *..* ]]; then
    echo "invalid managed path: ${path}" >&2
    exit 1
  fi
}

backup_existing_path() {
  local target="$1"
  if [[ -e "${target}" || -L "${target}" ]]; then
    echo "${target} already exists, moving to ${target}.bak"
    rm -rf -- "${target}.bak"
    mv -- "${target}" "${target}.bak"
  fi
}

substitute_text_file() {
  local source="$1"
  local target="$2"
  gawk '{
    for (varname in ENVIRON) {
      gsub("@" varname "@", ENVIRON[varname])
    }
    print
  }' "${source}" | envsubst > "${target}"
}

copy_managed_file() {
  local source="$1"
  local target="$2"
  if [[ -d "${source}" ]]; then
    cp -R -L -- "${source}" "${target}"
    chmod -R u+w -- "${target}" || true
  elif file --mime-encoding "${source}" | grep -v '\bbinary$' -q; then
    substitute_text_file "${source}" "${target}"
  else
    cp -L -- "${source}" "${target}"
    chmod u+w -- "${target}" || true
  fi
}

remove_previous_managed_paths() {
  if [[ -e "${MANAGED_STATE}" ]]; then
    while IFS= read -r path || [[ -n "${path}" ]]; do
      [[ -z "${path}" ]] && continue
      safe_managed_path "${path}"
      rm -rf -- "${MC_DATA_DIR}/${path}"
    done < "${MANAGED_STATE}"
    rm -f -- "${MANAGED_STATE}"
  fi
}

apply_managed_paths() {
  local kind_file="$1"
  local mode="$2"
  [[ -f "${kind_file}" ]] || return 0

  while IFS=$'\t' read -r path source || [[ -n "${path}" ]]; do
    [[ -z "${path}" ]] && continue
    safe_managed_path "${path}"

    local target="${MC_DATA_DIR}/${path}"
    mkdir -p -- "$(dirname "${target}")"
    backup_existing_path "${target}"

    if [[ "${mode}" == "symlink" ]]; then
      if ! ln -sfn -- "${source}" "${target}"; then
        echo "failed to symlink ${target}; copying managed path instead" >&2
        copy_managed_file "${source}" "${target}"
      fi
    else
      copy_managed_file "${source}" "${target}"
    fi

    printf '%s\n' "${path}" >> "${MANAGED_STATE}"
  done < "${kind_file}"
}

apply_managed_tree() {
  remove_previous_managed_paths
  : > "${MANAGED_STATE}"
  apply_managed_paths "${MANAGED_DIR}/symlinks.tsv" symlink
  apply_managed_paths "${MANAGED_DIR}/files.tsv" file
}

if [[ ! -f eula.txt ]]; then
  echo "eula=${MC_EULA:-false}" > eula.txt
fi

apply_managed_tree

if [[ ! -f "${SERVER_JAR}" ]]; then
  echo "missing Minecraft server jar at ${SERVER_JAR}" >&2
  exit 1
fi

trap 'forward_signal TERM' TERM
trap 'forward_signal INT' INT

java ${JAVA_OPTS} -jar "${SERVER_JAR}" nogui &
JAVA_PID="$!"

periodic_sync_loop &
SYNC_PID="$!"

set +e
wait "${JAVA_PID}"
JAVA_STATUS="$?"
set -e

if kill -0 "${SYNC_PID}" 2>/dev/null; then
  kill "${SYNC_PID}" 2>/dev/null || true
  wait "${SYNC_PID}" 2>/dev/null || true
fi

FINAL_SYNC_STATUS=0
if ! sync_world "final"; then
  FINAL_SYNC_STATUS=1
  echo "final world sync failed" >&2
fi

if [[ "${JAVA_STATUS}" -eq 143 && "${TERM_REQUESTED}" -eq 1 ]]; then
  exit 0
fi

if [[ "${JAVA_STATUS}" -eq 0 ]]; then
  exit "${FINAL_SYNC_STATUS}"
fi

exit "${JAVA_STATUS}"
