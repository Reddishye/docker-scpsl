# syntax=docker/dockerfile:1
FROM weilbyte/box:arm64v8-debian-11
LABEL maintainer="EsserGaming"
ENTRYPOINT []
USER root

# Grab the essentials
RUN apt-get update && apt-get install -y --no-install-recommends \
    adduser \
    libicu67 \
    ca-certificates \
    curl \
    wget \
    ffmpeg && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

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
