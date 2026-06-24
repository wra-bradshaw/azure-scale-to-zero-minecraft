#!/usr/bin/env bash
set -euo pipefail

MC_DATA_DIR="${MC_DATA_DIR:-/srv/minecraft}"
SERVER_JAR="${SERVER_JAR:-/opt/minecraft/server.jar}"
JAVA_OPTS="${JAVA_OPTS:--Djava.io.tmpdir=${MC_DATA_DIR}/tmp -Xms1G -Xmx4G}"
MANAGED_DIR="${MANAGED_DIR:-/opt/minecraft/managed}"
MANAGED_STATE="${MANAGED_STATE:-${MC_DATA_DIR}/.nix-minecraft-managed}"

require() {
  if [[ -z "${!1:-}" ]]; then
    echo "$1 is required" >&2
    exit 1
  fi
}

require VELOCITY_FORWARDING_SECRET

mkdir -p "${MC_DATA_DIR}"
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
    chmod -R u+w -- "${target}"
  elif file --mime-encoding "${source}" | grep -v '\bbinary$' -q; then
    substitute_text_file "${source}" "${target}"
  else
    cp -L -- "${source}" "${target}"
    chmod u+w -- "${target}"
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
      ln -sfn -- "${source}" "${target}"
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

exec java ${JAVA_OPTS} -jar "${SERVER_JAR}" nogui
