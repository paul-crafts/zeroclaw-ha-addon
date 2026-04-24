#!/usr/bin/bashio
set -e

# ── 1. Configuration ──
CONFIG_DIR=$(bashio::config 'config_dir')
INGRESS_PORT=$(bashio::addon.ingress_port)
TTYD_PORT=8099
ZEROCLAW_PORT=42617

bashio::log.info "Starting ZeroClaw initialization..."

# Ensure directories exist
mkdir -p "$CONFIG_DIR"
mkdir -p /run/nginx

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
bashio::log.info "Generating Nginx configuration..."
sed -e "s|%%INGRESS_PORT%%|${INGRESS_PORT}|g" \
    /nginx.conf.tpl > /etc/nginx/nginx.conf

# ── 4. Start Services ──

# Start ZeroClaw Daemon
bashio::log.info "Starting ZeroClaw daemon..."
zeroclaw --config-dir "$CONFIG_DIR" daemon --host 127.0.0.1 --port $ZEROCLAW_PORT &
ZEROCLAW_PID=$!

# Start ttyd (Web Terminal)
bashio::log.info "Starting Web Terminal (ttyd)..."
ttyd -p $TTYD_PORT -i 127.0.0.1 -W tmux new -A -s zeroclaw /bin/bash &
TTYD_PID=$!

# Start Nginx
bashio::log.info "Starting Nginx proxy..."
nginx -g "daemon off;" &
NGINX_PID=$!

# ── 5. Signal Handling ──
function shutdown() {
    bashio::log.info "Shutdown signal received, stopping services..."
    kill -TERM "$NGINX_PID" 2>/dev/null || true
    kill -TERM "$TTYD_PID" 2>/dev/null || true
    kill -TERM "$ZEROCLAW_PID" 2>/dev/null || true
    bashio::log.info "Shutdown complete."
    exit 0
}

trap shutdown SIGTERM SIGINT

bashio::log.info "ZeroClaw is up and running!"

# ── 6. Supervisor Loop ──
while true; do
    if ! kill -0 "$ZEROCLAW_PID" 2>/dev/null; then
        bashio::log.error "ZeroClaw daemon died, restarting..."
        zeroclaw --config-dir "$CONFIG_DIR" daemon --host 127.0.0.1 --port $ZEROCLAW_PORT &
        ZEROCLAW_PID=$!
    fi
    if ! kill -0 "$TTYD_PID" 2>/dev/null; then
        bashio::log.warn "ttyd died, restarting..."
        ttyd -p $TTYD_PORT -i 127.0.0.1 -W tmux new -A -s zeroclaw /bin/bash &
        TTYD_PID=$!
    fi
    if ! kill -0 "$NGINX_PID" 2>/dev/null; then
        bashio::log.error "Nginx died, restarting..."
        nginx -g "daemon off;" &
        NGINX_PID=$!
    fi
    sleep 10
done
