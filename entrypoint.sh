#!/bin/bash
cd /home/container

ARCH=$(uname -m)

# Priority PATH: prefer /usr/bin box64
if [ "$ARCH" = "aarch64" ]; then
    export PATH="/usr/bin:$PATH"
    printf '\033[0;32m=== SCP:SL ARM64 Container ===\033[0m\n'
fi

# DEBUG mode - verbose diagnostics only when enabled
if [ "$DEBUG" = "true" ] && [ "$ARCH" = "aarch64" ]; then
    printf '\033[0;33m=== SSL DIAG (runtime) ===\033[0m\n'
    ls -la /usr/lib/x86_64-linux-gnu/libssl* /usr/lib/x86_64-linux-gnu/libcrypto* 2>&1 | head -10
    echo "--- native openssl s_client (ARM64) ---"
    echo "Q" | timeout 10 openssl s_client -connect api.scpslgame.com:443 -CAfile /etc/ssl/certs/ca-certificates.crt 2>&1 | head -15 || echo "OPENSSL_NATIVE_FAILED=$?"
    echo "--- amd64 openssl under box64 ---"
    if [ -x /usr/local/bin/openssl.amd64 ]; then
        echo "Q" | timeout 10 box64 /usr/local/bin/openssl.amd64 s_client -connect api.scpslgame.com:443 -CAfile /etc/ssl/certs/ca-certificates.crt 2>&1 | head -30 || echo "OPENSSL_AMD64_FAILED=$?"
    fi
    echo "--- amd64 curl under box64 ---"
    if [ -x /usr/local/bin/curl.amd64 ]; then
        timeout 10 box64 /usr/local/bin/curl.amd64 -v "https://api.scpslgame.com/" 2>&1 | head -20 || echo "CURL_AMD64_FAILED=$?"
    fi
    printf '\033[0;33m=== SSL DIAG END ===\033[0m\n'
fi

# OpenSSL SECLEVEL=0 via config file
if [ "$ARCH" = "aarch64" ]; then
    if [ ! -f /tmp/openssl-seclevel.cnf ]; then
        cat > /tmp/openssl-seclevel.cnf << 'EOF'
openssl_conf = openssl_init
[openssl_init]
ssl_conf = ssl_sect
[ssl_sect]
system_default = system_default_sect
[system_default_sect]
MinProtocol = TLSv1.2
CipherString = DEFAULT@SECLEVEL=0
EOF
    fi
    export OPENSSL_CONF=/tmp/openssl-seclevel.cnf
fi

# Fix SSL: ensure --weak-http-security is AFTER port arg
if [ "$ARCH" = "aarch64" ] && [ -f "start.sh" ]; then
    sed -i "s/^LAUNCH_CMD='\.\/LocalAdmin --weak-http-security'/LAUNCH_CMD='.\/LocalAdmin'/" start.sh
    sed -i "s/^LAUNCH_CMD='box64 \.\/LocalAdmin --weak-http-security'/LAUNCH_CMD='box64 .\/LocalAdmin'/" start.sh
    if ! grep -q '\$@ --weak-http-security' start.sh 2>/dev/null; then
        sed -i 's/\$LAUNCH_CMD "\$@"/$LAUNCH_CMD "$@" --weak-http-security/' start.sh
    fi
fi

# Fix stdin: remove printf pipe that steals console input
if [ "$ARCH" = "aarch64" ] && [ -f "start.sh" ]; then
    if grep -q 'printf.*|.*\$LAUNCH_CMD' start.sh 2>/dev/null; then
        sed -i '/^[[:space:]]*printf/s/^[[:space:]]*printf[^|]*|[[:space:]]*//' start.sh
    fi
fi

# Restore real binaries if .bin files exist
for bin in LocalAdmin SCPSL.x86_64; do
    if [ -f "${bin}.bin" ] && [ -f "$bin" ] && head -1 "$bin" | grep -q "^#!/bin/bash"; then
        mv "${bin}.bin" "$bin"
        chmod +x "$bin"
    fi
done

# Ensure box64 for LocalAdmin on ARM64
if [ "$ARCH" = "aarch64" ] && [ -f "start.sh" ] && grep -q '^"./LocalAdmin"' start.sh 2>/dev/null; then
    sed -i 's|^"./LocalAdmin"|box64 "./LocalAdmin"|' start.sh
fi

# Box64 env config
if [ "$ARCH" = "aarch64" ]; then
    export templdpath="${LD_LIBRARY_PATH}"
    export LD_LIBRARY_PATH="/usr/lib/x86_64-linux-gnu:/lib/x86_64-linux-gnu"
    export DEBUGGER="/usr/local/bin/box64"
    export SSL_CERT_DIR=/etc/ssl/certs
fi

# SSL cert sync
if [ "$ARCH" = "aarch64" ]; then
    if [ ! -f /etc/ssl/certs/ISRG_Root_X1.pem ] && [ ! -f /etc/ssl/certs/isrgrootx1.pem ]; then
        wget -q -O /tmp/isrg-root-x1.crt https://letsencrypt.org/certs/isrgrootx1.pem 2>/dev/null && \
        cp /tmp/isrg-root-x1.crt /usr/local/share/ca-certificates/isrg-root-x1.crt && \
        update-ca-certificates --fresh 2>/dev/null
        rm -f /tmp/isrg-root-x1.crt
    fi
fi

# Box64 warmup
if [ "$ARCH" = "aarch64" ] && command -v box64 >/dev/null 2>&1; then
    if [ -x /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 ]; then
        timeout 5 box64 /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 2>/dev/null || true
    fi
fi

MODIFIED_STARTUP="eval $(echo ${STARTUP} | sed -e 's/{{/${/g' -e 's/}}/}/g')"

exec /opt/scpsl/runner.sh "$MODIFIED_STARTUP"
