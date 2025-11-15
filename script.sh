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

# ----------------------------
# Paths
# ----------------------------
PROJECT_DIR=$(pwd)
PROJECT_NAME=$(basename "$PROJECT_DIR")
DEVPROXY_DIR="$PROJECT_DIR/.devproxy"
IP_FILE="$DEVPROXY_DIR/ip"
PORT_FILE="$DEVPROXY_DIR/port"
SSL_CERT="$DEVPROXY_DIR/server.crt"
SSL_KEY="$DEVPROXY_DIR/server.key"
NGINX_CONF="$DEVPROXY_DIR/nginx.conf"
DOCKERFILE="$DEVPROXY_DIR/Dockerfile"
DOCKER_CONTAINER="${PROJECT_NAME}-nginx"

mkdir -p "$DEVPROXY_DIR"