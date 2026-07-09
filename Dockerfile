FROM debian:trixie-slim
LABEL maintainer="EsserGaming"
USER root

# Grab the essentials
RUN apt-get update && apt-get install -y \
    adduser \
    libicu76 \
    ca-certificates \
    curl \
    wget \
    adduser \
    libicu76 && \
    rm -rf /var/lib/apt/lists/*

# Container setup for Pterodactyl
RUN adduser --home /home/container container --disabled-password
ARG CACHBUST=1
USER container
ENV USER=container HOME=/home/container
WORKDIR /home/container

COPY ./entrypoint.sh /entrypoint.sh
CMD ["/bin/bash", "/entrypoint.sh"]
