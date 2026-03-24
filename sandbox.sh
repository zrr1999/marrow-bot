#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF_USAGE'
Usage: ./sandbox.sh [--live-run]

Create an isolated local sandbox under ./.sandbox/ for validating marrow-bot
against the neighboring ../marrow-core checkout.

Options:
  --live-run   After dry-run checks, also attempt one real `marrow-core run --once`.
EOF_USAGE
}

LIVE_RUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --live-run)
      LIVE_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[marrow-bot:sandbox] unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

MB_LOG_PREFIX="[marrow-bot:sandbox]"
BOT_DIR="${SCRIPT_DIR}"
CORE_DIR_INPUT="${CORE_DIR:-${BOT_DIR}/../marrow-core}"
CORE_DIR="$(cd "${CORE_DIR_INPUT}" && pwd)"
SANDBOX_DIR="${SANDBOX_DIR:-${BOT_DIR}/.sandbox}"
BOT_USER="${BOT_USER:-$(id -un)}"
BOT_HOME="${BOT_HOME:-${SANDBOX_DIR}/home}"
CONFIG_PATH="${CONFIG_PATH:-${SANDBOX_DIR}/marrow.toml}"
SERVICE_OUT_DIR="${SERVICE_OUT_DIR:-${SANDBOX_DIR}/service-out}"
REPORT_PATH="${REPORT_PATH:-${SANDBOX_DIR}/report.txt}"
BOT_PATH="${BOT_HOME}/.bun/bin:${BOT_HOME}/.local/bin:${BOT_HOME}/bin:${PATH}"
MB_LIB_DIR="${BOT_DIR}/lib"
if [[ -n "${ROLE_FORGE_BIN:-}" ]]; then
  ROLE_FORGE_CMD=("${ROLE_FORGE_BIN}")
elif command -v role-forge >/dev/null 2>&1; then
  ROLE_FORGE_CMD=("$(command -v role-forge)")
else
  ROLE_FORGE_CMD=(uvx role-forge)
fi

mkdir -p "${SANDBOX_DIR}" "${BOT_HOME}" "${SERVICE_OUT_DIR}"
: > "${REPORT_PATH}"

log() {
  printf '%s\n' "$*" | tee -a "${REPORT_PATH}"
}

log_cmd() {
  printf '$' | tee -a "${REPORT_PATH}" >/dev/null
  for arg in "$@"; do
    printf ' %q' "${arg}" | tee -a "${REPORT_PATH}" >/dev/null
  done
  printf '\n' | tee -a "${REPORT_PATH}" >/dev/null
}

run_step() {
  log ""
  log_cmd "$@"
  "$@" 2>&1 | tee -a "${REPORT_PATH}"
}

run_in_sandbox() {
  env HOME="${BOT_HOME}" PATH="${BOT_PATH}" "$@"
}

mb_run_core() {
  run_in_sandbox uv run --directory "${CORE_DIR}" marrow-core "$@"
}

write_config() {
  python3 "${MB_LIB_DIR}/py/write_sandbox_config.py" \
    "${BOT_DIR}" "${CORE_DIR}" "${BOT_USER}" "${BOT_HOME}" "${CONFIG_PATH}"
}

latest_exec_log() {
  local stream="$1"
  shopt -s nullglob
  local logs=("${BOT_HOME}"/runtime/logs/exec/*.${stream}.log)
  shopt -u nullglob
  if (( ${#logs[@]} == 0 )); then
    return 0
  fi
  printf '%s\n' "${logs[${#logs[@]}-1]}"
}

append_latest_exec_logs() {
  local latest_stdout=""
  local latest_stderr=""
  latest_stdout="$(latest_exec_log stdout)"
  latest_stderr="$(latest_exec_log stderr)"
  if [[ -n "${latest_stdout}" ]]; then
    log ""
    log "Latest stdout log: ${latest_stdout}"
    tail -n 40 "${latest_stdout}" | tee -a "${REPORT_PATH}"
  fi
  if [[ -n "${latest_stderr}" ]]; then
    log ""
    log "Latest stderr log: ${latest_stderr}"
    tail -n 40 "${latest_stderr}" | tee -a "${REPORT_PATH}"
  fi
}

detect_live_run_error() {
  local latest_stderr=""
  latest_stderr="$(latest_exec_log stderr)"
  if [[ -z "${latest_stderr}" || ! -s "${latest_stderr}" ]]; then
    return 1
  fi
  python3 "${MB_LIB_DIR}/py/detect_live_run_error.py" "${latest_stderr}"
}

if [[ ! -d "${CORE_DIR}" || ! -f "${CORE_DIR}/pyproject.toml" ]]; then
  echo "[marrow-bot:sandbox] ERROR: CORE_DIR must point to a marrow-core checkout: ${CORE_DIR}" >&2
  exit 1
fi

for cmd in python3 uv uvx opencode; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "[marrow-bot:sandbox] ERROR: required command not found: ${cmd}" >&2
    exit 1
  fi
done

log "[marrow-bot:sandbox] BOT_DIR=${BOT_DIR}"
log "[marrow-bot:sandbox] CORE_DIR=${CORE_DIR}"
log "[marrow-bot:sandbox] SANDBOX_DIR=${SANDBOX_DIR}"
log "[marrow-bot:sandbox] BOT_USER=${BOT_USER}"
log "[marrow-bot:sandbox] BOT_HOME=${BOT_HOME}"
log "[marrow-bot:sandbox] CONFIG_PATH=${CONFIG_PATH}"

log ""
log "[marrow-bot:sandbox] Writing local sandbox config..."
write_config
run_step cat "${CONFIG_PATH}"

# ── Render roles ────────────────────────────────────────────────────
log ""
log "[marrow-bot:sandbox] Rendering roles via role-forge..."
run_step "${ROLE_FORGE_CMD[@]}" render --project-dir "${BOT_DIR}" --yes

# ── Profile setup via marrow-core ───────────────────────────────────
log ""
log "[marrow-bot:sandbox] Running profile-setup..."
log_cmd uv run --directory "${CORE_DIR}" marrow-core profile-setup \
  --config "${CONFIG_PATH}" --home "${BOT_HOME}" --user "${BOT_USER}" --doctor
mb_run_core profile-setup \
  --config "${CONFIG_PATH}" \
  --home "${BOT_HOME}" \
  --user "${BOT_USER}" \
  --doctor 2>&1 | tee -a "${REPORT_PATH}"

if (( LIVE_RUN == 1 )); then
  log ""
  log "[marrow-bot:sandbox] Attempting one live run..."
  log_cmd uv run --directory "${CORE_DIR}" marrow-core run --once --config "${CONFIG_PATH}"
  set +e
  mb_run_core run --once --config "${CONFIG_PATH}" 2>&1 | tee -a "${REPORT_PATH}"
  live_status=${PIPESTATUS[0]}
  set -e
  log "[marrow-bot:sandbox] live run exit code: ${live_status}"
  append_latest_exec_logs
  live_error=""
  if live_error="$(detect_live_run_error)"; then
    log "[marrow-bot:sandbox] live run blocked: ${live_error}"
    log "[marrow-bot:sandbox] suggestion: re-authenticate opencode with a supported provider token/session, then rerun ./sandbox.sh --live-run."
    exit 1
  fi
  if (( live_status != 0 )); then
    exit "${live_status}"
  fi
  log "[marrow-bot:sandbox] live run completed without detected agent-side errors."
fi

log ""
log "[marrow-bot:sandbox] Sandbox ready."
log "[marrow-bot:sandbox] Report: ${REPORT_PATH}"
