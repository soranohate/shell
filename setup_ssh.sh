#!/bin/bash

# 脚本：配置 SSH 密钥认证并禁用密码登录（适用于 root 用户）

# 1. 检查是否以 root 身份运行
if [ "$(id -u)" != "0" ]; then
    echo "此脚本必须以 root 身份运行。"
    exit 1
fi

# 2. 检查并生成 SSH 密钥对
echo "正在检查 SSH 密钥对..."
if [ ! -f ~/.ssh/id_rsa ]; then
    echo "未找到现有密钥对，正在生成新的 SSH 密钥对..."
    ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
    echo "密钥对生成成功！"
else
    echo "SSH 密钥对已存在，跳过生成步骤。"
fi

# 3. 显示私钥内容并提醒保存
echo "以下是你的私钥内容，请复制并妥善保存："
cat ~/.ssh/id_rsa
echo "===================================="
echo "私钥显示完毕，请务必保存到安全位置！"

# 4. 将公钥添加到 authorized_keys 文件
echo "正在将公钥添加到 ~/.ssh/authorized_keys..."
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
echo "公钥已成功添加到 authorized_keys 文件。"

# 5. 设置正确的文件权限
echo "正在设置 .ssh 目录和文件的权限..."
[ -d ~/.ssh ] || mkdir -p ~/.ssh  # 如果 .ssh 目录不存在，则创建
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
echo "权限设置完成。"

# 6. 备份 SSH 配置文件并添加覆盖确认
BACKUP_FILE="/etc/ssh/sshd_config.bak"
CONFIG_FILE="/etc/ssh/sshd_config"
echo "正在备份 SSH 配置文件到 $BACKUP_FILE..."
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

# 7. 提示用户手动编辑 SSH 配置文件
echo "请手动编辑 $CONFIG_FILE，确保以下配置项正确设置："
echo "  - PubkeyAuthentication yes          # 启用密钥认证"
echo "  - PasswordAuthentication no         # 禁用密码登录"
echo "  - AuthorizedKeysFile .ssh/authorized_keys  # 指定密钥文件路径"
echo "  - PermitRootLogin without-password  # 仅允许密钥登录"
echo "按 Enter 键继续，脚本将打开编辑器..."
read -p ""
if command -v nano > /dev/null; then
    nano "$CONFIG_FILE"
elif command -v vim > /dev/null; then
    vim "$CONFIG_FILE"
else
    echo "未找到 nano 或 vim，请手动编辑 $CONFIG_FILE"
    exit 1
fi
echo "手动编辑完成"

# 8. 测试 SSH 配置
echo "正在测试 SSH 配置文件..."
if ! sshd -t; then
    echo "SSH 配置有错误，请检查 $CONFIG_FILE 并修正错误后重新运行脚本。"
    echo "你可以使用备份文件 $BACKUP_FILE 恢复原始配置。"
    exit 1
fi
echo "SSH 配置测试通过！"

# 9. 重启 SSH 服务
echo "正在重启 SSH 服务以应用配置..."
systemctl restart sshd
echo "SSH 服务已重启。"

# 10. 完成提示
echo "脚本执行完成！"
echo "请使用你的私钥测试 SSH 连接，确保配置生效。"
echo "示例命令：ssh -i <私钥文件路径> root@<服务器IP>"
