#!/bin/bash

apk add --no-cache wget curl git openssh openssl openrc

generate_random_password() {
  dd if=/dev/urandom bs=18 count=1 status=none | base64
}

generate_random_port() {
  echo $(( RANDOM % 40001 + 10000 ))
}

PORT=$(generate_random_port)
GENPASS="$(generate_random_password)"

echo_hysteria_config_yaml() {
  cat << EOF
listen: :$PORT

#有域名，使用CA证书
#acme:
#  domains:
#    - test.heybro.bid #你的域名，需要先解析到服务器ip
#  email: xxx@gmail.com

#使用自签名证书
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

echo "[INFO] Downloading hysteria binary..."
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

# 获取公网 IP
SERVER_IP=$(curl -s https://api64.ipify.org || curl -s https://ipinfo.io/ip)

# IPv6 地址加中括号
if echo "$SERVER_IP" | grep -q ":"; then
  SERVER_IP="[$SERVER_IP]"
fi

echo "------------------------------------------------------------------------"
echo "hysteria2 已安装完成"
echo "监听端口： $PORT"
echo "密码： $GENPASS"
echo "配置文件：/etc/hysteria/config.yaml"
echo "服务已随系统自动启动"
echo "查看状态：service hysteria status"
echo "重启服务：service hysteria restart"
echo "------------------------------------------------------------------------"
echo "客户端链接（直接复制使用）："
echo "hysteria2://$GENPASS@$SERVER_IP:$PORT?alpn=h3&insecure=1#hysteria2"
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
