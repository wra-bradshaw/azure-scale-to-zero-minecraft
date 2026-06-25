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

printf '%s\n' "$*"
mkdir -p world world_nether plugins/Example logs crash-reports tmp
printf '%s\n' "placed-block" > world/chunk.dat
printf '%s\n' "nether-block" > world_nether/chunk.dat
printf '%s\n' "plugin-state" > plugins/Example/data.yml
printf '%s\n' "log" > logs/latest.log
printf '%s\n' "crash" > crash-reports/crash.txt
printf '%s\n' "tmp" > tmp/runtime.tmp
printf '%s\n' "tmp" > session.tmp
sleep "${FAKE_JAVA_SLEEP:-2}"
FAKE_JAVA
  chmod +x "${bin_dir}/java"
}

run_entrypoint() {
  local data_dir="$1"
  local fake_bin="$2"
  local jar="$3"
  local managed_dir="$4"
  local log_path="$5"

  if ! env \
    PATH="${fake_bin}:${PATH}" \
    VELOCITY_FORWARDING_SECRET="test-secret" \
    MC_EULA="true" \
    MC_DATA_DIR="${data_dir}" \
    SERVER_JAR="${jar}" \
    MANAGED_DIR="${managed_dir}" \
    bash "${ENTRYPOINT}" > "${log_path}" 2>&1; then
    cat "${log_path}" >&2
    exit 1
  fi
}

assert_clean_shutdown() {
  local data_dir="$1"
  local fake_bin="$2"
  local jar="$3"
  local managed_dir="$4"
  local log_path="$5"

  env \
    PATH="${fake_bin}:${PATH}" \
    VELOCITY_FORWARDING_SECRET="test-secret" \
    MC_EULA="true" \
    MC_DATA_DIR="${data_dir}" \
    SERVER_JAR="${jar}" \
    MANAGED_DIR="${managed_dir}" \
    FAKE_JAVA_SLEEP="30" \
    bash "${ENTRYPOINT}" > "${log_path}" 2>&1 &
  local entrypoint_pid="$!"

  sleep 1
  kill -TERM "${entrypoint_pid}"

  set +e
  wait "${entrypoint_pid}"
  local status="$?"
  set -e

  if [[ "${status}" -ne 0 ]]; then
    echo "expected clean shutdown after SIGTERM, got ${status}" >&2
    cat "${log_path}" >&2
    exit 1
  fi
}

main() {
  bash -n "${ENTRYPOINT}"

  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "${tmp_dir}"' EXIT

  local fake_bin="${tmp_dir}/bin"
  local data_dir="${tmp_dir}/data"
  local managed_dir="${tmp_dir}/managed"
  local jar="${tmp_dir}/server.jar"
  local log_path="${tmp_dir}/entrypoint.log"
  local shutdown_data="${tmp_dir}/shutdown-data"
  local shutdown_log="${tmp_dir}/shutdown.log"

  make_fake_java "${fake_bin}"
  mkdir -p "${managed_dir}"
  : > "${jar}"
  : > "${managed_dir}/symlinks.tsv"
  printf '%s\t%s\n' "server.properties" "${ROOT_DIR}/server/managed/server.properties" > "${managed_dir}/files.tsv"

  run_entrypoint "${data_dir}" "${fake_bin}" "${jar}" "${managed_dir}" "${log_path}"

  assert_file_contains "${data_dir}/eula.txt" "eula=true"
  assert_file_contains "${data_dir}/world/chunk.dat" "placed-block"
  assert_file_contains "${data_dir}/world_nether/chunk.dat" "nether-block"
  assert_file_contains "${data_dir}/plugins/Example/data.yml" "plugin-state"
  assert_file_contains "${data_dir}/server.properties" "motd=Scale-to-zero Minecraft"
  assert_log_contains "${log_path}" "-jar ${jar} nogui"

  assert_clean_shutdown "${shutdown_data}" "${fake_bin}" "${jar}" "${managed_dir}" "${shutdown_log}"
}

main "$@"
