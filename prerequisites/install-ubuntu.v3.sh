#!/bin/bash

# 此脚本将在 Ubuntu 上安装 Postal 的所有先决条件。
# 它还将为您启动 MariaDB 容器。
#
# 重要提示：如果您将其用于产品，则应确保使用适合您的数据库服务的凭据。

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
  echo "目标目录 $INSTALL_DIR 已存在，正在删除..."
  rm -rf "$INSTALL_DIR"
fi

if [ -L "$SYMLINK" ]; then
  echo "符号链接 $SYMLINK 已存在，正在删除..."
  rm "$SYMLINK"
fi

# 克隆 Postal 仓库
git clone https://github.com/DOMGO-cut/postal.git "$INSTALL_DIR"
ln -s "$INSTALL_DIR/bin/postal" "$SYMLINK"

sudo chmod +x "$INSTALL_DIR/bin/postal"
echo "权限已执行完毕"

# 删除现有的 MariaDB 容器（如果存在）
if [ "$(docker ps -aq -f name=postal-mariadb)" ]; then
  echo "现有的 MariaDB 容器存在，正在删除..."
  docker rm -f postal-mariadb
fi

# 启动 MariaDB 容器
docker run -d \
   --name postal-mariadb \
   -p 127.0.0.1:3306:3306 \
   --restart always \
   -e MARIADB_DATABASE=domcsc \
   -e MARIADB_ROOT_PASSWORD=hzx19960426 \
   mariadb

# 提示用户输入域名
read -p "请输入你的域名: " domain

# 检查用户是否输入了域名
if [ -z "$domain" ]; then
  echo "缺少主机名。"
  exit 1
fi

# 运行 postal bootstrap 命令
postal bootstrap "$domain"

echo "Postal bootstrap 已执行完毕，使用域名: $domain"

echo "正在进行初始化数据库"
postal initialize

postal make-user
echo "数据库初始化完毕"

postal start
echo "开启 postal 服务成功"

# 删除现有的 Caddy 容器（如果存在）
if [ "$(docker ps -aq -f name=postal-caddy)" ]; then
  echo "现有的 Caddy 容器存在，正在删除..."
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

echo "安装完成，请打开网址访问 postal 服务，https://$domain"
