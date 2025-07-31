#!/bin/sh

set -e  # 出错即退出

echo "[INFO] Updating package index and upgrading existing packages..."
apk update && apk upgrade

echo "[INFO] Installing curl and wget..."
apk add --no-cache curl wget

echo "[INFO] Downloading and executing hy2.sh..."
wget -O hy2.sh https://raw.githubusercontent.com/zrlhk/alpine-hysteria2/main/hy2.sh
sh hy2.sh

echo "[INFO] Updating /etc/resolv.conf with IPv6 DNS servers..."
cat > /etc/resolv.conf <<EOF
nameserver 2a00:1098:2c::1
nameserver 2a00:1098:2b::1
nameserver 2a01:4f8:c2c:123f::1
nameserver 2a01:4f9:c010:3f02::1
nameserver 2001:67c:2b0::4
nameserver 2001:67c:2b0::6
EOF

echo "[DONE] All tasks completed successfully."
