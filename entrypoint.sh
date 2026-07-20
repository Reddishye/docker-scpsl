#!/bin/bash
cd /home/container

ARCH=$(uname -m)

# SSL Diag: test if OpenSSL works under box64 at runtime
if [ "$ARCH" = "aarch64" ]; then
    echo "=== SSL DIAG ==="
    ls -la /usr/lib/x86_64-linux-gnu/libssl* /usr/lib/x86_64-linux-gnu/libcrypto* 2>&1 | head -10
    echo "=== SSL DIAG END ==="
fi

# Migrate old wrapper scheme: restore real binaries if .bin files exist
for bin in LocalAdmin SCPSL.x86_64; do
    if [ -f "${bin}.bin" ] && [ -f "$bin" ] && head -1 "$bin" | grep -q "^#!/bin/bash"; then
        mv "${bin}.bin" "$bin"
        chmod +x "$bin"
        echo "Migrated $bin: restored real x86_64 binary from .bin backup"
    fi
done

# Ensure start.sh uses box64 for LocalAdmin on ARM64
if [ "$ARCH" = "aarch64" ] && [ -f "start.sh" ] && grep -q '^"./LocalAdmin"' start.sh 2>/dev/null; then
    sed -i 's|^"./LocalAdmin"|box64 "./LocalAdmin"|' start.sh
    echo "Fixed start.sh: added box64 prefix for ARM64"
fi

# Prep x86_64 library path for box64 on ARM64
if [ "$ARCH" = "aarch64" ]; then
    export LD_LIBRARY_PATH="/usr/lib/x86_64-linux-gnu:/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi

MODIFIED_STARTUP="eval $(echo ${STARTUP} | sed -e 's/{{/${/g' -e 's/}}/}/g')"
echo ":/home/container$ ${MODIFIED_STARTUP}"

${MODIFIED_STARTUP}