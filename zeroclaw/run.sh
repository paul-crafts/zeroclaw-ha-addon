#!/usr/bin/with-contenv bashio
set -e

# ── 1. Configuration ──
# We read from /data/options.json directly to avoid Supervisor API token issues
OPTIONS_FILE="/data/options.json"
CONFIG_DIR=$(jq -r '.config_dir // "/config"' "$OPTIONS_FILE")
CONFIG_FILE="${CONFIG_DIR%/}/config.toml"
INGRESS_TOKEN_FILE="${CONFIG_DIR%/}/.ha_ingress_token"
INGRESS_PORT=8099
TTYD_PORT=8100
ZEROCLAW_PORT=42617
ZEROCLAW_INTERNAL_PATH_PREFIX="/"
ZEROCLAW_PUBLIC_PATH_PREFIX="$ZEROCLAW_INTERNAL_PATH_PREFIX"

echo "[INFO] Starting ZeroClaw initialization..."

# Ensure directories exist
mkdir -p "$CONFIG_DIR"
mkdir -p /run/nginx

upsert_toml_key() {
    local section="$1"
    local key="$2"
    local value="$3"
    local tmp_file
    tmp_file=$(mktemp)

    awk -v section="$section" -v key="$key" -v value="$value" '
        BEGIN {
            in_section = 0
            section_found = 0
            key_written = 0
        }
        {
            if ($0 ~ "^\\[" section "\\]$") {
                print
                in_section = 1
                section_found = 1
                next
            }

            if (in_section && $0 ~ "^\\[.*\\]$") {
                if (!key_written) {
                    print key " = " value
                    key_written = 1
                }
                in_section = 0
            }

            if (in_section && $0 ~ "^" key "[[:space:]]*=") {
                if (!key_written) {
                    print key " = " value
                    key_written = 1
                }
                next
            }

            print
        }
        END {
            if (section_found) {
                if (in_section && !key_written) {
                    print key " = " value
                }
            } else {
                print ""
                print "[" section "]"
                print key " = " value
            }
        }
    ' "$CONFIG_FILE" > "$tmp_file"

    mv "$tmp_file" "$CONFIG_FILE"
}

remove_toml_key() {
    local section="$1"
    local key="$2"
    local tmp_file
    tmp_file=$(mktemp)

    awk -v section="$section" -v key="$key" '
        BEGIN {
            in_section = 0
        }
        {
            if ($0 ~ "^\\[" section "\\]$") {
                in_section = 1
                print
                next
            }

            if (in_section && $0 ~ "^\\[.*\\]$") {
                in_section = 0
            }

            if (in_section && $0 ~ "^" key "[[:space:]]*=") {
                next
            }

            print
        }
    ' "$CONFIG_FILE" > "$tmp_file"

    mv "$tmp_file" "$CONFIG_FILE"
}

fetch_supervisor_addon_info() {
    if [ -z "${SUPERVISOR_TOKEN:-}" ]; then
        echo "[WARN] SUPERVISOR_TOKEN not available; skipping Supervisor self-info lookup."
        return 1
    fi

    curl -fsSL \
        -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
        http://supervisor/addons/self/info
}

echo "[INFO] Preparing ZeroClaw ingress configuration..."
touch "$CONFIG_FILE"

if [ ! -f "$INGRESS_TOKEN_FILE" ]; then
    tr -dc 'a-f0-9' < /dev/urandom | head -c 64 > "$INGRESS_TOKEN_FILE"
    chmod 600 "$INGRESS_TOKEN_FILE"
fi

ZEROCLAW_INGRESS_TOKEN=$(cat "$INGRESS_TOKEN_FILE")
ZEROCLAW_INGRESS_TOKEN_HASH=$(printf '%s' "$ZEROCLAW_INGRESS_TOKEN" | sha256sum | awk '{print $1}')

EXISTING_PAIRED_TOKENS_LINE=$(awk '
    /^\[gateway\]$/ { in_gateway = 1; next }
    /^\[.*\]$/ { in_gateway = 0 }
    in_gateway && /^paired_tokens[[:space:]]*=/ { print; exit }
' "$CONFIG_FILE")

if printf '%s\n' "$EXISTING_PAIRED_TOKENS_LINE" | grep -q "$ZEROCLAW_INGRESS_TOKEN_HASH"; then
    echo "[INFO] Reusing existing ingress dashboard token."
else
    if [ -n "$EXISTING_PAIRED_TOKENS_LINE" ]; then
        UPDATED_PAIRED_TOKENS_LINE="${EXISTING_PAIRED_TOKENS_LINE%]}"
        if [ "$UPDATED_PAIRED_TOKENS_LINE" = 'paired_tokens = [' ]; then
            UPDATED_PAIRED_TOKENS_LINE="paired_tokens = [\"${ZEROCLAW_INGRESS_TOKEN_HASH}\"]"
        else
            UPDATED_PAIRED_TOKENS_LINE="${UPDATED_PAIRED_TOKENS_LINE}, \"${ZEROCLAW_INGRESS_TOKEN_HASH}\"]"
        fi
    else
        UPDATED_PAIRED_TOKENS_LINE="paired_tokens = [\"${ZEROCLAW_INGRESS_TOKEN_HASH}\"]"
    fi
    upsert_toml_key "gateway" "paired_tokens" "${UPDATED_PAIRED_TOKENS_LINE#paired_tokens = }"
    echo "[INFO] Registered persistent ingress dashboard token."
fi

echo "[INFO] Querying Supervisor for addon ingress metadata..."
if SUPERVISOR_INFO_JSON=$(fetch_supervisor_addon_info 2>/dev/null); then
    SUPERVISOR_INGRESS_URL=$(printf '%s' "$SUPERVISOR_INFO_JSON" | jq -r '.data.ingress_url // empty')
    SUPERVISOR_INGRESS_ENTRY=$(printf '%s' "$SUPERVISOR_INFO_JSON" | jq -r '.data.ingress_entry // empty')
    SUPERVISOR_HOSTNAME=$(printf '%s' "$SUPERVISOR_INFO_JSON" | jq -r '.data.hostname // empty')
    echo "[INFO] Supervisor hostname: ${SUPERVISOR_HOSTNAME:-<unknown>}"
    echo "[INFO] Supervisor ingress_entry: ${SUPERVISOR_INGRESS_ENTRY:-<empty>}"
    echo "[INFO] Supervisor ingress_url: ${SUPERVISOR_INGRESS_URL:-<empty>}"

    if [ -n "${SUPERVISOR_INGRESS_ENTRY:-}" ]; then
        ZEROCLAW_PUBLIC_PATH_PREFIX="$SUPERVISOR_INGRESS_ENTRY"
    fi
else
    echo "[WARN] Unable to fetch Supervisor self-info; continuing with static ingress settings."
fi

echo "[INFO] ZeroClaw internal path prefix: ${ZEROCLAW_INTERNAL_PATH_PREFIX}"
echo "[INFO] ZeroClaw public path prefix: ${ZEROCLAW_PUBLIC_PATH_PREFIX}"
upsert_toml_key "gateway" "path_prefix" "\"${ZEROCLAW_PUBLIC_PATH_PREFIX}\""

# ── 2. Environment Setup ──
# Setup .bashrc for the terminal
if [ ! -f /root/.bashrc ]; then
    cat > /root/.bashrc << 'EOF'
# Zeroclaw environment
export PS1='\[\033[01;32m\]zeroclaw\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
alias ls='ls --color=auto'
alias ll='ls -alF'
alias zc='zeroclaw'
# Add /usr/local/bin to path if not present
[[ ":$PATH:" != *":/usr/local/bin:"* ]] && export PATH="/usr/local/bin:$PATH"
EOF
fi

# Setup .tmux.conf
if [ ! -f /root/.tmux.conf ]; then
    cat > /root/.tmux.conf << 'EOF'
set -g mouse on
set -g status-bg black
set -g status-fg white
EOF
fi

# ── 3. Nginx Setup ──
echo "[INFO] Generating Nginx configuration..."
sed -e "s|%%INGRESS_PORT%%|${INGRESS_PORT}|g" \
    -e "s|%%TTYD_PORT%%|${TTYD_PORT}|g" \
    -e "s|%%ZEROCLAW_PORT%%|${ZEROCLAW_PORT}|g" \
    -e "s|%%ZEROCLAW_PATH_PREFIX%%|${ZEROCLAW_INTERNAL_PATH_PREFIX}|g" \
    -e "s|%%ZEROCLAW_INGRESS_TOKEN%%|${ZEROCLAW_INGRESS_TOKEN}|g" \
    /nginx.conf.tpl > /etc/nginx/nginx.conf

# ── 4. Start Services ──

# Start ZeroClaw Daemon
echo "[INFO] Starting ZeroClaw daemon..."
zeroclaw --config-dir "$CONFIG_DIR" daemon --host 127.0.0.1 --port $ZEROCLAW_PORT &
ZEROCLAW_PID=$!

# Start ttyd (Web Terminal)
echo "[INFO] Starting Web Terminal (ttyd)..."
ttyd -p $TTYD_PORT -i 127.0.0.1 -b /terminal -W tmux new -A -s zeroclaw /bin/bash &
TTYD_PID=$!

# Start Nginx
echo "[INFO] Starting Nginx proxy..."
sleep 2
nginx -g "daemon off;" &
NGINX_PID=$!

# ── 5. Signal Handling ──
function shutdown() {
    echo "[INFO] Shutdown signal received, stopping services..."
    kill -TERM "$NGINX_PID" 2>/dev/null || true
    kill -TERM "$TTYD_PID" 2>/dev/null || true
    kill -TERM "$ZEROCLAW_PID" 2>/dev/null || true
    echo "[INFO] Shutdown complete."
    exit 0
}

trap shutdown SIGTERM SIGINT

echo "[INFO] ZeroClaw is up and running!"

# ── 6. Supervisor Loop ──
while true; do
    if ! kill -0 "$ZEROCLAW_PID" 2>/dev/null; then
        echo "[ERROR] ZeroClaw daemon died, restarting..."
        zeroclaw --config-dir "$CONFIG_DIR" daemon --host 127.0.0.1 --port $ZEROCLAW_PORT &
        ZEROCLAW_PID=$!
    fi
    if ! kill -0 "$TTYD_PID" 2>/dev/null; then
        echo "[WARN] ttyd died, restarting..."
        ttyd -p $TTYD_PORT -i 127.0.0.1 -b /terminal -W tmux new -A -s zeroclaw /bin/bash &
        TTYD_PID=$!
    fi
    if ! kill -0 "$NGINX_PID" 2>/dev/null; then
        echo "[ERROR] Nginx died, restarting..."
        nginx -g "daemon off;" &
        NGINX_PID=$!
    fi
    sleep 10
done
