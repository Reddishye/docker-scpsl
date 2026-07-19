# docker-scpsl

A modified Docker image for SCP: Secret Laboratory on Pterodactyl/Pelican, includes [ffmpeg](https://ffmpeg.org/).

## Features
- Includes ffmpeg for audio player plugins
- **ARM64 support** (Oracle Ampere, Raspberry Pi 4/5, etc.) via [Box64](https://github.com/ptitSeb/box64)
- Box64 is compiled from source with ARM DYNAREC for optimal x86_64 emulation on ARM64
- x86_64 binaries (SCPSL.x86_64, LocalAdmin, scpdiscord) are transparently wrapped with Box64 at install time

## GitHub package branches:
- master: `ghcr.io/reddishye/docker-scpsl:master` **(Multi-arch: amd64 + arm64, includes ffmpeg)**
- slim: `ghcr.io/essergaming/docker-scpsl:slim` **(amd64 only)**
- staging: `ghcr.io/essergaming/docker-scpsl:staging` **(amd64 only, experimental)**

## Architecture
| Arch | Status | Notes |
|------|--------|-------|
| amd64 | Full native | x86_64 native support |
| arm64 | Box64 emulation | Builds Box64 at image build time, x86_64 binaries wrapped with Box64 |
