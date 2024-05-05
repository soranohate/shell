#!/bin/bash

# 提示用户输入邮箱和域名
read -p "请输入你的邮箱地址: " email
read -p "请输入你的域名: " domain

# 安装 acme.sh
curl https://get.acme.sh | sh -s email=$email

# 生成证书
~/.acme.sh/acme.sh --issue -d $domain --nginx

# 创建证书目录
mkdir -p /etc/nginx/cert

# 安装证书
~/.acme.sh/acme.sh --install-cert -d $domain \
--key-file       /etc/nginx/cert/key.pem  \
--fullchain-file /etc/nginx/cert/cert.pem \
--reloadcmd     "service nginx force-reload"

# 配置 Nginx
cat > /etc/nginx/sites-available/wordpress <<EOF
server {
    listen 8080;
    listen [::]:8080;
    server_name $domain;
    return 301 https://\$server_name:8443\$request_uri;
}

server {
    listen 8443 ssl;
    listen [::]:8443 ssl;
    server_name $domain;

    ssl_certificate /etc/nginx/cert/cert.pem;
    ssl_certificate_key /etc/nginx/cert/key.pem;
    ssl_session_timeout 5m;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE:ECDH:AES:HIGH:!NULL:!aNULL:!MD5:!ADH:!RC4;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_prefer_server_ciphers on;

    root /var/www/html/wordpress;
    index index.php;

    location = /favicon.ico {
        log_not_found off;
        access_log off;
    }

    location = /robots.txt {
        allow all;
        log_not_found off;
        access_log off;
    }

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php7.4-fpm.sock;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|swf|webp|pdf|txt|doc|docx|xls|xlsx|ppt|pptx|mov|fla|zip|rar)$ {
        expires max;
        access_log off;
        log_not_found off;
        try_files \$uri =404;
    }
}
EOF

ln -s /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/
rm /etc/nginx/sites-enabled/default

# 重启 Nginx
systemctl restart nginx

echo "HTTPS 设置完成。你的 WordPress 网站现在可以通过 https://$domain:8443 访问。"
