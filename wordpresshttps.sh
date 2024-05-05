#!/bin/bash

# 提示用户输入邮箱和域名
read -p "请输入你的邮箱地址: " email
read -p "请输入你的域名: " domain

# 安装 acme.sh
curl https://get.acme.sh | sh -s email=$email

# 申请证书
~/.acme.sh/acme.sh --issue -d $domain --nginx

# 安装证书
~/.acme.sh/acme.sh --install-cert -d $domain \
--key-file       /etc/nginx/cert/$domain.key  \
--fullchain-file /etc/nginx/cert/fullchain.cer \
--reloadcmd     "service nginx force-reload"

# 配置 Nginx
cat > /etc/nginx/sites-available/wordpress <<EOF
server {
    listen 80;
    server_name $domain;

    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name $domain;

    ssl_certificate /etc/nginx/cert/fullchain.cer;
    ssl_certificate_key /etc/nginx/cert/$domain.key;
    
    ssl_session_timeout 1d;
    ssl_session_cache shared:MozSSL:10m;  # about 40000 sessions
    ssl_session_tickets off;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    add_header Strict-Transport-Security "max-age=63072000" always;

    ssl_stapling on;
    ssl_stapling_verify on;

    resolver 1.1.1.1 valid=300s;
    resolver_timeout 5s;
      
    root /var/www/html/wordpress;
    index index.php;

    location / {
        try_files \$uri \$uri/ /index.php\$is_args\$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php7.4-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
      
    location = /favicon.ico { 
        log_not_found off; access_log off; 
    }
    location = /robots.txt { 
        log_not_found off; access_log off; allow all; 
    }
    location ~* \.(css|gif|ico|jpeg|jpg|js|png)$ {
        expires max;
        log_not_found off;
    }
}
EOF

ln -s /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/
rm /etc/nginx/sites-enabled/default

# 重启 Nginx
systemctl restart nginx

echo "HTTPS 设置完成。你的 WordPress 网站现在可以通过 https://$domain 访问。"
echo "请检查 WordPress 的设置,确保 WordPress 地址和站点地址都设置为 https://$domain。"
echo "如果遇到样式丢失等问题,请检查 WordPress 的资源链接是否使用了相对路径。"
