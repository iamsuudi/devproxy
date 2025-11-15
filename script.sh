#!/usr/bin/env bash
set -e

# ----------------------------
# Colors
# ----------------------------
CYAN="\033[1;36m"
GREEN="\033[1;32m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
RESET="\033[0m"

echo_color() { echo -e "$1$2$RESET"; }

# ----------------------------
# CLI
# ----------------------------
CMD="$1"
shift || true

case "$CMD" in
    *)
        echo_color "$CYAN" "Usage: devproxy <init|start|stop|regen|status>"
        ;;
esac