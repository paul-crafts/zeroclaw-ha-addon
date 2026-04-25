#!/usr/bin/with-contenv bashio
set -e

# ── 1. Configuration & Paths ──
# Get config_dir from HA options, defaulting to /config
BASE_CONFIG_DIR=$(bashio::config 'config_dir' "/config")
ZEROCLAW_DATA_DIR="${BASE_CONFIG_DIR%/}/zeroclaw"

# Internal paths
ROOT_ZEROCLAW_DIR="/root/.zeroclaw"
CONFIG_FILE="${ZEROCLAW_DATA_DIR}/config.toml"
INGRESS_TOKEN_FILE="${ZEROCLAW_DATA_DIR}/.ha_ingress_token"

# Port mapping
INGRESS_PORT=8099
TTYD_PORT=8100
ZEROCLAW_PORT=42617

echo "[INFO] Persistent storage located at: ${ZEROCLAW_DATA_DIR}"

# ── 2. Helper Functions ──

# Updates or inserts keys into the TOML configuration file
upsert_toml_key() {
    local section="$1"
    local key="$2"
    local value="$3"
    local tmp_file
    tmp_file=$(mktemp)

    awk -v section="$section" -v key="$key" -v value="$value" '
        BEGIN { in_section = 0; section_found = 0; key_written = 0 }
        {
            if ($0 ~ "^\\[" section "\\]$") { print; in_section = 1; section_found = 1; next }
            if (in_section && $0 ~ "^\\[.*\\]$") {
                if (!key_written) { print key " = " value; key_written = 1 }
                in_section = 0
            }
            if (in_section && $0 ~ "^" key "[[:space:]]*=") {
                if (!key_written) { print key " = " value; key_written = 1 }
                next
            }
            print
        }
        END {
            if (section_found) {
                if (in_section && !key_written) { print key " = " value }
            } else {
                print "\n[" section "]\n" key " = " value
            }
        }
    ' "$CONFIG_FILE" > "$tmp_file"
    mv "$tmp_file" "$CONFIG_FILE"
}

# ── 3. Directory & Symlink Setup ──
# Create target directory first
mkdir -p "$ZEROCLAW_DATA_DIR"
mkdir -p /run/nginx

# Robust symlink handling to prevent first-run crashes:
if [ ! -L "$ROOT_ZEROCLAW_DIR" ] && [ -d "$ROOT_ZEROCLAW_DIR" ]; then
    echo "[INFO] Migrating existing local data to persistent storage..."
    # '|| true' ensures script continues if directory is empty or busy
    cp -rp "$ROOT_ZEROCLAW_DIR/." "$ZEROCLAW_DATA_DIR/" || true
    rm -rf "$ROOT_ZEROCLAW_DIR"
fi

# Force symbolic link creation (f=force, n=no-dereference)
ln -sfn "$ZEROCLAW_DATA_DIR" "$ROOT_ZEROCLAW_DIR"

# Set application environment
export ZEROCLAW_CONFIG_DIR="$ROOT_ZEROCLAW_DIR"
export ZEROCLAW_WORKSPACE="${ROOT_ZEROCLAW_DIR}/workspace"
mkdir -p "$ZEROCLAW_WORKSPACE"

# ── 4. Ingress & TOML Setup ──
if [ ! -f "$CONFIG_FILE" ]; then
    touch "$CONFIG_FILE"
fi

# Manage the unique Ingress Token
if [ ! -f "$INGRESS_TOKEN_FILE" ]; then
    echo "[INFO] Creating new Ingress token..."
    tr -dc 'a-f0-9' < /dev/urandom | head -c 64 > "$INGRESS_TOKEN_FILE" || true
    chmod 600 "$INGRESS_TOKEN_FILE" || true
fi

ZEROCLAW_INGRESS_TOKEN=$(cat "$INGRESS_TOKEN_FILE")
ZEROCLAW_INGRESS_TOKEN_HASH=$(printf '%s' "$ZEROCLAW_INGRESS_TOKEN" | sha256sum | awk '{print $1}')

# Write necessary gateway settings to config.toml
upsert_toml_key "gateway" "paired_tokens" "[\"${ZEROCLAW_INGRESS_TOKEN_HASH}\"]"
upsert_toml_key "gateway" "path_prefix" "\"/dashboard\""
upsert_toml_key "gateway" "require_pairing" "false"

# ── 5. Environment & Proxy Setup ──
if [ ! -f /root/.bashrc ]; then
    cat > /root/.bashrc << 'EOF'
export PS1='\[\033[01;32m\]zeroclaw\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
alias ls='ls --color=auto'
alias ll='ls -alF'
alias zc='zeroclaw'
[[ ":$PATH:" != *":/usr/local/bin:"* ]] && export PATH="/usr/local/bin:$PATH"
EOF
fi

# Generate Nginx config from template
sed -e "s|%%INGRESS_PORT%%|${INGRESS_PORT}|g" \
    -e "s|%%TTYD_PORT%%|${TTYD_PORT}|g" \
    -e "s|%%ZEROCLAW_PORT%%|${ZEROCLAW_PORT}|g" \
    -e "s|%%ZEROCLAW_UPSTREAM_PATH_PREFIX%%|/dashboard|g" \
    -e "s|%%ZEROCLAW_PUBLIC_PATH_PREFIX%%|/dashboard|g" \
    -e "s|%%ZEROCLAW_INGRESS_TOKEN%%|${ZEROCLAW_INGRESS_TOKEN}|g" \
    /nginx.conf.tpl > /etc/nginx/nginx.conf

# ── 6. Service Management ──

function shutdown() {
    echo "[INFO] Shutdown signal received, stopping services..."
    kill -TERM "$NGINX_PID" "$TTYD_PID" "$ZEROCLAW_PID" 2>/dev/null || true
    exit 0
}
trap shutdown SIGTERM SIGINT

echo "[INFO] Starting ZeroClaw daemon..."
zeroclaw --config-dir "$ROOT_ZEROCLAW_DIR" daemon --host 127.0.0.1 --port $ZEROCLAW_PORT &
ZEROCLAW_PID=$!

echo "[INFO] Starting Web Terminal..."
ttyd -p $TTYD_PORT -i 127.0.0.1 -b /terminal -W env ZEROCLAW_CONFIG_DIR="$ROOT_ZEROCLAW_DIR" ZEROCLAW_WORKSPACE="$ZEROCLAW_WORKSPACE" tmux new -A -s zeroclaw /bin/bash &
TTYD_PID=$!

# Wait for internal services to bind before starting proxy
sleep 3

echo "[INFO] Starting Nginx proxy..."
nginx -g "daemon off;" &
NGINX_PID=$!

echo "[INFO] ZeroClaw is ready."

# ── 7. Health Monitor Loop ──
while true; do
    if ! kill -0 "$ZEROCLAW_PID" 2>/dev/null; then
        echo "[ERROR] ZeroClaw daemon died, restarting..."
        zeroclaw --config-dir "$ROOT_ZEROCLAW_DIR" daemon --host 127.0.0.1 --port $ZEROCLAW_PORT &
        ZEROCLAW_PID=$!
    fi
    if ! kill -0 "$TTYD_PID" 2>/dev/null; then
        echo "[WARN] ttyd died, restarting..."
        ttyd -p $TTYD_PORT -i 127.0.0.1 -b /terminal -W env ZEROCLAW_CONFIG_DIR="$ROOT_ZEROCLAW_DIR" ZEROCLAW_WORKSPACE="$ZEROCLAW_WORKSPACE" tmux new -A -s zeroclaw /bin/bash &
        TTYD_PID=$!
    fi
    if ! kill -0 "$NGINX_PID" 2>/dev/null; then
        echo "[ERROR] Nginx died, restarting..."
        nginx -g "daemon off;" &
        NGINX_PID=$!
    fi
    sleep 10
done