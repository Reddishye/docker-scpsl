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

# Install Box64 for ARM64 via ryanfortner repo (pre-built, ~10s instead of 60min compile)
# ponytail: pin to specific version if upstream breaking changes happen
ARG TARGETARCH
RUN ARCH=${TARGETARCH:-$(uname -m)} && \
    if [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then \
        apt-get update && apt-get install -y --no-install-recommends gnupg && \
        wget -qO- https://ryanfortner.github.io/box64-debs/KEY.gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/box64-debs-archive-keyring.gpg && \
        wget https://ryanfortner.github.io/box64-debs/box64.list -O /etc/apt/sources.list.d/box64.list && \
        apt-get update && apt-get install -y --no-install-recommends box64 && \
        apt-get purge -y gnupg && \
        apt-get autoremove --purge -y && \
        rm -rf /var/lib/apt/lists/* /etc/apt/sources.list.d/box64.list /etc/apt/trusted.gpg.d/box64-debs-archive-keyring.gpg; \
    fi

# Disable Box64 dynarec Native Flags optimization on ARM64
# (Neoverse-N1 crash in sysconf with _SC_PAGESIZE: native flags corrupts register)
ENV BOX64_DYNAREC_NATIVEFLAGS=0

# Container setup for Pterodactyl
RUN adduser --home /home/container container --disabled-password
ARG CACHBUST=1
USER container
ENV USER=container HOME=/home/container
WORKDIR /home/container

COPY ./entrypoint.sh /entrypoint.sh
CMD ["/bin/bash", "/entrypoint.sh"]
