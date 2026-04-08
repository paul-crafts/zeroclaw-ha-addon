ARG BUILD_FROM=ghcr.io/home-assistant/aarch64-base-debian:latest
FROM $BUILD_FROM

# Build arguments provided by Home Assistant Supervisor
ARG BUILD_ARCH=aarch64
ENV ZEROCLAW_VERSION="v0.6.8"

# Install necessary runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl ca-certificates tar bash jq && \
    rm -rf /var/lib/apt/lists/*

# Download the appropriate ZeroClaw binary based on the architecture
RUN echo "Building for architecture: ${BUILD_ARCH}" && \
    if [ "${BUILD_ARCH}" = "aarch64" ]; then \
        URL="https://github.com/zeroclaw-labs/zeroclaw/releases/download/${ZEROCLAW_VERSION}/zeroclaw-aarch64-unknown-linux-gnu.tar.gz"; \
    elif [ "${BUILD_ARCH}" = "amd64" ]; then \
        URL="https://github.com/zeroclaw-labs/zeroclaw/releases/download/${ZEROCLAW_VERSION}/zeroclaw-x86_64-unknown-linux-gnu.tar.gz"; \
    elif [ "${BUILD_ARCH}" = "armv7" ]; then \
        URL="https://github.com/zeroclaw-labs/zeroclaw/releases/download/${ZEROCLAW_VERSION}/zeroclaw-armv7-unknown-linux-gnueabihf.tar.gz"; \
    else \
        echo "Unsupported architecture: ${BUILD_ARCH}"; \
        exit 1; \
    fi && \
    curl -sL "$URL" | tar -xz -C /usr/local/bin && \
    chmod +x /usr/local/bin/zeroclaw

# Copy initialization script
COPY run.sh /
RUN chmod a+x /run.sh

CMD [ "/run.sh" ]
