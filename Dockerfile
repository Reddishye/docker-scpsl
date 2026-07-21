# syntax=docker/dockerfile:1
ARG TARGETARCH

FROM debian:bullseye-slim AS base-amd64
FROM weilbyte/box:arm64v8-debian-11 AS base-arm64

FROM base-${TARGETARCH}
LABEL maintainer="EsserGaming"
ENTRYPOINT []
USER root

# Install packages + x86_64 multiarch libraries for box64 (ARM64 only)
RUN ARCH=$(uname -m); \
    dpkg --add-architecture amd64 2>/dev/null; \
    apt-get update; \
    if [ "$ARCH" = "aarch64" ]; then \
        apt-get install -y --no-install-recommends \
            libc6:amd64 libstdc++6:amd64 libicu67:amd64 \
            libssl1.1:amd64 libssl-dev:amd64 \
            libssh2-1:amd64 \
            curl:amd64 openssl:amd64; \
        cp /usr/bin/openssl /usr/local/bin/openssl.amd64; \
        cp /usr/bin/curl /usr/local/bin/curl.amd64; \
    fi; \
    apt-get install -y --no-install-recommends \
        adduser libicu67 ca-certificates curl wget ffmpeg && \
    if [ "$ARCH" = "aarch64" ]; then \
        update-ca-certificates --fresh; \
        # Download real libssl3:amd64 for Unity IL2CPP (needs libssl.so.3 soname)
        wget -q -O /tmp/libssl3_amd64.deb \
            "https://deb.debian.org/debian/pool/main/o/openssl/libssl3_3.0.20-1~deb12u2_amd64.deb" && \
        mkdir -p /tmp/libssl3_extract && \
        dpkg-deb -x /tmp/libssl3_amd64.deb /tmp/libssl3_extract && \
        cp -v /tmp/libssl3_extract/usr/lib/x86_64-linux-gnu/libssl.so.3 \
              /tmp/libssl3_extract/usr/lib/x86_64-linux-gnu/libcrypto.so.3 \
              /usr/lib/x86_64-linux-gnu/ && \
        rm -rf /tmp/libssl3_amd64.deb /tmp/libssl3_extract; \
    fi; \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
ENV DOTNET_OPENSSL_VERSION_OVERRIDE=1.1
ENV BOX64_DYNAREC_NATIVEFLAGS=0
ENV BOX64_DYNAREC_STRONGMEM=1
ENV DEBUGGER=/usr/local/bin/box64
ENV BOX64_LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu/
ENV SteamAppId=996560
ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
ENV TERM=xterm-256color
ENV DOTNET_SYSTEM_CONSOLE_ALLOW_ANSI_COLOR_REDIRECTION=true
ENV DOTNET_SYSTEM_NET_HTTP_SHOW_DIAGNOSTICS=1
ENV DOTNET_SYSTEM_NET_HTTP_SOCKETSHTTPHANDLER_HTTP3_DISABLED=1
ENV DOTNET_SYSTEM_NET_SECURITY_CHAINREVOCATIONCHECKMODE=NoCheck
ENV ACCEPT_SCPSL_EULA=TRUE

# Container setup for Pterodactyl
RUN adduser --home /home/container container --disabled-password
ARG CACHBUST=1
USER container
ENV USER=container HOME=/home/container
WORKDIR /home/container

COPY ./entrypoint.sh /entrypoint.sh
CMD ["/bin/bash", "/entrypoint.sh"]
