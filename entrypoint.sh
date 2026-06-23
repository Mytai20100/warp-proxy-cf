#!/bin/bash
set -e

PROXY_PORT=${PROXY_PORT:-3128}

echo "[entrypoint] setting up writable dirs..."
mkdir -p /mnt/server/warp-data
mkdir -p /mnt/server/warp-run

# /var/lib/cloudflare-warp da bi xoa trong Dockerfile
# gio tao symlink sang /mnt/server truoc khi warp-svc start
ln -sf /mnt/server/warp-data /var/lib/cloudflare-warp

# /run thuong la tmpfs nen co the ghi duoc, nhung tao san cho chac
mkdir -p /run/cloudflare-warp 2>/dev/null || \
    ln -sf /mnt/server/warp-run /run/cloudflare-warp

echo "[entrypoint] starting warp-svc..."
/usr/bin/warp-svc &
sleep 5

warp() {
    expect -c "
        spawn warp-cli $*
        expect {
            \"y/N\" { send \"y\r\"; exp_continue }
            eof
        }
    " 2>/dev/null || true
}

echo "[entrypoint] registering WARP..."
warp "registration new" || true

echo "[entrypoint] setting tunnel mode..."
warp "tunnel protocol set WireGuard" || true
warp "mode warp"

echo "[entrypoint] connecting WARP..."
warp "connect"

echo "[entrypoint] waiting for WARP to connect..."
MAX_WAIT=60
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
    STATUS=$(warp "status" 2>&1 || true)
    echo "[entrypoint] status: $STATUS"
    if echo "$STATUS" | grep -q "Connected"; then
        echo "[entrypoint] WARP connected OK"
        break
    fi
    sleep 3
    ELAPSED=$((ELAPSED + 3))
done

if ! echo "$STATUS" | grep -q "Connected"; then
    echo "[entrypoint] ERROR: WARP failed to connect after ${MAX_WAIT}s"
    exit 1
fi

echo "[entrypoint] starting tinyproxy on port ${PROXY_PORT}..."
exec /usr/bin/tinyproxy -d -c /mnt/server/tinyproxy.conf
