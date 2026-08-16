#!/usr/bin/env bash
# Stands in for Invoker's own delete-all command AFTER #9290/#9291/#9305/
# #9306 intentionally removed its production-DB guard. Runs unconditionally
# now -- this is the correct, current, intended behavior.
set -euo pipefail
echo "All workflows deleted."
