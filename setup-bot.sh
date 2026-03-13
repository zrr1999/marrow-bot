#!/usr/bin/env bash
set -euo pipefail

# Minimal helper to wire the marrow-bot profile into a marrow-core install.
#
# Assumes:
# - marrow-core is installed under /opt/marrow-core
# - this repository is cloned under /opt/marrow-bot

CORE_DIR="${CORE_DIR:-/opt/marrow-core}"
BOT_DIR="${BOT_DIR:-/opt/marrow-bot}"
CONFIG_PATH="${CONFIG_PATH:-${CORE_DIR}/marrow.toml}"

echo "[marrow-bot] Using CORE_DIR=${CORE_DIR}"
echo "[marrow-bot] Using BOT_DIR=${BOT_DIR}"
echo "[marrow-bot] Using CONFIG_PATH=${CONFIG_PATH}"

if [[ ! -d "${CORE_DIR}" ]]; then
  echo "[marrow-bot] ERROR: CORE_DIR does not exist: ${CORE_DIR}" >&2
  exit 1
fi

if [[ ! -d "${BOT_DIR}" ]]; then
  echo "[marrow-bot] ERROR: BOT_DIR does not exist: ${BOT_DIR}" >&2
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

echo "[marrow-bot] Casting roles via role-forge (uvx role-forge)..."
uvx role-forge cast --config roles.toml

echo "[marrow-bot] Copying marrow.toml to ${CONFIG_PATH}..."
cp marrow.toml "${CONFIG_PATH}"

echo "[marrow-bot] Validating config via marrow-core (uvx marrow)..."

cd "${CORE_DIR}"
uvx marrow validate --config "${CONFIG_PATH}"
uvx marrow install-service --config "${CONFIG_PATH}" --platform auto --output-dir ./service-out

echo "[marrow-bot] Setup complete."

