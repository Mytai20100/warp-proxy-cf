#!/bin/bash
set -e

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

echo "[entrypoint] setting tunnel mode (bypass proxy, route all traffic)..."
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

echo "[entrypoint] starting tinyproxy..."
exec /usr/bin/tinyproxy -d -c /etc/tinyproxy/tinyproxy.conf
