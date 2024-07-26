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

# 安装 Postal 辅助工具
git clone https://github.com/DOMGO-cut/postal.git /opt/postal/install
ln -s /opt/postal/install/bin/postal /usr/bin/postal

sudo chmod +x /opt/postal/install/bin/postal
echo "权限已执行完毕"

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

# 启动 Caddy 容器
docker run -d \
   --name postal-caddy \
   --restart always \
   --network host \
   -v /opt/postal/config/Caddyfile:/etc/caddy/Caddyfile \
   -v /opt/postal/caddy-data:/data \
   caddy

echo "安装完成，请打开网址访问 postal 服务，https://$domain"
