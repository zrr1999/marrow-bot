#!/usr/bin/env bash
set -euo pipefail

BOT_DIR="${BOT_DIR:-/opt/marrow-bot}"
CONFIG_PATH="${CONFIG_PATH:-${BOT_DIR}/marrow.toml}"
SERVICE_OUT_DIR="${SERVICE_OUT_DIR:-${BOT_DIR}/service-out}"
BOT_USER="${BOT_USER:-marrow}"

if [[ "$(uname -s)" == "Darwin" ]]; then
  BOT_HOME="${BOT_HOME:-/Users/${BOT_USER}}"
else
  BOT_HOME="${BOT_HOME:-/home/${BOT_USER}}"
fi

echo "[marrow-bot] Using BOT_DIR=${BOT_DIR}"
echo "[marrow-bot] Using CONFIG_PATH=${CONFIG_PATH}"
echo "[marrow-bot] Using SERVICE_OUT_DIR=${SERVICE_OUT_DIR}"
echo "[marrow-bot] Using BOT_USER=${BOT_USER}"
echo "[marrow-bot] Using BOT_HOME=${BOT_HOME}"

run_with_optional_sudo() {
  local target="$1"
  shift
  local parent
  if [[ -e "${target}" ]]; then
    parent="${target}"
  else
    parent="$(dirname "${target}")"
  fi
  if [[ -w "${parent}" ]]; then
    "$@"
    return
  fi
  sudo env "PATH=${PATH}" "$@"
}

run_as_bot_user() {
  if [[ "$(id -un)" == "${BOT_USER}" ]]; then
    env HOME="${BOT_HOME}" PATH="${BOT_PATH}" "$@"
    return
  fi
  sudo -u "${BOT_USER}" env HOME="${BOT_HOME}" PATH="${BOT_PATH}" "$@"
}


if [[ ! -d "${BOT_DIR}" ]]; then
  echo "[marrow-bot] ERROR: BOT_DIR does not exist: ${BOT_DIR}" >&2
  exit 1
fi

if [[ ! -f "${CONFIG_PATH}" ]]; then
  echo "[marrow-bot] ERROR: config does not exist: ${CONFIG_PATH}" >&2
  exit 1
fi
BOT_PATH="${BOT_HOME}/.bun/bin:${BOT_HOME}/.local/bin:${BOT_HOME}/bin:${PATH}"

if ! id "${BOT_USER}" >/dev/null 2>&1; then
  echo "[marrow-bot] ERROR: configured bot user does not exist: ${BOT_USER}" >&2
  exit 1
fi

cd "${BOT_DIR}"

if ! command -v uvx >/dev/null 2>&1; then
  echo "[marrow-bot] uvx not found, attempting to install uv..." >&2
  curl -LsSf https://astral.sh/uv/install.sh | sh
  # shellcheck source=/dev/null
  if [[ -f "${HOME}/.cargo/env" ]]; then
    # uv installer may update PATH via cargo; source if present
    # ignore shellcheck since this path is user-local
    . "${HOME}/.cargo/env"
  fi
  if ! command -v uvx >/dev/null 2>&1; then
    echo "[marrow-bot] ERROR: uvx still not found after attempted install. Please install uv manually from https://github.com/astral-sh/uv." >&2
    exit 1
  fi
fi

if ! command -v uv >/dev/null 2>&1; then
  echo "[marrow-bot] ERROR: uv is required (provides uvx for marrow-core)." >&2
  exit 1
fi

if ! command -v opencode >/dev/null 2>&1; then
  echo "[marrow-bot] ERROR: opencode is required but was not found on PATH." >&2
  exit 1
fi

if ! run_as_bot_user command -v opencode >/dev/null 2>&1; then
  echo "[marrow-bot] ERROR: opencode is not available on PATH for ${BOT_USER}." >&2
  exit 1
fi

marrow_core() {
  uvx marrow-core "$@"
}

echo "[marrow-bot] Rendering roles via role-forge..."
run_with_optional_sudo "${BOT_DIR}" uvx role-forge render --project-dir "${BOT_DIR}" --yes

echo "[marrow-bot] Linking rendered agents into ${BOT_HOME}/.opencode ..."
run_with_optional_sudo "${BOT_HOME}/.opencode" mkdir -p "${BOT_HOME}"
run_with_optional_sudo "${BOT_HOME}/.opencode" ln -sfn "${BOT_DIR}/.opencode" "${BOT_HOME}/.opencode"

echo "[marrow-bot] Installing context providers into ${BOT_HOME}/context.d ..."
run_with_optional_sudo "${BOT_HOME}/context.d" mkdir -p "${BOT_HOME}/context.d"
for script in "${BOT_DIR}"/context.d/*.py; do
  run_with_optional_sudo "${BOT_HOME}/context.d/$(basename "${script}")" install -m 0755 "${script}" "${BOT_HOME}/context.d/$(basename "${script}")"
done

echo "[marrow-bot] Ensuring workspace structure via marrow-core setup..."
run_as_bot_user marrow_core setup --config "${CONFIG_PATH}"

echo "[marrow-bot] Validating profile via marrow-core..."
run_as_bot_user marrow_core validate --config "${CONFIG_PATH}"
run_as_bot_user marrow_core doctor --config "${CONFIG_PATH}"
run_as_bot_user marrow_core dry-run --config "${CONFIG_PATH}" >/dev/null
run_with_optional_sudo "$(dirname "${SERVICE_OUT_DIR}")" env HOME="${BOT_HOME}" PATH="${BOT_PATH}" sh -lc 'uvx marrow-core install-service --config "$1" --platform auto --output-dir "$2"' -- "${CONFIG_PATH}" "${SERVICE_OUT_DIR}"

echo "[marrow-bot] Setup complete."
echo "[marrow-bot] Config: ${CONFIG_PATH}"
echo "[marrow-bot] Service files: ${SERVICE_OUT_DIR}"
