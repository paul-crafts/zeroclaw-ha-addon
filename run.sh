#!/usr/bin/bashio

# Create data directory for persistent configuration if it doesn't exist
mkdir -p /data/zeroclaw

bashio::log.info "Initializing ZeroClaw Add-on..."

# Optionally, you could extract options from HA UI configuration here, e.g.:
# PROVIDER=$(bashio::config 'provider')
# MODEL=$(bashio::config 'model')
# GATEWAY_PORT=$(bashio::config 'gateway_port')
# bashio::log.info "Configured to use provider: ${PROVIDER} and model: ${MODEL}"

bashio::log.info "Starting ZeroClaw daemon..."
exec /usr/local/bin/zeroclaw --config-dir /data/zeroclaw daemon
