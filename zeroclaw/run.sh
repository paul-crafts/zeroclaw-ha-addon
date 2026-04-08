#!/usr/bin/bashio

# Create data directory for persistent configuration if it doesn't exist
mkdir -p /data/zeroclaw

bashio::log.info "Initializing ZeroClaw Add-on..."

bashio::log.info "Starting ZeroClaw daemon..."
exec /usr/local/bin/zeroclaw --config-dir /data/zeroclaw daemon
