#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENTRYPOINT="${ROOT_DIR}/server/scripts/entrypoint.sh"

assert_file_contains() {
  local path="$1"
  local expected="$2"

  if [[ ! -f "${path}" ]]; then
    echo "expected file to exist: ${path}" >&2
    exit 1
  fi

  if ! grep -Fqx -- "${expected}" "${path}"; then
    echo "expected ${path} to contain exactly: ${expected}" >&2
    exit 1
  fi
}

assert_missing() {
  local path="$1"

  if [[ -e "${path}" ]]; then
    echo "expected path to be excluded from sync: ${path}" >&2
    exit 1
  fi
}

assert_log_contains() {
  local path="$1"
  local expected="$2"

  if ! grep -Fq -- "${expected}" "${path}"; then
    echo "expected ${path} to contain: ${expected}" >&2
    cat "${path}" >&2
    exit 1
  fi
}

make_fake_java() {
  local bin_dir="$1"

  mkdir -p "${bin_dir}"
  cat > "${bin_dir}/java" <<'FAKE_JAVA'
#!/usr/bin/env bash
set -euo pipefail

mkdir -p world world_nether plugins/Example logs crash-reports tmp
printf '%s\n' "placed-block" > world/chunk.dat
printf '%s\n' "nether-block" > world_nether/chunk.dat
printf '%s\n' "plugin-state" > plugins/Example/data.yml
printf '%s\n' "log" > logs/latest.log
printf '%s\n' "crash" > crash-reports/crash.txt
printf '%s\n' "tmp" > tmp/runtime.tmp
printf '%s\n' "tmp" > session.tmp
sleep 2
FAKE_JAVA
  chmod +x "${bin_dir}/java"
}

run_entrypoint() {
  local data_dir="$1"
  local backend_dir="$2"
  local fake_bin="$3"
  local jar="$4"
  local managed_dir="$5"
  local log_path="$6"

  if ! env \
    PATH="${fake_bin}:${PATH}" \
    VELOCITY_FORWARDING_SECRET="test-secret" \
    MC_EULA="true" \
    MC_DATA_DIR="${data_dir}" \
    SERVER_JAR="${jar}" \
    MANAGED_DIR="${managed_dir}" \
    WORLD_SYNC_BACKEND="local" \
    WORLD_SYNC_LOCAL_PATH="${backend_dir}" \
    WORLD_SYNC_INTERVAL_SECONDS="1" \
    bash "${ENTRYPOINT}" > "${log_path}" 2>&1; then
    cat "${log_path}" >&2
    exit 1
  fi
}

main() {
  bash -n "${ENTRYPOINT}"

  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "${tmp_dir}"' EXIT

  local fake_bin="${tmp_dir}/bin"
  local backend_dir="${tmp_dir}/backend"
  local first_data="${tmp_dir}/first-data"
  local second_data="${tmp_dir}/second-data"
  local managed_dir="${tmp_dir}/managed"
  local jar="${tmp_dir}/server.jar"
  local first_log="${tmp_dir}/first.log"
  local second_log="${tmp_dir}/second.log"

  make_fake_java "${fake_bin}"
  mkdir -p "${backend_dir}" "${managed_dir}"
  : > "${jar}"
  : > "${managed_dir}/symlinks.tsv"
  printf '%s\t%s\n' "server.properties" "${ROOT_DIR}/server/managed/server.properties" > "${managed_dir}/files.tsv"

  run_entrypoint "${first_data}" "${backend_dir}" "${fake_bin}" "${jar}" "${managed_dir}" "${first_log}"

  assert_file_contains "${backend_dir}/current/world/chunk.dat" "placed-block"
  assert_file_contains "${backend_dir}/current/world_nether/chunk.dat" "nether-block"
  assert_file_contains "${backend_dir}/current/plugins/Example/data.yml" "plugin-state"
  assert_file_contains "${backend_dir}/current/server.properties" "motd=Scale-to-zero Minecraft"
  assert_missing "${backend_dir}/current/logs/latest.log"
  assert_missing "${backend_dir}/current/crash-reports/crash.txt"
  assert_missing "${backend_dir}/current/tmp/runtime.tmp"
  assert_missing "${backend_dir}/current/session.tmp"
  assert_missing "${backend_dir}/current/.nix-minecraft-managed"
  assert_log_contains "${first_log}" "(periodic)"

  run_entrypoint "${second_data}" "${backend_dir}" "${fake_bin}" "${jar}" "${managed_dir}" "${second_log}"

  assert_file_contains "${second_data}/world/chunk.dat" "placed-block"
  assert_file_contains "${second_data}/world_nether/chunk.dat" "nether-block"
  assert_file_contains "${second_data}/plugins/Example/data.yml" "plugin-state"
  assert_file_contains "${second_data}/server.properties" "motd=Scale-to-zero Minecraft"
}

main "$@"
