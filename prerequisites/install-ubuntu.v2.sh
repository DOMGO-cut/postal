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

# 检查并删除现有的符号链接
if [ -L "/usr/bin/postal" ]; then
    echo "检测到现有的符号链接 /usr/bin/postal，正在删除..."
    rm /usr/bin/postal
fi

# 创建新的符号链接
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
   -e RABBITMQ_DEFAULT_USER=domcscs \
   -e RABBITMQ_DEFAULT_PASS=hzx19960426 \
   -e RABBITMQ_DEFAULT_VHOST=postal \
   rabbitmq:3.8


# 提示用户输入域名
echo -e "\e[35mPostal 安装\e[0m 请输入你的域名（例如: example.com）:"
read domain

# 检查用户是否输入了域名
if [ -z "$domain" ]; then
  echo -e "\e[35mPostal 安装\e[0m 缺少主机名。请确保输入一个有效的域名。"
  exit 1
fi

# 运行 postal bootstrap 命令
postal bootstrap "$domain"

echo -e "\e[35mPostal 安装\e[0m Postal bootstrap 已执行完毕，使用域名: $domain"

echo -e "\e[35mPostal 安装\e[0m 正在进行初始化数据库"
postal initialize

postal make-user
echo -e "\e[35mPostal 安装\e[0m 数据库初始化完毕"

postal start
echo -e "\e[35mPostal 安装\e[0m 开启 postal 服务成功"

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

echo -e "\e[35mPostal 安装\e[0m 安装完成，请打开网址访问 postal 服务，https://$domain"
