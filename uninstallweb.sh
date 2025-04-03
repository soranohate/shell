#!/bin/bash
set -e

# 检查是否以root权限运行
if [ "$EUID" -ne 0 ]; then
    echo "请使用sudo或以root身份运行此脚本"
    exit 1
fi

# 获取要删除的域名
read -p "请输入要删除的域名 (例如: p.zyovo.cc): " domain

# 定义相关路径
nginx_available="/etc/nginx/sites-available/${domain}.conf"
nginx_enabled="/etc/nginx/sites-enabled/${domain}.conf"
letsencrypt_live="/etc/letsencrypt/live/${domain}"
letsencrypt_archive="/etc/letsencrypt/archive/${domain}"
letsencrypt_renewal="/etc/letsencrypt/renewal/${domain}.conf"

# 检查配置文件是否存在
if [ ! -f "$nginx_available" ] && [ ! -L "$nginx_enabled" ]; then
    echo "错误：未找到 ${domain} 的Nginx配置文件"
    exit 1
fi

# 显示警告信息
echo -e "\n即将永久删除以下内容："
echo "-------------------------------------"
[ -f "$nginx_available" ] && echo "Nginx配置: $nginx_available"
[ -L "$nginx_enabled" ] && echo "符号链接: $nginx_enabled"
[ -d "$letsencrypt_live" ] && echo "SSL证书(Live): $letsencrypt_live"
[ -d "$letsencrypt_archive" ] && echo "SSL证书(Archive): $letsencrypt_archive"
[ -f "$letsencrypt_renewal" ] && echo "证书续订配置: $letsencrypt_renewal"
echo "相关日志: /var/log/letsencrypt/*"
echo "-------------------------------------"

# 二次确认
read -p "确认要永久删除以上所有内容吗？(y/n): " confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "操作已取消"
    exit 0
fi

# 吊销证书（如果存在）
if [ -d "$letsencrypt_live" ]; then
    echo -e "\n正在吊销SSL证书..."
    certbot revoke --cert-path "$letsencrypt_live/cert.pem" --delete-after-revoke --non-interactive
fi

# 删除所有证书相关配置
echo -e "\n正在清理Certbot配置..."
[ -d "$letsencrypt_live" ] && rm -rf "$letsencrypt_live"
[ -d "$letsencrypt_archive" ] && rm -rf "$letsencrypt_archive"
[ -f "$letsencrypt_renewal" ] && rm -f "$letsencrypt_renewal"

# 删除Nginx配置
echo -e "\n正在删除Nginx配置..."
[ -f "$nginx_available" ] && rm -f "$nginx_available"
[ -L "$nginx_enabled" ] && rm -f "$nginx_enabled"

# 清理日志文件
echo -e "\n正在清理日志..."
rm -rf /var/log/letsencrypt/*

# 测试并重载Nginx配置
echo -e "\n正在验证Nginx配置..."
if nginx -t; then
    echo -e "\n正在重载Nginx服务..."
    systemctl reload nginx
else
    echo "错误：Nginx配置验证失败，请手动检查！"
    exit 1
fi

echo -e "\n[完成] ${domain} 配置已完全清除！"
echo "已删除内容包括："
echo "1. Nginx配置文件"
echo "2. SSL证书文件(Live/Archive)"
echo "3. 证书续订配置"
echo "4. 相关日志文件"
