#!/bin/bash
# Mock bashio and test run.sh logic

# Mocking bashio functions
bashio::config() {
    if [ "$1" == "config_dir" ]; then
        echo "/tmp/zeroclaw_config"
    fi
}

bashio::addon.ingress_port() {
    echo "8099"
}

bashio::log.info() {
    echo "[INFO] $1"
}

bashio::log.error() {
    echo "[ERROR] $1"
}

export -f bashio::config
export -f bashio::addon.ingress_port
export -f bashio::log.info
export -f bashio::log.error

# Mocking other commands
alias zeroclaw='echo "MOCKED zeroclaw"'
alias ttyd='echo "MOCKED ttyd"'
alias nginx='echo "MOCKED nginx"'
shopt -s expand_aliases

echo "Running tests for run.sh..."

# Test 1: Check if run.sh can be parsed
bash -n ../run.sh
if [ $? -eq 0 ]; then
    echo "✅ run.sh syntax is valid"
else
    echo "❌ run.sh syntax error"
    exit 1
fi

# Test 2: Check Nginx template generation (Dry run)
CONFIG_DIR="/tmp/zeroclaw_config"
INGRESS_PORT="8099"
mkdir -p "$CONFIG_DIR"
mkdir -p /tmp/run/nginx

# Mocking sed for template check
sed -e "s|%%INGRESS_PORT%%|${INGRESS_PORT}|g" \
    ../nginx.conf.tpl > /tmp/nginx.conf

if grep -q "listen 8099;" /tmp/nginx.conf; then
    echo "✅ Nginx config generation successful"
else
    echo "❌ Nginx config generation failed"
    exit 1
fi

echo "All tests passed! (MOCKED)"
rm -rf /tmp/zeroclaw_config /tmp/run/nginx /tmp/nginx.conf
