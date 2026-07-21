#!/bin/bash
cd /home/container

ARCH=$(uname -m)

# Priority PATH: prefer /usr/bin box64 (updated via Pi-Apps-Coders deb)
# over host-mounted stale box64 at /usr/local/bin (Pterodactyl mount)
if [ "$ARCH" = "aarch64" ]; then
    export PATH="/usr/bin:$PATH"
fi

# SSL DIAG: check x86_64 libs + SSL connectivity under box64
if [ "$ARCH" = "aarch64" ]; then
    echo "=== SSL DIAG (runtime) ==="
    ls -la /usr/lib/x86_64-linux-gnu/libssl* /usr/lib/x86_64-linux-gnu/libcrypto* 2>&1 | head -10
    ls -la /etc/ssl/certs/ca-certificates.crt 2>&1
    echo "--- native openssl s_client (ARM64) ---"
    echo "Q" | timeout 10 openssl s_client -connect api.scpslgame.com:443 -CAfile /etc/ssl/certs/ca-certificates.crt 2>&1 | head -15 || echo "OPENSSL_NATIVE_FAILED=$?"
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

# OpenSSL SECLEVEL=0: .NET under box64 may fail with SECLEVEL=1 cipher restrictions
if [ "$ARCH" = "aarch64" ]; then
    if [ ! -f /etc/ssl/openssl.cnf.ori ]; then
        cp /etc/ssl/openssl.cnf /etc/ssl/openssl.cnf.ori 2>/dev/null
        cat >> /etc/ssl/openssl.cnf << 'EOF'

# SECLEVEL=0 for .NET SSL compat under box64 (added by entrypoint.sh)
openssl_conf = openssl_init

[openssl_init]
ssl_conf = ssl_sect

[ssl_sect]
system_default = system_default_sect

[system_default_sect]
MinProtocol = TLSv1.2
CipherString = DEFAULT@SECLEVEL=0
EOF
        echo "OpenSSL SECLEVEL=0 configured"
    fi
fi

# Fix SSL: ensure --weak-http-security is AFTER port arg (correct position)
if [ "$ARCH" = "aarch64" ] && [ -f "start.sh" ]; then
    sed -i "s/^LAUNCH_CMD='\.\/LocalAdmin --weak-http-security'/LAUNCH_CMD='.\/LocalAdmin'/" start.sh
    sed -i "s/^LAUNCH_CMD='box64 \.\/LocalAdmin --weak-http-security'/LAUNCH_CMD='box64 .\/LocalAdmin'/" start.sh
    if ! grep -q '\$@ --weak-http-security' start.sh 2>/dev/null; then
        sed -i 's/\$LAUNCH_CMD "\$@"/$LAUNCH_CMD "$@" --weak-http-security/' start.sh
    fi
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
    export SSL_CERT_DIR=/etc/ssl/certs
fi

# SSL cert sync: ensure ISRG Root X1 cert is present for .NET/OpenSSL
if [ "$ARCH" = "aarch64" ]; then
    if [ ! -f /etc/ssl/certs/ISRG_Root_X1.pem ] && [ ! -f /etc/ssl/certs/isrgrootx1.pem ]; then
        echo "=== SSL: ISRG Root X1 cert missing, attempting download ==="
        wget -q -O /tmp/isrg-root-x1.crt https://letsencrypt.org/certs/isrgrootx1.pem 2>/dev/null && \
        cp /tmp/isrg-root-x1.crt /usr/local/share/ca-certificates/isrg-root-x1.crt && \
        update-ca-certificates --fresh 2>/dev/null && \
        echo "=== SSL: ISRG Root X1 installed ===" || \
        echo "=== SSL: ISRG Root X1 download failed (will retry at next boot) ==="
        rm -f /tmp/isrg-root-x1.crt
    else
        echo "=== SSL: ISRG Root X1 already present ==="
    fi
fi

# Box64 warmup: run box64 with real x86_64 binary to prime dynarec cache
# Using ld-linux (x86_64 dynamic linker) - box64 will set up JIT/dynarec
if [ "$ARCH" = "aarch64" ]; then
    if command -v box64 >/dev/null 2>&1; then
        if [ -x /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 ]; then
            timeout 5 box64 /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 2>/dev/null || true
        fi
        # Also warm with openssl binary for SSL-related codegen
        if [ -x /usr/local/bin/openssl.amd64 ]; then
            timeout 5 box64 /usr/local/bin/openssl.amd64 version 2>/dev/null || true
        fi
        echo "=== Box64 warmup done ==="
    fi
fi

MODIFIED_STARTUP="eval $(echo ${STARTUP} | sed -e 's/{{/${/g' -e 's/}}/}/g')"
echo ":/home/container$ ${MODIFIED_STARTUP}"

# Retry loop for ARM64: first boot may crash (exit 134) due to box64 cold cache
if [ "$ARCH" = "aarch64" ]; then
    MAX_RETRIES=3
    for i in $(seq 1 $MAX_RETRIES); do
        ${MODIFIED_STARTUP}
        RC=$?
        if [ $RC -eq 0 ]; then
            exit 0
        fi
        if [ $i -lt $MAX_RETRIES ]; then
            echo "Server exited with code $RC, retry $i/$MAX_RETRIES in 5s..."
            sleep 5
        else
            echo "All $MAX_RETRIES attempts failed, last exit code: $RC"
            exit $RC
        fi
    done
else
    ${MODIFIED_STARTUP}
fi
