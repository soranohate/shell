#!/bin/bash
set -e

# 检查root权限
if [ "$EUID" -ne 0 ]; then
    echo "请使用sudo或以root身份运行此脚本"
    exit 1
fi

# 获取可用域名列表（按字母排序）
show_menu() {
    echo "可用域名列表："
    ls -1 /etc/nginx/sites-available/*.conf 2>/dev/null \
        | sort -V \
        | xargs -n1 basename \
        | sed 's/.conf$//' \
        | nl -s ") " -w 3
    echo
}

# 参数处理
if [ $# -eq 0 ]; then
    show_menu
    read -p "请输入要删除的域名编号或完整域名: " input
    [ -z "$input" ] && { echo "输入不能为空"; exit 1; }

    # 数字输入处理
    if [[ $input =~ ^[0-9]+$ ]]; then
        mapfile -t domains < <(
            ls -1 /etc/nginx/sites-available/*.conf 2>/dev/null \
            | sort -V \
            | xargs -n1 basename \
            | sed 's/.conf$//'
        )
        selected=$((input-1))
        
        # 验证数字范围
        if (( selected < 0 || selected >= ${#domains[@]} )); then
            echo "错误：无效的编号"
            exit 1
        fi
        domain=${domains[$selected]}
    else
        domain=$input
    fi
else
    domain=$1
fi

# 定义路径
nginx_available="/etc/nginx/sites-available/${domain}.conf"
nginx_enabled="/etc/nginx/sites-enabled/${domain}.conf"

# 验证配置存在
if [ ! -f "$nginx_available" ] && [ ! -L "$nginx_enabled" ]; then
    echo "错误：未找到 ${domain} 的Nginx配置"
    exit 1
fi

# 显示删除清单（红色警告）
echo -e "\n\033[31m[警告] 即将永久删除以下内容：\033[0m"
echo "-------------------------------------"
[ -f "$nginx_available" ] && echo "Nginx配置: $nginx_available"
[ -L "$nginx_enabled" ] && echo "启用链接: $nginx_enabled"

cert_paths=(
    "/etc/letsencrypt/live/${domain}"
    "/etc/letsencrypt/archive/${domain}"
    "/etc/letsencrypt/renewal/${domain}.conf"
)

for path in "${cert_paths[@]}"; do
    [ -e "$path" ] && echo "证书相关: $path"
done
echo "相关日志: /var/log/letsencrypt/*"
echo "-------------------------------------"

# 二次确认（带红色强调）
read -p $'\033[31m确认永久删除以上内容？(y/n)\033[0m ' -n 1 confirm
echo
[[ $confirm =~ [yY] ]] || { echo "操作取消"; exit 0; }

# 吊销证书
if [ -d "/etc/letsencrypt/live/${domain}" ]; then
    echo -e "\n吊销SSL证书..."
    certbot revoke --cert-path "/etc/letsencrypt/live/${domain}/cert.pem" \
        --delete-after-revoke --non-interactive
fi

# 删除操作
echo -e "\n删除Nginx配置..."
rm -f "$nginx_available" "$nginx_enabled"

echo "清理证书文件..."
rm -rf "/etc/letsencrypt/live/${domain}" \
       "/etc/letsencrypt/archive/${domain}" \
       "/etc/letsencrypt/renewal/${domain}.conf"

echo "清理日志..."
rm -rf /var/log/letsencrypt/*

# 重载Nginx
echo -e "\n检查Nginx配置..."
if nginx -t; then
    systemctl reload nginx
    echo -e "\n\033[32m[成功] ${domain} 已完全移除\033[0m"
else
    echo -e "\n\033[31m[错误] Nginx配置验证失败，请手动检查！\033[0m"
    exit 1
fi
