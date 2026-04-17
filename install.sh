#!/usr/bin/env bash
set -e

ATLAS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INTEGRATION="claude-code"

# Parse flags
EXTRA_ARGS=()
for arg in "$@"; do
  case $arg in
    --integration=*)
      INTEGRATION="${arg#*=}"
      ;;
    *)
      EXTRA_ARGS+=("$arg")
      ;;
  esac
done

INTEGRATION_SCRIPT="$ATLAS_DIR/integrations/$INTEGRATION/install.sh"

if [ ! -f "$INTEGRATION_SCRIPT" ]; then
  echo "Error: no integration found for '$INTEGRATION'."
  echo ""
  echo "Available integrations:"
  for d in "$ATLAS_DIR/integrations/"/*/; do
    [ -d "$d" ] && echo "  $(basename "$d")"
  done
  echo ""
  echo "Usage: ./install.sh [--integration=<name>] [--per-repo] [--repo=<path>] [--full]"
  echo ""
  echo "  --skill      Install as a single self-contained atlas skill (default)"
  echo "  --full       Install 5 commands + 5 individual skills (classic mode)"
  echo "  --per-repo   Install into .claude/ instead of ~/.claude/"
  exit 1
fi

bash "$INTEGRATION_SCRIPT" "${EXTRA_ARGS[@]}"
