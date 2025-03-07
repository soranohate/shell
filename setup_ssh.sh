#!/bin/bash

CONFIG_FILE="/etc/ssh/sshd_config"
BACKUP_FILE="/etc/ssh/sshd_config.bak"

# 检查 root 权限
if [ "$(id -u)" != "0" ]; then
    echo "此脚本需要 root 权限，请以 root 身份运行"
    exit 1
fi

# 备份配置文件
if [ -f "$BACKUP_FILE" ]; then
    echo "备份文件 $BACKUP_FILE 已存在，是否覆盖？(y/n)"
    read -p "输入 y 覆盖，n 退出: " overwrite
    overwrite=$(echo "$overwrite" | tr '[:upper:]' '[:lower:]')
    if [ "$overwrite" != "y" ]; then
        echo "脚本退出"
        exit 1
    fi
fi
cp "$CONFIG_FILE" "$BACKUP_FILE" || { echo "备份 $CONFIG_FILE 失败"; exit 1; }
echo "配置文件已备份到 $BACKUP_FILE"

# 提示用户选择
echo "是否自动更新 SSH 配置文件？（推荐）"
read -p "输入 y 自动更新，n 手动编辑: " choice
choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]')

if [ "$choice" = "y" ]; then
    # 自动更新配置
    echo "正在自动更新 SSH 配置文件..."
    for opt in \
        "PubkeyAuthentication yes" \
        "PasswordAuthentication no" \
        "AuthorizedKeysFile .ssh/authorized_keys" \
        "PermitRootLogin prohibit-password"; do
        key=$(echo "$opt" | cut -d' ' -f1)
        if grep -q "^#*$key " "$CONFIG_FILE"; then
            sed -i "/^#*$key /s/.*/$opt/" "$CONFIG_FILE"
        else
            echo "$opt" >> "$CONFIG_FILE"
        fi
    done
    echo "自动更新完成"
else
    # 手动编辑配置
    echo "请手动编辑 $CONFIG_FILE，确保以下配置项正确设置："
    echo "  - PubkeyAuthentication yes"
    echo "  - PasswordAuthentication no"
    echo "  - AuthorizedKeysFile .ssh/authorized_keys"
    echo "  - PermitRootLogin prohibit-password"
    read -p "按 Enter 键继续，脚本将打开编辑器..."
    if command -v nano > /dev/null; then
        nano "$CONFIG_FILE"
    elif command -v vim > /dev/null; then
        vim "$CONFIG_FILE"
    else
        echo "未找到 nano 或 vim，请手动编辑 $CONFIG_FILE"
        exit 1
    fi
    echo "手动编辑完成"
fi

# 测试配置
echo "正在测试 SSH 配置文件..."
if sshd -t; then
    echo "SSH 配置测试通过"
else
    echo "SSH 配置有错误，请检查 $CONFIG_FILE"
    read -p "是否回滚到备份文件？(y/n): " rollback
    rollback=$(echo "$rollback" | tr '[:upper:]' '[:lower:]')
    if [ "$rollback" = "y" ]; then
        cp "$BACKUP_FILE" "$CONFIG_FILE" || { echo "回滚失败"; exit 1; }
        echo "已回滚到备份文件"
    fi
    exit 1
fi
