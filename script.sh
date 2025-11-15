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

# ----------------------------
# Detect LAN IP
# ----------------------------
detect_ip() {
    # Return persisted IP if exists
    if [[ -f "$IP_FILE" ]]; then
        cat "$IP_FILE"
        return
    fi

    echo_color "$CYAN" "Detecting LAN IP..." >&2
    IPS=$(ip -4 -o addr show \
        | awk '!/docker|br-|virbr|veth|lo|tailscale|wg0/ {print $4}' \
        | cut -d/ -f1)

    if [[ -z "$IPS" ]]; then
        echo_color "$YELLOW" "Could not detect via 'ip'. Trying hostname -I..." >&2
        IPS=$(hostname -I 2>/dev/null | awk '{print $1}')
    fi

    if [[ -z "$IPS" ]]; then
        echo_color "$RED" "No LAN IP detected." >&2
        read -p "Enter LAN IP manually: " manual_ip
        echo "$manual_ip"
        echo "$manual_ip" > "$IP_FILE"
        echo "$manual_ip"
        return
    fi

    COUNT=$(echo "$IPS" | wc -l)
    if [[ "$COUNT" -eq 1 ]]; then
        echo_color "$GREEN" "Using IP: $IPS" >&2
        echo "$IPS" > "$IP_FILE"
        echo "$IPS"
        return
    fi

    echo_color "$YELLOW" "Multiple LAN IPs detected:" >&2
    echo "$IPS" | nl >&2
    read -p "Choose IP number: " choice
    SELECTED=$(echo "$IPS" | sed -n "${choice}p")
    if [[ -z "$SELECTED" ]]; then
        read -p "Enter IP manually: " manual_ip
        echo "$manual_ip" > "$IP_FILE"
        echo "$manual_ip"
    else
        echo "$SELECTED" > "$IP_FILE"
        echo "$SELECTED"
    fi
}