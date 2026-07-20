#!/bin/bash
cd /home/container

ARCH=$(uname -m)

# SSL Diag: check x86_64 libs + SSL connectivity under box64
if [ "$ARCH" = "aarch64" ]; then
    echo "=== SSL DIAG (runtime) ==="
    ls -la /usr/lib/x86_64-linux-gnu/libssl* /usr/lib/x86_64-linux-gnu/libcrypto* 2>&1 | head -10
    ls -la /etc/ssl/certs/ca-certificates.crt 2>&1
    echo "--- native openssl s_client (ARM64) ---"
    echo "Q" | timeout 10 box64 /usr/bin/openssl s_client -connect api.scpslgame.com:443 -CAfile /etc/ssl/certs/ca-certificates.crt 2>&1 | head -15 || echo "OPENSSL_NATIVE_FAILED=$?"
    echo "--- amd64 openssl under box64 ---"
    if [ -x /usr/local/bin/openssl.amd64 ]; then
        echo "Q" | timeout 10 box64 /usr/local/bin/openssl.amd64 s_client -connect api.scpslgame.com:443 -CAfile /etc/ssl/certs/ca-certificates.crt 2>&1 | head -30 || echo "OPENSSL_AMD64_FAILED=$?"
    else
        echo "openssl.amd64 not found - skipping"
    fi
    echo "--- amd64 curl under box64 ---"
    if [ -x /usr/local/bin/curl.amd64 ]; then
        timeout 10 box64 /usr/local/bin/curl.amd64 -v "https://api.scpslgame.com/" 2>&1 | head -20 || echo "CURL_AMD64_FAILED=$?"
    else
        echo "curl.amd64 not found - skipping"
    fi
    echo "=== SSL DIAG END ==="
fi

# Fix SSL: add --weak-http-security to start.sh if not present (Northwood official fix)
if [ "$ARCH" = "aarch64" ] && [ -f "start.sh" ]; then
    sed -i '/--weak-http-security/! s|"./LocalAdmin"|"./LocalAdmin" --weak-http-security|' start.sh 2>/dev/null || true
    sed -i '/--weak-http-security/! s|box64 "./LocalAdmin"|box64 "./LocalAdmin" --weak-http-security|' start.sh 2>/dev/null || true
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

# Box64 env config (mirrors reference init.sh pattern)
if [ "$ARCH" = "aarch64" ]; then
    export templdpath="${LD_LIBRARY_PATH}"
    export LD_LIBRARY_PATH="/usr/lib/x86_64-linux-gnu:/lib/x86_64-linux-gnu"
    export DEBUGGER="/usr/local/bin/box64"
fi

MODIFIED_STARTUP="eval $(echo ${STARTUP} | sed -e 's/{{/${/g' -e 's/}}/}/g')"
echo ":/home/container$ ${MODIFIED_STARTUP}"

${MODIFIED_STARTUP}