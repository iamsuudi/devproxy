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

# ----------------------------
# Detect Port
# ----------------------------
get_port() {
    if [[ -f "$PORT_FILE" ]]; then
        cat "$PORT_FILE"
        return
    fi
    while true; do
        read -p "Enter backend port (e.g., 3001): " PORT
        [[ "$PORT" =~ ^[0-9]+$ ]] && break
        echo_color "$RED" "Port must be numeric."
    done
    echo "$PORT" > "$PORT_FILE"
    echo "$PORT"
}

# ----------------------------
# Generate SSL
# ----------------------------
make_ssl() {
    IP="$1"
    echo_color "$CYAN" "Generating SSL certificate..." 

    CFG=$(mktemp)
    cat > "$CFG" <<EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = v3_req

[dn]
CN = $PROJECT_NAME.local

[v3_req]
subjectAltName = IP:$IP
EOF

    openssl req -x509 -nodes -days 365 \
        -newkey rsa:2048 \
        -keyout "$SSL_KEY" \
        -out "$SSL_CERT" \
        -config "$CFG"

    rm -f "$CFG"
    echo_color "$GREEN" "SSL created at $SSL_CERT"
}

# ----------------------------
# Generate nginx.conf
# ----------------------------
make_nginx_conf() {
    PORT="$1"
    IP="$2"
    cat > "$NGINX_CONF" <<EOF
server {
    listen 443 ssl;
    server_name _;

    ssl_certificate     /etc/nginx/certs/server.crt;
    ssl_certificate_key /etc/nginx/certs/server.key;

    location / {
        proxy_pass http://host.docker.internal:$PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}

server {
    listen 80;
    server_name _;
    return 301 https://\$host\$uri;
}
EOF
    echo_color "$GREEN" "nginx config created at $NGINX_CONF"
}

# ----------------------------
# Generate Dockerfile
# ----------------------------
make_dockerfile() {
    cat > "$DOCKERFILE" <<EOF
FROM nginx:alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY server.crt /etc/nginx/certs/server.crt
COPY server.key /etc/nginx/certs/server.key
CMD ["nginx", "-g", "daemon off;"]
EOF
    echo_color "$GREEN" "Dockerfile created at $DOCKERFILE"
}

# ----------------------------
# Start Docker container
# ----------------------------
start_docker() {
    PORT="$1"
    IP="$2"
    docker rm -f "$DOCKER_CONTAINER" >/dev/null 2>&1 || true
    docker build -t "${PROJECT_NAME}-nginx" "$DEVPROXY_DIR"
    echo_color "$CYAN" "Starting Docker container..."
    docker run -d --name "$DOCKER_CONTAINER" \
        --add-host=host.docker.internal:host-gateway \
        -p 443:443 -p 80:80 \
        "${PROJECT_NAME}-nginx"
    echo_color "$GREEN" "Container running. Access at https://$IP"
}

# ----------------------------
# Stop Docker container
# ----------------------------
stop_docker() {
    docker rm -f "$DOCKER_CONTAINER" >/dev/null 2>&1 || true
    echo_color "$GREEN" "Container stopped."
}

# ----------------------------
# Status
# ----------------------------
status_docker() {
    if docker ps --filter "name=$DOCKER_CONTAINER" --format '{{.Names}}' | grep -q "$DOCKER_CONTAINER"; then
        echo_color "$GREEN" "Container '$DOCKER_CONTAINER' is running."
    else
        echo_color "$YELLOW" "Container '$DOCKER_CONTAINER' is not running."
    fi
}

# ----------------------------
# CLI
# ----------------------------
CMD="$1"
shift || true

case "$CMD" in
    init)
        PORT=$(get_port)
        IP=$(detect_ip)
        make_ssl "$IP"
        make_nginx_conf "$PORT" "$IP"
        make_dockerfile
        ;;
    start)
        PORT=$(get_port)
        IP=$(cat "$IP_FILE")
        start_docker "$PORT" "$IP"
        ;;
    stop)
        stop_docker
        ;;
    regen)
        PORT=$(get_port)
        IP=$(cat "$IP_FILE")
        make_ssl "$IP"
        make_nginx_conf "$PORT" "$IP"
        make_dockerfile
        ;;
    status)
        status_docker
        ;;
    *)
        echo_color "$CYAN" "Usage: devproxy <init|start|stop|regen|status>"
        ;;
esac