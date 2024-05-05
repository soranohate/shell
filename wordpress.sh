#!/bin/bash

# 更新系统依赖
apt update && apt upgrade -y

# 安装PHP7.4
apt install php7.4 php7.4-fpm php7.4-mysql php7.4-curl php7.4-gd php7.4-intl php7.4-mbstring php7.4-soap php7.4-xml php7.4-xmlrpc php7.4-zip -y

# 安装Apache2
apt install apache2 -y 

# 启用Apache2 rewrite模块
a2enmod rewrite

# 修改Apache根目录权限
chmod -R 777 /var/www/html

# 创建wordpress文件夹
mkdir /var/www/html/wordpress

# 修改Apache默认配置文件
sed -i 's/\/var\/www\//\/var\/www\/html\/wordpress/g' /etc/apache2/sites-available/000-default.conf
sed -i 's/<Directory \/var\/www\//<Directory \/var\/www\/html\/wordpress/g' /etc/apache2/apache2.conf

# 重启Apache服务 
systemctl restart apache2

# 安装MySQL
apt install mariadb-server mariadb-client -y

# 运行MySQL安全脚本 
mysql_secure_installation <<EOF

n
n
y
y
y
y
EOF

# 进入MySQL终端
mysql -u root <<EOF

# 提示用户输入要创建的MySQL用户名和密码,如果直接回车则使用默认值
read -p "请输入要创建的MySQL用户名 (默认为shipzy): " username
username=\${username:-shipzy}
read -s -p "请输入 \$username 的密码 (留空则自动生成随机密码): " password
echo

# 如果用户直接回车,则使用预设的默认值
if [ -z "\$username" ]; then
  root_password="soranohate"
  db_username="shipzy"
  db_password="soranohate"
  
  # 设置root密码
  SET PASSWORD FOR 'root'@'localhost' = PASSWORD('\$root_password');
  
  # 创建WordPress数据库
  CREATE DATABASE wordpress;
  
  # 创建MySQL用户
  CREATE USER '\$db_username'@'localhost' IDENTIFIED BY '\$db_password';
  
  # 关联数据库和用户
  GRANT ALL PRIVILEGES ON wordpress.* TO '\$db_username'@'localhost';
else
  # 如果用户没有输入密码,则生成随机密码
  if [ -z "\$password" ]; then
    db_password=\$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 16)
    echo "自动生成的随机密码为: \$db_password"
  else
    db_password="\$password"
  fi
  
  root_password="\$db_password"
  db_username="\$username"
  
  # 设置root密码
  SET PASSWORD FOR 'root'@'localhost' = PASSWORD('\$root_password');
  
  # 创建WordPress数据库
  CREATE DATABASE wordpress;
  
  # 创建MySQL用户
  CREATE USER '\$db_username'@'localhost' IDENTIFIED BY '\$db_password';
  
  # 关联数据库和用户
  GRANT ALL PRIVILEGES ON wordpress.* TO '\$db_username'@'localhost';
fi

# 刷新权限
FLUSH PRIVILEGES;

# 退出MySQL
exit
EOF

# 删除wordpress空文件夹
rm -rf /var/www/html/wordpress

# 安装wget
apt install wget -y

# 下载wordpress压缩包
wget https://cn.wordpress.org/latest-zh_CN.zip

# 安装unzip
apt install unzip -y

# 解压wordpress压缩包
unzip latest-zh_CN.zip

# 移动wordpress文件夹到网站根目录 
mv wordpress /var/www/html/

# 修改wordpress目录权限
chmod -R 777 /var/www/html/wordpress

# 移动index.html
mv /var/www/html/index.html /var/www/html/wordpress/index~.html

# 重启php7.4-fpm
systemctl restart php7.4-fpm

# 重启mysql
systemctl restart mariadb

# 重启apache2
systemctl restart apache2

echo "===== 账号密码信息 ====="
echo "MySQL root 密码: $root_password"
echo "WordPress 数据库名: wordpress"
echo "WordPress 数据库用户名: $db_username"
echo "WordPress 数据库密码: $db_password"

echo "WordPress安装完成,请访问 http://服务器公网IP地址 开始安装"
