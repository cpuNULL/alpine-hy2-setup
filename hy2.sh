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

# 用户输入端口或使用随机端口
echo "请输入端口号 (建议范围 20000-65535，也可使用其他端口)，或按回车使用随机端口："
read -r USER_PORT

if [ -n "$USER_PORT" ] && [ "$USER_PORT" -ge 1 ] && [ "$USER_PORT" -le 65535 ] 2>/dev/null; then
  PORT="$USER_PORT"
  echo "使用用户指定端口: $PORT"
  # 给出端口范围建议
  if [ "$PORT" -lt 1024 ]; then
    echo "⚠️  注意：端口 $PORT 为系统保留端口，可能需要 root 权限"
  elif [ "$PORT" -lt 20000 ]; then
    echo "💡 提示：建议使用 20000-65535 范围内的端口以避免冲突"
  fi
else
  if [ -n "$USER_PORT" ]; then
    echo "❌ 无效端口号，使用随机端口"
  fi
  PORT="$(generate_random_port)"
  echo "使用随机端口: $PORT"
fi

GENPASS="$(generate_random_password)"

# 自动检测公网 IPv4 地址
IPV4_ADDR=$(curl -4 -s --max-time 10 ifconfig.me || curl -4 -s --max-time 10 ipinfo.io/ip || curl -4 -s --max-time 10 icanhazip.com)

# 如果获取公网IP失败，尝试获取本地IP
if [ -z "$IPV4_ADDR" ]; then
    IPV4_ADDR=$(ip -4 addr show | grep inet | grep -v 127.0.0.1 | awk '{print $2}' | cut -d/ -f1 | head -n1)
fi

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

echo "下载 Hysteria2..."
wget -O /usr/local/bin/hysteria https://download.hysteria.network/app/latest/hysteria-linux-amd64 --no-check-certificate || {
    echo "❌ 下载失败，尝试备用链接..."
    wget -O /usr/local/bin/hysteria https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64 --no-check-certificate
}
chmod +x /usr/local/bin/hysteria

# 生成自签名证书
echo "生成自签名证书..."
mkdir -p /etc/hysteria/
openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) \
  -keyout /etc/hysteria/server.key \
  -out /etc/hysteria/server.crt \
  -subj "/CN=bing.com" -days 36500

# 写入配置文件
echo "写入配置文件..."
echo_hysteria_config_yaml > /etc/hysteria/config.yaml

# 写入 OpenRC 启动脚本
echo "设置自启动服务..."
echo_hysteria_autoStart > /etc/init.d/hysteria
chmod +x /etc/init.d/hysteria
rc-update add hysteria
service hysteria start

# 格式化IP用于输出
FORMATTED_IP=$(format_ip "$IPV4_ADDR")

# 检查IP获取是否成功
if [ -z "$IPV4_ADDR" ]; then
    echo "⚠️  警告：无法自动获取服务器IP地址，请手动替换连接字符串中的IP"
    FORMATTED_IP="YOUR_SERVER_IP"
fi

# 输出连接信息
echo "------------------------------------------------------------------------"
echo " ✅ hysteria2 已安装并自动启动"
echo " ✅ 服务器IP：$IPV4_ADDR"
echo " ✅ 端口：$PORT"
echo " ✅ 密码：$GENPASS"
echo " ✅ SNI：bing.com"
echo " ✅ 配置文件：/etc/hysteria/config.yaml"
echo ""
echo " 🔗 客户端连接协议（完整）："
echo "hy2://$GENPASS@$FORMATTED_IP:$PORT?insecure=1&sni=bing.com#hysteria2"
echo ""
echo " ✅ 查看状态：service hysteria status"
echo " ✅ 重启服务：service hysteria restart"
echo " ✅ 停止服务：service hysteria stop"
echo "------------------------------------------------------------------------"
