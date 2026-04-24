ARG BUILD_FROM
FROM $BUILD_FROM

# Build arguments provided by Home Assistant Supervisor
ARG BUILD_ARCH=aarch64
ENV ZEROCLAW_VERSION="v0.6.8"

# Install necessary runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        ca-certificates \
        tar \
        bash \
        jq \
        nginx \
        tmux \
        bash-completion \
    && rm -rf /var/lib/apt/lists/*

# Download the appropriate ZeroClaw and ttyd binaries based on the architecture
RUN echo "Building for architecture: ${BUILD_ARCH}" && \
    if [ "${BUILD_ARCH}" = "aarch64" ]; then \
        ZC_URL="https://github.com/zeroclaw-labs/zeroclaw/releases/download/${ZEROCLAW_VERSION}/zeroclaw-aarch64-unknown-linux-gnu.tar.gz"; \
        TTYD_URL="https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.aarch64"; \
    elif [ "${BUILD_ARCH}" = "amd64" ]; then \
        ZC_URL="https://github.com/zeroclaw-labs/zeroclaw/releases/download/${ZEROCLAW_VERSION}/zeroclaw-x86_64-unknown-linux-gnu.tar.gz"; \
        TTYD_URL="https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.x86_64"; \
    elif [ "${BUILD_ARCH}" = "armv7" ]; then \
        ZC_URL="https://github.com/zeroclaw-labs/zeroclaw/releases/download/${ZEROCLAW_VERSION}/zeroclaw-armv7-unknown-linux-gnueabihf.tar.gz"; \
        TTYD_URL="https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.armhf"; \
    else \
        echo "Unsupported architecture: ${BUILD_ARCH}"; \
        exit 1; \
    fi && \
    curl -sL "$ZC_URL" | tar -xz -C /usr/local/bin && \
    curl -sL "$TTYD_URL" -o /usr/local/bin/ttyd && \
    chmod +x /usr/local/bin/zeroclaw /usr/local/bin/ttyd

# Create a wrapper script for onboarding
RUN echo '#!/bin/sh' > /usr/local/bin/zc-onboard && \
    echo 'exec /usr/local/bin/zeroclaw --config-dir /config onboard "$@"' >> /usr/local/bin/zc-onboard && \
    chmod +x /usr/local/bin/zc-onboard

# Set up Nginx directories
RUN mkdir -p /var/www /var/log/nginx /run/nginx

# Copy initialization script and templates
COPY run.sh /
COPY nginx.conf.tpl /
COPY landing.html /var/www/index.html
RUN chmod a+x /run.sh

CMD [ "/run.sh" ]
