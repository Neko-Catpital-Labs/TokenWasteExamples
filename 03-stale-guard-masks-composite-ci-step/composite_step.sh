#!/usr/bin/env bash
# The actual shape of required-fast/Guardrails: one CI step that shells out
# to several unrelated check scripts in sequence under `set -e`. If check 1
# fails, checks 2-6 never run at all -- their real status stays unknown.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUARD_SCRIPT="$1"

bash "$SCRIPT_DIR/$GUARD_SCRIPT"
bash "$SCRIPT_DIR/check-06.sh"
bash "$SCRIPT_DIR/check-07.sh"
bash "$SCRIPT_DIR/check-08.sh"
bash "$SCRIPT_DIR/check-09.sh"
bash "$SCRIPT_DIR/check-10.sh"
