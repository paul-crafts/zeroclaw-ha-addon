#!/usr/bin/bashio

if bashio::config.has_value 'config_dir'; then
    CONFIG_DIR=$(bashio::config 'config_dir')
else
    CONFIG_DIR="/config"
fi
CONFIG_FILE="${CONFIG_DIR}/config.toml"
DATA_DIR="/data"

# Ensure the wrapper script respects the configured path
echo '#!/bin/sh' > /usr/local/bin/zc-onboard
echo "/usr/local/bin/zeroclaw --config-dir \"${CONFIG_DIR}\" onboard \"\$@\"" >> /usr/local/bin/zc-onboard
chmod +x /usr/local/bin/zc-onboard

bashio::log.info "Booting ZeroClaw Add-on..."

# 1. Ensure the persistent directories exist
mkdir -p "$CONFIG_DIR"
mkdir -p "$DATA_DIR"

# 2. Check if a config already exists.
if [ ! -f "$CONFIG_FILE" ]; then
    bashio::log.info "No existing configuration found at ${CONFIG_FILE}."
    bashio::log.info "You can configure it by running 'zc-onboard' in the addon terminal."
fi

# 3. Start the ZeroClaw server
bashio::log.info "Starting ZeroClaw daemon..."
exec /usr/local/bin/zeroclaw --config-dir "$CONFIG_DIR" daemon --host 0.0.0.0
