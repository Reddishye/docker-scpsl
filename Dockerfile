# syntax=docker/dockerfile:1
FROM debian:trixie-slim
LABEL maintainer="EsserGaming"
USER root

# Grab the essentials
RUN apt-get update && apt-get install -y --no-install-recommends \
    adduser \
    libicu76 \
    ca-certificates \
    curl \
    wget \
    ffmpeg && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Build Box64 for ARM64 (Oracle Ampere / Raspberry Pi / etc)
ARG TARGETARCH
RUN ARCH=${TARGETARCH:-$(uname -m)} && \
    if [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then \
        apt-get update && apt-get install -y --no-install-recommends \
            git ca-certificates cmake build-essential python3 && \
        git clone --depth=1 https://github.com/ptitSeb/box64.git /tmp/box64 && \
        cd /tmp/box64 && mkdir build && cd build && \
        cmake .. -DARM_DYNAREC=ON -DCMAKE_BUILD_TYPE=Release && \
        make -j$(nproc) && make install && \
        rm -rf /tmp/box64 && \
        apt-get purge -y git ca-certificates cmake build-essential python3 && \
        apt-get autoremove --purge -y && \
        rm -rf /var/lib/apt/lists/*; \
    fi

# Container setup for Pterodactyl
RUN adduser --home /home/container container --disabled-password
ARG CACHBUST=1
USER container
ENV USER=container HOME=/home/container
WORKDIR /home/container

COPY ./entrypoint.sh /entrypoint.sh
CMD ["/bin/bash", "/entrypoint.sh"]
