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
alias curl='echo "{\"data\":{\"ingress_url\":\"/api/hassio_ingress/test-session/zeroclaw\",\"ingress_entry\":\"/api/hassio_ingress/test-session\",\"hostname\":\"771b918e_zeroclaw\"}}"'
shopt -s expand_aliases
export SUPERVISOR_TOKEN="test-supervisor-token"

echo "Running tests for run.sh..."

# Test 1: Check if run.sh can be parsed
if bash -n ../run.sh; then
    echo "✅ run.sh syntax is valid"
else
    echo "❌ run.sh syntax error"
    exit 1
fi

# Test 2: Check Nginx template generation (Dry run)
CONFIG_DIR="/tmp/zeroclaw_config"
INGRESS_PORT="8099"
TTYD_PORT="8100"
ZEROCLAW_PORT="42617"
ZEROCLAW_INGRESS_TOKEN="test-ingress-token"
ZEROCLAW_UPSTREAM_PATH_PREFIX="/api/hassio_ingress/test-session/dashboard"
mkdir -p "$CONFIG_DIR"
mkdir -p /tmp/run/nginx

# Mocking sed for template check
sed -e "s|%%INGRESS_PORT%%|${INGRESS_PORT}|g" \
    -e "s|%%TTYD_PORT%%|${TTYD_PORT}|g" \
    -e "s|%%ZEROCLAW_PORT%%|${ZEROCLAW_PORT}|g" \
    -e "s|%%ZEROCLAW_UPSTREAM_PATH_PREFIX%%|${ZEROCLAW_UPSTREAM_PATH_PREFIX}|g" \
    -e "s|%%ZEROCLAW_INGRESS_TOKEN%%|${ZEROCLAW_INGRESS_TOKEN}|g" \
    ../nginx.conf.tpl > /tmp/nginx.conf

if grep -q "listen 8099;" /tmp/nginx.conf; then
    echo "✅ Nginx config generation successful"
else
    echo "❌ Nginx config generation failed"
    exit 1
fi

if grep -q 'proxy_set_header Authorization "Bearer test-ingress-token";' /tmp/nginx.conf && \
   grep -q 'location /dashboard/ {' /tmp/nginx.conf; then
    echo "✅ Ingress auth header wiring successful"
else
    echo "❌ Ingress auth header wiring failed"
    exit 1
fi

if grep -q 'location = / {' /tmp/nginx.conf && \
   grep -q 'proxy_pass http://zeroclaw_daemon/api/hassio_ingress/test-session/dashboard/;' /tmp/nginx.conf && \
   grep -q 'proxy_redirect ~^(/.*)$ \$scheme://\$http_host\$http_x_ingress_path\$1;' /tmp/nginx.conf; then
    echo "✅ Landing and dashboard routing successful"
else
    echo "❌ Landing and dashboard routing failed"
    exit 1
fi

if grep -q 'SUPERVISOR_TOKEN="test-supervisor-token"' <(declare -p SUPERVISOR_TOKEN 2>/dev/null); then
    echo "✅ Supervisor metadata lookup mocked"
else
    echo "❌ Supervisor metadata lookup mock failed"
    exit 1
fi

if grep -q 'ingress_url\\":\\"/api/hassio_ingress/test-session/zeroclaw' <(alias curl) ; then
    echo "✅ Supervisor ingress URL mock successful"
else
    echo "❌ Supervisor ingress URL mock failed"
    exit 1
fi

if grep -q 'join_path_prefix' ../run.sh && \
   grep -q 'ZEROCLAW_PUBLIC_PATH_PREFIX=$(join_path_prefix "\$SUPERVISOR_INGRESS_ENTRY" "\$ZEROCLAW_INTERNAL_PATH_PREFIX")' ../run.sh; then
    echo "✅ Dashboard public prefix join logic present"
else
    echo "❌ Dashboard public prefix join logic missing"
    exit 1
fi

echo "All tests passed! (MOCKED)"
rm -rf /tmp/zeroclaw_config /tmp/run/nginx /tmp/nginx.conf
