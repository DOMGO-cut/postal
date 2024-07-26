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

# Install docker
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Install helper
git clone https://postalserver.io/start/install /opt/postal/install
ln -s /opt/postal/install/bin/postal /usr/bin/postal

# Run MariaDB
docker run -d \
   --name postal-mariadb \
   -p 127.0.0.1:3306:3306 \
   --restart always \
   -e MARIADB_DATABASE=domcsc \
   -e MARIADB_ROOT_PASSWORD=hzx19960426 \
   mariadb
