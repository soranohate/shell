#!/bin/bash

# 更新系统依赖
apt update && apt upgrade -y

# 安装Nginx
apt install nginx -y

# 安装MariaDB
apt install mariadb-server -y

# 运行MySQL安全脚本 
mysql_secure_installation <<EOF

n
n
y
y
y
y
EOF

# 提示用户输入要创建的MySQL用户名和密码,如果直接回车则使用默认值
read -p "请输入要创建的MySQL用户名 (默认为shipyz): " db_username
db_username=${db_username:-shipyz}
read -s -p "请输入 $db_username 的密码 (留空则自动生成随机密码): " db_password
echo

# 如果用户没有输入密码,则生成随机密码
if [ -z "$db_password" ]; then
  db_password=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 16)
  echo "自动生成的随机密码为: $db_password"
fi

# 创建WordPress数据库和用户
mysql -u root <<EOF
CREATE DATABASE wordpress DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;
CREATE USER '$db_username'@'localhost' IDENTIFIED BY '$db_password';
GRANT ALL PRIVILEGES ON wordpress.* TO '$db_username'@'localhost';
FLUSH PRIVILEGES;
EXIT;
EOF

# 添加PHP7.4仓库
apt install -y lsb-release apt-transport-https ca-certificates
wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list

# 更新仓库并安装PHP7.4
apt update
apt install -y php7.4-fpm php7.4-mysql php7.4-curl php7.4-gd php7.4-intl php7.4-mbstring php7.4-soap php7.4-xml php7.4-xmlrpc php7.4-zip php7.4-opcache

# 配置Nginx
cat > /etc/nginx/sites-available/wordpress <<EOF
server {
    listen 8080;
    listen [::]:8080;
    server_name _;
    root /var/www/html/wordpress;
    index index.php;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php7.4-fpm.sock;
    }
}
EOF

ln -s /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/
rm /etc/nginx/sites-enabled/default

# 下载并安装WordPress
wget https://cn.wordpress.org/latest-zh_CN.tar.gz
tar zxvf latest-zh_CN.tar.gz -C /var/www/html
chown -R www-data:www-data /var/www/html/wordpress
chmod -R 755 /var/www/html/wordpress

# 配置WordPress
cat > /var/www/html/wordpress/wp-config.php <<EOF
<?php
define( 'DB_NAME', 'wordpress' );
define( 'DB_USER', '$db_username' );
define( 'DB_PASSWORD', '$db_password' );
define( 'DB_HOST', 'localhost' );
define( 'DB_CHARSET', 'utf8' );
define( 'DB_COLLATE', '' );

define( 'WP_SITEURL', 'http://\$_SERVER[HTTP_HOST]:8080' );
define( 'WP_HOME', 'http://\$_SERVER[HTTP_HOST]:8080' );

\$table_prefix = 'wp_';

if ( ! defined( 'ABSPATH' ) ) {
	define( 'ABSPATH', __DIR__ . '/' );
}

require_once ABSPATH . 'wp-settings.php';
EOF

# 优化PHP上传限制
sed -i 's/post_max_size = .*/post_max_size = 50M/' /etc/php/7.4/fpm/php.ini
sed -i 's/upload_max_filesize = .*/upload_max_filesize = 50M/' /etc/php/7.4/fpm/php.ini

# 修改Nginx上传文件限制
sed -i 's/client_max_body_size .*/client_max_body_size 50M;/' /etc/nginx/nginx.conf

# 开启PHP OPcache
sed -i 's/;opcache.enable=.*/opcache.enable=1/' /etc/php/7.4/fpm/php.ini
sed -i 's/;opcache.memory_consumption=.*/opcache.memory_consumption=128/' /etc/php/7.4/fpm/php.ini
sed -i 's/;opcache.validate_timestamps=.*/opcache.validate_timestamps=1/' /etc/php/7.4/fpm/php.ini

# 安装Redis及PHP扩展(可选)
apt install -y redis-server php7.4-redis
systemctl enable redis-server

# 重启服务 
systemctl restart php7.4-fpm
systemctl restart nginx
systemctl restart redis-server

echo "===== 账号密码信息 ====="
echo "WordPress 数据库名: wordpress"
echo "WordPress 数据库用户名: $db_username"
echo "WordPress 数据库密码: $db_password"

echo "WordPress安装完成,请访问 http://服务器IP地址:8080 开始安装"
