#!/bin/sh

set -e

echo "[INFO] Updating and installing essential packages..."
apk update && apk upgrade
apk add --no-cache curl wget openssl openrc

generate_random_password() {
  dd if=/dev/urandom bs=18 count=1 status=none | base64
}

generate_random_port() {
  echo $((RANDOM % 40001 + 10000))
}

read -p "请输入监听端口（10000~50000之间），直接回车则随机生成: " USER_PORT
if echo "$USER_PORT" | grep -Eq '^[0-9]+$' && [ "$USER_PORT" -ge 10000 ] && [ "$USER_PORT" -le 50000 ]; then
  PORT=$USER_PORT
else
  PORT=$(generate_random_port)
  echo "已随机生成端口：$PORT"
fi

GENPASS="$(generate_random_password)"

echo_hysteria_config_yaml() {
  cat << EOF
listen: :$PORT

tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key

auth:
  type: password
  password: $GENPASS

masquerade:
  type: proxy
  proxy:
    url: https://bing.com/
    rewriteHost: true

maxConn: 0
maxStreams: 512
recvWindowConn: 16777216
recvWindow: 6291456
disableMTUDiscovery: true
disableCongestionControl: true
alpn:
  - h3
EOF
}

echo_hysteria_autoStart(){
  cat << EOF
#!/sbin/openrc-run

name="hysteria"
command="/usr/local/bin/hysteria"
command_args="server --config /etc/hysteria/config.yaml"
pidfile="/var/run/\${name}.pid"
command_background="yes"

depend() {
    need networking
}
EOF
}

echo "[INFO] Downloading hysteria2 binary..."
wget -O /usr/local/bin/hysteria https://download.hysteria.network/app/latest/hysteria-linux-amd64 --no-check-certificate
chmod +x /usr/local/bin/hysteria

mkdir -p /etc/hysteria/

echo "[INFO] Generating self-signed TLS certificate..."
openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) \
  -keyout /etc/hysteria/server.key \
  -out /etc/hysteria/server.crt \
  -subj "/CN=bing.com" \
  -days 36500

echo "[INFO] Writing hysteria config..."
echo_hysteria_config_yaml > /etc/hysteria/config.yaml

echo "[INFO] Writing OpenRC service script..."
echo_hysteria_autoStart > /etc/init.d/hysteria
chmod +x /etc/init.d/hysteria
rc-update add hysteria

echo "[INFO] Starting hysteria service..."
service hysteria start

SERVER_IP=$(curl -s https://api64.ipify.org || curl -s https://ipinfo.io/ip)

echo "------------------------------------------------------------------------"
echo "✅ hysteria2 已安装完成"
echo "监听端口: $PORT"
echo "密码: $GENPASS"
echo "配置文件: /etc/hysteria/config.yaml"
echo "服务状态: service hysteria status"
echo "重启服务: service hysteria restart"
echo "------------------------------------------------------------------------"
echo "📎 客户端链接（可复制使用）:"
echo "hysteria2://$GENPASS@$SERVER_IP:$PORT?alpn=h3&insecure=1#hysteria2"
echo "------------------------------------------------------------------------"

echo "[INFO] Updating /etc/resolv.conf with IPv6 DNS..."
cat > /etc/resolv.conf <<EOF
nameserver 2a00:1098:2c::1
nameserver 2a00:1098:2b::1
nameserver 2a01:4f8:c2c:123f::1
nameserver 2a01:4f9:c010:3f02::1
nameserver 2001:67c:2b0::4
nameserver 2001:67c:2b0::6
EOF

echo "[DONE] All tasks completed successfully."
