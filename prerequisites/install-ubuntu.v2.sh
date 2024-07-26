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

# 检查并删除现有的 Postal 安装目录
if [ -d "/opt/postal/install" ]; then
    echo "检测到现有的 Postal 安装目录，正在删除..."
    rm -rf /opt/postal/install
fi

# 安装 Postal 助手
git clone https://postalserver.io/start/install /opt/postal/install
ln -s /opt/postal/install/bin/postal /usr/bin/postal

# 确保 /usr/bin/postal 是可执行的
chmod +x /usr/bin/postal

# 检查并删除现有的 MariaDB 容器
if [ "$(docker ps -q -f name=postal-mariadb)" ]; then
    echo "检测到现有的 MariaDB 容器，正在停止并删除..."
    docker stop postal-mariadb
    docker rm postal-mariadb
fi

# 运行 MariaDB
docker run -d \
   --name postal-mariadb \
   -p 127.0.0.1:3306:3306 \
   --restart always \
   -e MARIADB_DATABASE=postal \
   -e MARIADB_ROOT_PASSWORD=postal \
   mariadb

# 检查并删除现有的 RabbitMQ 容器
if [ "$(docker ps -q -f name=postal-rabbitmq)" ]; then
    echo "检测到现有的 RabbitMQ 容器，正在停止并删除..."
    docker stop postal-rabbitmq
    docker rm postal-rabbitmq
fi

# 运行 RabbitMQ
docker run -d \
   --name postal-rabbitmq \
   -p 127.0.0.1:5672:5672 \
   --restart always \
   -e RABBITMQ_DEFAULT_USER=postal \
   -e RABBITMQ_DEFAULT_PASS=postal \
   -e RABBITMQ_DEFAULT_VHOST=postal \
   rabbitmq:3.8
