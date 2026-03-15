#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BOT_DIR="${BOT_DIR:-${SCRIPT_DIR}}"
DEFAULT_CORE_DIR="$(cd "${BOT_DIR}/.." && pwd)/marrow-core"
if [[ -d "${DEFAULT_CORE_DIR}" ]]; then
  CORE_DIR="${CORE_DIR:-${DEFAULT_CORE_DIR}}"
else
  CORE_DIR="${CORE_DIR:-/opt/marrow-core}"
fi
WORKSPACE="${WORKSPACE:-${HOME:-/Users/marrow}}"
CONFIG_PATH="${CONFIG_PATH:-${BOT_DIR}/.runtime-config.toml}"
SERVICE_OUT_DIR="${SERVICE_OUT_DIR:-${BOT_DIR}/service-out}"
SERVICE_MODE="${SERVICE_MODE:-single_user}"
AGENT_USER="${AGENT_USER:-$(id -un)}"

echo "[marrow-bot] Using CORE_DIR=${CORE_DIR}"
echo "[marrow-bot] Using BOT_DIR=${BOT_DIR}"
echo "[marrow-bot] Using WORKSPACE=${WORKSPACE}"
echo "[marrow-bot] Using CONFIG_PATH=${CONFIG_PATH}"
echo "[marrow-bot] Using SERVICE_OUT_DIR=${SERVICE_OUT_DIR}"

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

if ! command -v uv >/dev/null 2>&1; then
  echo "[marrow-bot] ERROR: uv is required to run the local marrow-core checkout." >&2
  exit 1
fi

if ! command -v opencode >/dev/null 2>&1; then
  echo "[marrow-bot] ERROR: opencode is required but was not found on PATH." >&2
  exit 1
fi

OPENCODE_BIN="${OPENCODE_BIN:-$(command -v opencode)}"

echo "[marrow-bot] Rendering roles via role-forge..."
uvx role-forge render --project-dir "${BOT_DIR}" --yes

echo "[marrow-bot] Generating runtime config at ${CONFIG_PATH}..."
BOT_DIR="${BOT_DIR}" WORKSPACE="${WORKSPACE}" CONFIG_PATH="${CONFIG_PATH}" SERVICE_MODE="${SERVICE_MODE}" AGENT_USER="${AGENT_USER}" OPENCODE_BIN="${OPENCODE_BIN}" python3 - <<'PY'
from __future__ import annotations

import json
import os
from pathlib import Path

bot_dir = Path(os.environ["BOT_DIR"]).resolve()
workspace = Path(os.environ["WORKSPACE"]).resolve()
config_path = Path(os.environ["CONFIG_PATH"]).resolve()
service_mode = os.environ["SERVICE_MODE"].strip() or "single_user"
agent_user = os.environ["AGENT_USER"].strip() or "marrow"
opencode_bin = Path(os.environ["OPENCODE_BIN"]).resolve()

workspace_context_dir = workspace / "context.d"
text = "\n".join(
    [
        "[profile]",
        f"root_dir = {json.dumps(str(bot_dir))}",
        f"source_context_dir = {json.dumps(str(bot_dir / 'context.d'))}",
        "",
        "[service]",
        f"mode = {json.dumps(service_mode)}",
        "",
        "[ipc]",
        "enabled = true",
        "",
        "[self_check]",
        "enabled = true",
        "interval_seconds = 900",
        "wake_agent = \"orchestrator\"",
        "",
        "[sync]",
        "enabled = false",
        "",
        "[[agents]]",
        f"user = {json.dumps(agent_user)}",
        "name = \"orchestrator\"",
        "heartbeat_interval = 10800",
        "heartbeat_timeout = 7200",
        f"workspace = {json.dumps(str(workspace))}",
        f"agent_command = {json.dumps(str(opencode_bin) + ' run --agent orchestrator')}",
        f"context_dirs = [{json.dumps(str(workspace_context_dir))}]",
        "",
    ]
)
config_path.write_text(text, encoding="utf-8")
PY

echo "[marrow-bot] Ensuring workspace structure via marrow-core setup..."
uv run --directory "${CORE_DIR}" marrow-core setup --config "${CONFIG_PATH}"

echo "[marrow-bot] Installing context providers into ${WORKSPACE}/context.d ..."
mkdir -p "${WORKSPACE}/context.d"
for script in "${BOT_DIR}"/context.d/*.py; do
  install -m 0755 "${script}" "${WORKSPACE}/context.d/$(basename "${script}")"
done

echo "[marrow-bot] Validating profile via local marrow-core checkout..."
uv run --directory "${CORE_DIR}" marrow-core validate --config "${CONFIG_PATH}"
uv run --directory "${CORE_DIR}" marrow-core doctor --config "${CONFIG_PATH}"
uv run --directory "${CORE_DIR}" marrow-core dry-run --config "${CONFIG_PATH}" >/dev/null
uv run --directory "${CORE_DIR}" marrow-core install-service --config "${CONFIG_PATH}" --platform auto --output-dir "${SERVICE_OUT_DIR}"

echo "[marrow-bot] Setup complete."
echo "[marrow-bot] Config: ${CONFIG_PATH}"
echo "[marrow-bot] Service files: ${SERVICE_OUT_DIR}"
