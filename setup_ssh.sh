#!/bin/bash

# 脚本：配置 SSH 密钥认证并禁用密码登录（适用于 root 用户）

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
echo "正在备份 SSH 配置文件到 /etc/ssh/sshd_config.bak..."
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
echo "备份完成。"

# 6. 提示用户手动编辑 SSH 配置文件
echo "接下来需要手动编辑 SSH 配置文件 /etc/ssh/sshd_config。"
echo "请确保以下配置项正确设置："
echo "  - PubkeyAuthentication yes          # 启用密钥认证"
echo "  - PasswordAuthentication no         # 禁用密码登录"
echo "  - AuthorizedKeysFile .ssh/authorized_keys  # 指定密钥文件路径"
echo "  - PermitRootLogin yes               # 允许 root 登录"
echo "按 Enter 键继续，脚本将打开编辑器..."
read -p ""
nano /etc/ssh/sshd_config  # 可替换为 vim 或其他编辑器
echo "配置文件编辑完成。"

# 7. 测试 SSH 配置
echo "正在测试 SSH 配置文件..."
if sshd -t; then
    echo "SSH 配置测试通过！"
else
    echo "SSH 配置有错误，请检查 /etc/ssh/sshd_config 文件并修正错误后重新运行脚本。"
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
