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
  echo -e "\e[35mPostal 安装\e[0m 目标目录 $INSTALL_DIR 已存在，正在删除..."
  rm -rf "$INSTALL_DIR"
fi
echo ""
if [ -L "$SYMLINK" ]; then
  echo -e "\e[35mPostal 安装\e[0m 符号链接 $SYMLINK 已存在，正在删除..."
  rm -rf "$SYMLINK"
fi
echo ""
# 克隆 Postal 仓库
git clone https://github.com/DOMGO-cut/postal.git "$INSTALL_DIR"
ln -s "$INSTALL_DIR/bin/postal" "$SYMLINK"

sudo chmod +x "$INSTALL_DIR/bin/postal"
echo -e "\e[35mPostal 安装\e[0m 权限已执行完毕"
echo ""
# 删除现有的 MariaDB 容器（如果存在）
if [ "$(docker ps -aq -f name=postal-mariadb)" ]; then
  echo -e "\e[35mPostal 安装\e[0m 现有的 MariaDB 容器存在，正在删除..."
  docker rm -f postal-mariadb
fi
echo ""
# 启动 MariaDB 容器
docker run -d \
   --name postal-mariadb \
   -p 127.0.0.1:3306:3306 \
   --restart always \
   -e MARIADB_DATABASE=postal \
   -e MARIADB_ROOT_PASSWORD=hzx19960426 \
   mariadb

# 提示用户输入域名
echo -e "\e[35mPostal 安装\e[0m 请输入你的域名（例如: example.com）:"
read domain
echo ""
# 检查用户是否输入了域名
if [ -z "$domain" ]; then
  echo -e "\e[35mPostal 安装\e[0m 缺少主机名。请确保输入一个有效的域名。"
  echo ""
  exit 1
fi

# 运行 postal bootstrap 命令
postal bootstrap "$domain"

echo -e "\e[35mPostal 安装\e[0m Postal bootstrap 已执行完毕，使用域名: $domain"
echo ""
echo -e "\e[35mPostal 安装\e[0m 正在进行初始化数据库"
postal initialize
echo ""
postal make-user
echo -e "\e[35mPostal 安装\e[0m 数据库初始化完毕"
echo ""
postal start
echo -e "\e[35mPostal 安装\e[0m 开启 postal 服务成功"
echo ""
# 删除现有的 Caddy 容器（如果存在）
if [ "$(docker ps -aq -f name=postal-caddy)" ]; then
  echo -e "\e[35mPostal 安装\e[0m 现有的 Caddy 容器存在，正在删除..."
  echo ""
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
ipv4=$(curl -s https://api64.ipify.org)


# 将结果赋值给变量
ips="$ipv4"

echo ""
echo -e "\e[35mPostal 安装\e[0m 安装完成，请打开网址访问 postal 服务，\e[31m https://domcsc.$domain \e[0m"
echo ""
echo -e "\e[35mPostal 安装\e[0m 设置A记录为： \e[31m   @  \e[0m       \e[31m A  \e[0m    $ips"
echo ""
echo -e "\e[35mDNS配置\e[0m 设置MX记录为：   \e[32m    @ \e[0m        \e[31m MX   10 \e[0m mx.$domain"
echo ""
echo -e "\e[35mDNS配置\e[0m 设置MX记录为：   \e[32m    rp \e[0m       \e[31m MX   10 \e[0m  $domain"
echo ""
echo -e "\e[35mDNS配置\e[0m 设置返回MX记录为：\e[32m routes \e[0m  \e[31m MX  10 \e[0m  $domain"
echo ""
echo -e "\e[35mDNS配置\e[0m 设置DMARC记录为： \e[32m _dmarc \e[0m \e[31m TXT \e[0m  v=DMARC1;p=quarantine;rua=mailto:admin@$domain"
echo ""
echo -e "\e[35mDNS配置\e[0m 设置SPF记录为：   \e[32m  rp \e[0m    \e[31m TXT \e[0m  v=spf1 a mx include:spf.$domain ~all"
echo ""
echo -e "\e[35mDNS配置\e[0m 设置SPF记录为：   \e[32m  spf \e[0m    \e[31m TXT \e[0m  v=spf1 ip4:$ips  ~all"
echo ""
echo -e "\e[35mDNS配置\e[0m 设置CNAM记录为：  \e[32m  psrp  \e[0m  \e[31m CNAM \e[0m  rp.$domain"
echo ""
echo -e "\e[35mDNS配置\e[0m 设置CNAM记录为：  \e[32m  click \e[0m  \e[31m CNAM \e[0m  track.$domain"
echo ""
echo -e "\e[35mDNS配置\e[0m 设置A记录为：      \e[32m track \e[0m  \e[31m A \e[0m   $ips"
echo ""
echo -e "\e[35mDNS配置\e[0m 设置A记录为：      \e[32m domcsc \e[0m  \e[31m A \e[0m   $ips"
