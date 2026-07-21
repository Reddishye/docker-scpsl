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
        adduser libicu67 ca-certificates curl wget ffmpeg \
        openssl socat gnupg && \
    if [ "$ARCH" = "aarch64" ]; then \
        update-ca-certificates --fresh; \
        wget -q -O /tmp/libssl3.deb \
            "https://deb.debian.org/debian/pool/main/o/openssl/libssl3_3.0.20-1~deb12u2_amd64.deb" && \
        mkdir -p /tmp/ssl3 && dpkg-deb -x /tmp/libssl3.deb /tmp/ssl3 && \
        cp /tmp/ssl3/usr/lib/x86_64-linux-gnu/libssl.so.3 \
           /tmp/ssl3/usr/lib/x86_64-linux-gnu/libcrypto.so.3 \
           /usr/lib/x86_64-linux-gnu/ && \
        rm -rf /tmp/libssl3.deb /tmp/ssl3; \
        wget -q -O /tmp/isrg-root-x1.crt https://letsencrypt.org/certs/isrgrootx1.pem; \
        cp /tmp/isrg-root-x1.crt /usr/local/share/ca-certificates/isrg-root-x1.crt; \
        update-ca-certificates --fresh; \
        rm -f /tmp/isrg-root-x1.crt; \
        openssl rehash /etc/ssl/certs/ 2>/dev/null; \
        # Install latest box64 from Pi-Apps-Coders repo (daily CI builds)
        mkdir -p /usr/share/keyrings && \
        wget -qO- "https://pi-apps-coders.github.io/box64-debs/KEY.gpg" | \
            gpg --dearmor -o /usr/share/keyrings/box64-archive-keyring.gpg && \
        echo "Types: deb
URIs: https://Pi-Apps-Coders.github.io/box64-debs/debian
Suites: ./
Signed-By: /usr/share/keyrings/box64-archive-keyring.gpg" \
            > /etc/apt/sources.list.d/box64.sources && \
        apt-get update && \
        apt-get install -y box64-generic-arm; \
    fi; \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt

ENV BOX64_DYNAREC_NATIVEFLAGS=0
ENV BOX64_DYNAREC_STRONGMEM=1
ENV DEBUGGER=/usr/local/bin/box64
ENV BOX64_LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu/
ENV SteamAppId=996560
ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
# .NET config: PascalCase mapping (dot -> _), all lowercase for the rest
ENV DOTNET_System_Net_Http_SocketsHttpHandler_Http2UnsupportedEnabled=true
ENV DOTNET_System_Net_Http_SocketsHttpHandler_Http3Disabled=true
ENV DOTNET_System_Net_Http_ShowDiagnostics=false
ENV DOTNET_System_Net_Security_ChainRevocationCheckMode=NoCheck
ENV TERM=xterm-256color
ENV ACCEPT_SCPSL_EULA=TRUE

# Container setup for Pterodactyl
RUN adduser --home /home/container container --disabled-password
ARG CACHBUST=1
USER container
ENV USER=container HOME=/home/container
WORKDIR /home/container

COPY ./entrypoint.sh /entrypoint.sh
CMD ["/bin/bash", "/entrypoint.sh"]
