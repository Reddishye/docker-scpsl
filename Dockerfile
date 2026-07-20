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

# Install Box64 for ARM64 via direct download from ryanfortner repo
# (apt repo broken: GitHub Pages 404; raw.githubusercontent.com double-encodes '+')
# ponytail: switch to apt repo if GitHub Pages comes back
ARG TARGETARCH
RUN set -ex; \
    ARCH=${TARGETARCH:-$(uname -m)}; \
    if [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then \
        apt-get update; \
        apt-get install -y --no-install-recommends wget ca-certificates; \
        wget -qO /tmp/packages.txt https://raw.githubusercontent.com/ryanfortner/box64-debs/master/debian/Packages; \
        DEB_FILE=$(grep '^Filename: \./box64_' /tmp/packages.txt | tail -1 | cut -d' ' -f2 | sed 's|^\./||'); \
        wget -qO /tmp/box64.deb "https://raw.githubusercontent.com/ryanfortner/box64-debs/master/debian/${DEB_FILE}"; \
        dpkg -i /tmp/box64.deb; \
        echo "Box64 installed at: $(which box64)"; \
        box64 --version; \
        rm -f /tmp/packages.txt /tmp/box64.deb; \
        apt-get purge -y wget; \
        apt-get autoremove --purge -y; \
        rm -rf /var/lib/apt/lists/*; \
    fi

# Debug crash of SCPSL.x86_64 under box64 — shows segfault addr + last insn
ENV BOX64_LOG=1
ENV BOX64_SHOWSEGV=1

# Disable Box64 dynarec Native Flags optimization on ARM64
# (Neoverse-N1 crash in sysconf with _SC_PAGESIZE: native flags corrupts register)
ENV BOX64_DYNAREC_NATIVEFLAGS=0

# Required for SCP:SL server - SteamAppId for Steamworks, invariant for .NET ICU
ENV SteamAppId=996560
ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1

# Container setup for Pterodactyl
RUN adduser --home /home/container container --disabled-password
ARG CACHBUST=1
USER container
ENV USER=container HOME=/home/container
WORKDIR /home/container

COPY ./entrypoint.sh /entrypoint.sh
CMD ["/bin/bash", "/entrypoint.sh"]
