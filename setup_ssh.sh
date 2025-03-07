#!/bin/bash

# 脚本：配置 SSH 密钥认证并禁用密码登录（适用于 root 用户）

# 检查 root 权限
if [ "$(id -u)" != "0" ]; then
    echo "此脚本需要 root 权限，请以 root 身份运行"
    exit 1
fi

# 1. 检查并生成 SSH 密钥对
echo "正在检查 SSH 密钥对..."
if [ ! -f ~/.ssh/id_rsa ]; then
    echo "未找到现有密钥对，正在生成新的 SSH 密钥对..."
    ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
    echo "密钥对生成成功！"
else
    echo "SSH 密钥对已存在，跳过生成步骤。"
fi

# 2. 显示私钥内容并提醒保存
echo "以下是你的私钥内容，请复制并妥善保存："
cat ~/.ssh/id_rsa
echo "===================================="
echo "私钥显示完毕，请务必保存到安全位置！"

# 3. 将公钥添加到 authorized_keys 文件
echo "正在将公钥添加到 ~/.ssh/authorized_keys..."
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
echo "公钥已成功添加到 authorized_keys 文件。"

# 4. 设置正确的文件权限
echo "正在设置 .ssh 目录和文件的权限..."
[ -d ~/.ssh ] || mkdir -p ~/.ssh  # 如果 .ssh 目录不存在，则创建
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
echo "权限设置完成。"

# 5. 备份 SSH 配置文件
BACKUP_FILE="/etc/ssh/sshd_config.bak"
CONFIG_FILE="/etc/ssh/sshd_config"
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

# 6. 提示用户选择自动更新或手动编辑
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
        "PermitRootLogin yes"; do
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
    echo "  - PermitRootLogin yes"
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

# 7. 测试 SSH 配置
echo "正在测试 SSH 配置文件..."
if sshd -t; then
    echo "SSH 配置测试通过！"
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

# 8. 重启 SSH 服务
echo "正在重启 SSH 服务以应用配置..."
systemctl restart sshd
echo "SSH 服务已重启。"

# 9. 完成提示
echo "脚本执行完成！"
echo "请使用你的私钥测试 SSH 连接，确保配置生效。"
echo "示例命令：ssh -i <私钥文件路径> root@<服务器IP>"
