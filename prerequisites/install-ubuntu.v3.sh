#!/bin/bash


set -e

# 添加 Docker 的官方 GPG 密钥：
apt-get update
apt-get install -y ca-certificates curl git jq
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# 将存储库添加到 Apt 源：
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update

# 安装 Docker
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 检查并删除现有目录和符号链接
INSTALL_DIR="/opt/postal/install"
SYMLINK="/usr/bin/postal"

if [ -d "$INSTALL_DIR" ]; then
  echo -e "\e[35mstart\e[0m 目标目录 $INSTALL_DIR 已存在，正在删除..."
  rm -rf "$INSTALL_DIR"
fi

if [ -L "$SYMLINK" ]; then
  echo -e "\e[35mstart\e[0m 符号链接 $SYMLINK 已存在，正在删除..."
  rm -rf "$SYMLINK"
fi

# 克隆 Postal 仓库
git clone https://github.com/DOMGO-cut/postal.git "$INSTALL_DIR"
ln -s "$INSTALL_DIR/bin/postal" "$SYMLINK"

sudo chmod +x "$INSTALL_DIR/bin/postal"
echo -e "\e[35mstart\e[0m 权限已执行完毕"

# 删除现有的 MariaDB 容器（如果存在）
if [ "$(docker ps -aq -f name=postal-mariadb)" ]; then
  echo -e "\e[35mstart\e[0m 现有的 MariaDB 容器存在，正在删除..."
  docker rm -f postal-mariadb
fi

# 启动 MariaDB 容器
docker run -d \
   --name postal-mariadb \
   -p 127.0.0.1:3306:3306 \
   --restart always \
   -e MARIADB_DATABASE=postal \
   -e MARIADB_ROOT_PASSWORD=hzx19960426 \
   mariadb

# 提示用户输入域名
echo -e "\e[35mstart\e[0m 请输入你的域名（例如: example.com）:"
read domain

# 检查用户是否输入了域名
if [ -z "$domain" ]; then
  echo -e "\e[35mstart\e[0m 缺少主机名。请确保输入一个有效的域名。"
  exit 1
fi

# 运行 postal bootstrap 命令
postal bootstrap "$domain"

echo -e "\e[35mstart\e[0m Postal bootstrap 已执行完毕，使用域名: $domain"

echo -e "\e[35mstart\e[0m 正在进行初始化数据库"
postal initialize

postal make-user
echo -e "\e[35mstart\e[0m 数据库初始化完毕"

postal start
echo -e "\e[35mstart\e[0m 开启 postal 服务成功"

# 删除现有的 Caddy 容器（如果存在）
if [ "$(docker ps -aq -f name=postal-caddy)" ]; then
  echo -e "\e[35mstart\e[0m 现有的 Caddy 容器存在，正在删除..."
  docker rm -f postal-caddy
fi

# 启动 Caddy 容器
docker run -d \
   --name postal-caddy \
   --restart always \
   --network host \
   -v /opt/postal/config/Caddyfile:/etc/caddy/Caddyfile \
   -v /opt/postal/caddy-data:/data \
   caddy
   
# 获取当前的 IPv4 地址
ipv4=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

# 获取当前的 IPv6 地址
ipv6=$(ip -6 addr show | grep -oP '(?<=inet6\s)[\da-fA-F:]+')

# 将结果赋值给变量
ips="$ipv4"
ipss="$ipv6"

# 获取默认 DKIM 记录
dkim_output=$(postal default-dkim-record)

# 提取 DKIM 记录（假设输出格式是纯文本的 DKIM 记录）
# 如果输出有特定的格式，例如 JSON，你可能需要使用 `jq` 或其他工具来解析
DKIM="$dkim_output"

echo -e "\e[35mPostal 安装\e[0m 安装完成，请打开网址访问 postal 服务，https://$domain"

echo -e "\e[35mPostal 安装e[0m 你应该设置A记录为： $ips   AAAA记录 $ipss"

echo -e "\e[35mPostal 安装e[0m MX记录为：    MX   10   $domain"

echo -e "\e[35mPostal 安装e[0m rp.MX记录为：    MX   10   rp.$domain"

echo -e "\e[35mPostal 安装e[0m 返回MX记录为： routes  MX  10  $domain"

echo -e "\e[35mPostal 安装e[0m DMARC记录为： _dmarc   v=DMARC1;p=quarantine;rua=mailto:admin@$domain"

echo -e "\e[35mPostal 安装e[0m SPF记录为：   spf   v=spf1 a mx include:spf.$domain ~all"

echo -e "\e[35mPostal 安装e[0m DKIM记录为：  default._domainkey.$domain   $DKIM"

echo -e "\e[35mPostal 安装e[0m 返回MX记录为： routes  MX  10  $domain"

