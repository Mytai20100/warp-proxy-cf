# warp-proxy-cf

![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04-E95420?logo=ubuntu&logoColor=white)

HTTP proxy that routes traffic through Cloudflare WARP (WireGuard), exposed on port `3128`.

## Setup

### Option 1: Clone & build

```bash
git clone https://github.com/Mytai20100/warp-proxy-cf.git
cd warp-proxy-cf
docker compose up -d --build
```

### Option 2: Docker pull

```bash
docker pull ghcr.io/mytai20100/warp-proxy:latest

docker run -d \
  --name warp-proxy \
  --restart unless-stopped \
  -p 3128:3128 \
  --cap-add NET_ADMIN \
  --cap-add SYS_ADMIN \
  --device /dev/net/tun \
  ghcr.io/mytai20100/warp-proxy:latest
```

> `NET_ADMIN`, `SYS_ADMIN`, and `/dev/net/tun` are required for WireGuard to work inside the container.

## Testing

Watch the logs until you see `[entrypoint] WARP connected OK`:

```bash
docker logs -f warp-proxy
```

Test the proxy with curl:

```bash
curl -x http://127.0.0.1:3128 https://www.cloudflare.com/cdn-cgi/trace
```

You should see `warp=on` in the output. Compare your IP before/after going through the proxy:

```bash
curl https://api.ipify.org                            # direct IP
curl -x http://127.0.0.1:3128 https://api.ipify.org    # IP through WARP
```

The two IPs should differ if the proxy is working correctly.
