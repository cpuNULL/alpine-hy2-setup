#!/bin/bash

set -e

apk add --no-cache wget curl openssl openrc

generate_random_password() {
  # 生成随机密码，过滤掉/ + = @ 等特殊字符，避免协议链接出错
  dd if=/dev/urandom bs=18 count=1 status=none | base64 | tr -d '/+=@'
}

generate_random_port() {
  echo $(( RANDOM % 40001 + 10000 ))
}

PORT=$(generate_random_port)
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
maxStreams: 1024
recvWindowConn: 33554432   # 32MB，更大接收窗口连接数
recvWindow: 12582912       # 12MB，更大接收窗口
disableMTUDiscovery: true
disableCongestionControl: true
alpn:
  - h3
EOF
}

echo_hysteria_autoStart() {
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

echo "[INFO] 下载 hysteria 二进制文件..."
wget -O /usr/local/bin/hysteria https://download.hysteria.network/app/latest/hysteria-linux-amd64 --no-check-certificate
chmod +x /usr/local/bin/hysteria

mkdir -p /etc/hysteria/

echo "[INFO] 生成自签名 TLS 证书..."
openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) \
  -keyout /etc/hysteria/server.key \
  -out /etc/hysteria/server.crt \
  -subj "/CN=bing.com" \
  -days 36500

echo "[INFO] 写入 hysteria 配置..."
echo_hysteria_config_yaml > /etc/hysteria/config.yaml

echo "[INFO] 写入 OpenRC 服务脚本..."
echo_hysteria_autoStart > /etc/init.d/hysteria
chmod +x /etc/init.d/hysteria
rc-update add hysteria

echo "[INFO] 启动 hysteria 服务..."
service hysteria start

# 获取公网 IP
SERVER_IP=$(curl -s https://api64.ipify.org || curl -s https://ipinfo.io/ip)

# IPv6 地址加中括号
if echo "$SERVER_IP" | grep -q ":"; then
  SERVER_IP="[$SERVER_IP]"
fi

echo "------------------------------------------------------------------------"
echo "✅ hysteria2 安装完成"
echo "监听端口： $PORT"
echo "密码： $GENPASS"
echo "配置文件：/etc/hysteria/config.yaml"
echo "服务已随系统自动启动"
echo "查看状态：service hysteria status"
echo "重启服务：service hysteria restart"
echo "------------------------------------------------------------------------"
echo "客户端链接（复制即可使用）："
echo "hysteria2://$GENPASS@$SERVER_IP:$PORT?alpn=h3&insecure=1&sni=bing.com#hysteria2"
echo "------------------------------------------------------------------------"

echo "[INFO] 设置 IPv6 DNS 服务器..."
cat > /etc/resolv.conf << EOF
nameserver 2a00:1098:2c::1
nameserver 2a00:1098:2b::1
nameserver 2a01:4f8:c2c:123f::1
nameserver 2a01:4f9:c010:3f02::1
nameserver 2001:67c:2b0::4
nameserver 2001:67c:2b0::6
EOF

echo "[DONE] 安装完成，祝你使用愉快！"
