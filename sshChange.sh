#!/bin/bash

set -e

port=57280
pwdLen=32
# 检查输入
if [[ -n "$1" && "$1" =~ ^[0-9]+$ ]]; then
    port=$1
fi
if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
    pwdLen=$2
fi	

# 获取旧的ssh端口
oPort=$(sed -En 's/^#?([^#]*)Port ([0-9]+)/\2/p' /etc/ssh/sshd_config | head -n 1)
# 改为新ssh端口
sed -Ei 's/^#?([^#]*)Port .*/\1Port '"$port"'/' /etc/ssh/sshd_config

systemctl restart sshd

# 检测是否为ufw防火墙
if which ufw >/dev/null 2>&1; then
    ufw allow "$port"/tcp
    ufw delete allow "$oPort"/tcp
    ufw delete allow "$oPort"
    echo -e "\033[32m\033[1mufw已开放新ssh端口$port\033[33m并关闭旧ssh端口$oPort\033[0;39m"
else
    echo -e "ufw 未安装,如果使用其他防火墙管理工具\033[0;31m请记得开放ssh端口$port\033[0;39m"
fi

# 随机密码生成工具
apt install pwgen -y

# 修改root密码
pwd=$(pwgen -cnys -r "\'\"" "$pwdLen" 1)
echo 'root:'"$pwd" | chpasswd
echo -e "新的root密码为\033[0;31m\033[1m$pwd\033[0;39m"

