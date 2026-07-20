# syntax=docker/dockerfile:1
ARG TARGETARCH

FROM debian:bullseye-slim AS base-amd64
FROM weilbyte/box:arm64v8-debian-11 AS base-arm64

FROM base-${TARGETARCH}
LABEL maintainer="EsserGaming"
ENTRYPOINT []
USER root

# Install essential packages + x86_64 multiarch libraries for box64 emulation
RUN dpkg --add-architecture amd64 2>/dev/null; \
    ARCH=$(uname -m); \
    if [ "$ARCH" = "aarch64" ]; then \
        apt-get update; \
        apt-get install -y --no-install-recommends libc6:amd64 libstdc++6:amd64 libicu67:amd64 libssl1.1:amd64; \
        echo "=== SSL DIAG: box64 curl api.scpslgame.com ==="; \
        apt-get install -y --no-install-recommends --fix-missing curl:amd64 2>&1; \
        box64 /usr/bin/curl -v --connect-timeout 10 "https://api.scpslgame.com/" 2>&1 | head -50 || echo "CURL_DIAG_FAILED"; \
        echo "=== SSL DIAG END ==="; \
        apt-get purge -y curl:amd64 2>/dev/null || true; \
    fi; \
    apt-get update && apt-get install -y --no-install-recommends \
    adduser \
    libicu67 \
    ca-certificates \
    curl \
    wget \
    ffmpeg && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

ENV BOX64_SHOWSEGV=1
ENV BOX64_DYNAREC_NATIVEFLAGS=0
ENV DEBUGGER=/usr/local/bin/box64
ENV BOX64_LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu/
ENV SteamAppId=996560
ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
ENV TERM=xterm-256color
ENV DOTNET_SYSTEM_CONSOLE_ALLOW_ANSI_COLOR_REDIRECTION=true

# Container setup for Pterodactyl
RUN adduser --home /home/container container --disabled-password
ARG CACHBUST=1
USER container
ENV USER=container HOME=/home/container
WORKDIR /home/container

COPY ./entrypoint.sh /entrypoint.sh
CMD ["/bin/bash", "/entrypoint.sh"]
