#!/bin/sh

apk update && apk upgrade
apk add wget curl git openssh openssl openrc

# 生成随机密码
generate_random_password() {
  dd if=/dev/urandom bs=18 count=1 status=none | base64
}

# 生成 20000-65535 范围内的随机端口
generate_random_port() {
  echo $(( ( RANDOM << 15 | RANDOM ) % 45536 + 20000 ))
}

GENPASS="$(generate_random_password)"
PORT="$(generate_random_port)"

# 自动检测首个全局 IPv6 地址
IPV6_ADDR=$(ip -6 addr show scope global | grep inet6 | awk '{print $2}' | cut -d/ -f1 | head -n1)

# 判断是否为 IPv6（用于协议输出）
format_ip() {
  IP=$1
  if echo "$IP" | grep -q ":"; then
    echo "[$IP]"
  else
    echo "$IP"
  fi
}

# 输出 hysteria2 配置文件
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
EOF
}

# OpenRC 启动脚本
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

# 下载 hysteria2
wget -O /usr/local/bin/hysteria https://download.hysteria.network/app/latest/hysteria-linux-amd64 --no-check-certificate
chmod +x /usr/local/bin/hysteria

# 生成自签名证书
mkdir -p /etc/hysteria/
openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) \
  -keyout /etc/hysteria/server.key \
  -out /etc/hysteria/server.crt \
  -subj "/CN=bing.com" -days 36500

# 写入配置文件
echo_hysteria_config_yaml > /etc/hysteria/config.yaml

# 写入 OpenRC 启动脚本
echo_hysteria_autoStart > /etc/init.d/hysteria
chmod +x /etc/init.d/hysteria
rc-update add hysteria
service hysteria start

# 设置 IPv6 DNS
echo "设置 IPv6 DNS..."
cat << EOF > /etc/resolv.conf
nameserver 2a00:1098:2c::1
nameserver 2a00:1098:2b::1
nameserver 2a01:4f8:c2c:123f::1
nameserver 2a01:4f9:c010:3f02::1
nameserver 2001:67c:2b0::4
nameserver 2001:67c:2b0::6
EOF

# 格式化IP用于输出
FORMATTED_IP=$(format_ip "$IPV6_ADDR")

# 输出连接信息
echo "------------------------------------------------------------------------"
echo " ✅ hysteria2 已安装并自动启动"
echo " ✅ 随机端口：$PORT"
echo " ✅ 密码：$GENPASS"
echo " ✅ SNI：bing.com"
echo " ✅ 配置文件：/etc/hysteria/config.yaml"
echo ""
echo " 🔗 客户端连接协议（完整）："
echo "hy2://$GENPASS@$FORMATTED_IP:$PORT?insecure=1&sni=bing.com#hysteria2"
echo ""
echo " ✅ 查看状态：service hysteria status"
echo " ✅ 重启服务：service hysteria restart"
echo "------------------------------------------------------------------------"
