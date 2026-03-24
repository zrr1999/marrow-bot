#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

# Render agent definitions from role templates
role-forge render --project-dir . --yes

# Set up profile: validate, prepare home, workspace setup, dry-run
uvx marrow-core profile-setup --config ./marrow.toml "$@"
