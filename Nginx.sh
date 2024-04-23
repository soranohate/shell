#!/bin/bash

set -e

domain=
home=


black="033[30m"         # 黑色字体
red="\033[31m"          # 红色字体
green="\033[32m"        # 绿色字体
yellow="\033[33m"       # 黄色字体
blue="\033[34m"         # 蓝色字体
purple="\033[35m"       # 紫色字体
sblue="\033[36m"        # 天蓝色字体
white="\033[37m"        # 白色字体


blackb="\033[40m"       # 黑色背景
redb="\033[41m"         # 红色背景
greenb="\033[42m"       # 绿色背景
yellowb="\033[43m"      # 黄色背景
blueb="\033[44m"        # 蓝色背景
purpleb="\033[45m"      # 紫色背景
sblueb="\033[46m"       # 天蓝色背景
whiteb="\033[47m"       # 白色背景

hl="\033[1m"            # 高亮
ul="\033[4m"            # 下划线
fl="\033[5m"            # 闪烁
rev="\033[7m"           # 反显
xy="\033[8m"            # 显隐
uc="\033[1A"            # 光标上移一格
dc="\033[1B"            # 光标下移一格
rc="\033[1C"            # 光标右移一格
lc="\033[1D"            # 光标左移一格
fc="\033[0G"            # 光标移动到首行
cal="\033[K"            # 清除从光标到行尾的内容
rec="\033[0;0H"         # 重置光标到0,0处，前一个为y，后一个为x
cl="\033[2J"            # 清屏
hc="\033[?25l"          # 隐藏光标
sc="\033[?25h"          # 显示光标


reset="\033[0;39m"      #重置字体及背景颜色


value=
function askvalue(){
    value=$1
    while [[ -z "$value" ]]; do
        echo -e "$2"
        read readvalue
        if [[ -n "$3" ]]; then
            if echo "${readvalue}" | grep -Eq "$3"; then
                value="$readvalue"
            fi
        else
            value="$readvalue"
        fi
    done
}


apt install curl
bashdomain="bash.vin"
temfile="/tmp/nginxinstalltempscript.sh"
function execbash(){
    url=$(curl -L "${bashdomain}" | grep "$1" | sed -En "s/.*\(.* (http.+)\).*/\1/p")
    touch "$temfile"
    curl -L "$url" > "$temfile"
    bash "$temfile" "$2" "$3" "$4" "$5"
    rm "$temfile"        
}

askvalue "$1" "请给出要安装nignx的home："
home="$value"

askvalue "$2" "请输入要反代的域名："
domain="$value"


if [[ ! -d "/home/$home/tool/nginx" ]]; then
    echo -e "${red}${hl}未检测到nginx文件夹，开始安装nginx...${reset}"
    execbash "nginx.sh" "$home"
fi

execbash "sslreq.sh" "$domain"

path="/home/$home/tool/nginx/conf/vhost"
touch "$path/${domain}.conf"

echo "
#resolver 8.8.8.8;

server{
   listen 443 ssl;
   http2 on;
   server_name  ${domain};

    location / {
        #set \$sni \"\";

        #proxy_set_header Host \$http_host;
	#proxy_set_header X-Real-IP \$HTTP_CF_CONNECTING_IP;
        #proxy_set_header X-Real-IP \$remote_addr;
        #proxy_set_header REMOTE-HOST \$remote_addr;
        #proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        #proxy_pass http://localhost:8080/;
      
        #proxy_ssl_name \$sni;
        #proxy_ssl_server_name on;	

        #proxy_set_header Upgrade \$http_upgrade;
        #proxy_set_header Connection \"Upgrade\";
       
        #root \${webapp}/;
        #index index.html index.htm;
        #try_files \$uri \$uri/ /index.html;
    }


    ssl_certificate /etc/letsencrypt/live/${domain}/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/${domain}/privkey.pem; # managed by Certbot
    #include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
    #ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
}

server {
    listen 80;
    server_name ${domain};


    location / {
        rewrite ^(.*)$ https://\$host\$1 permanent;
    }
}" > "${path}/${domain}.conf"

#touch "${path}/${domain}.stream"

#echo "" > "${path}/${domain}.stream"


echo -e "${blue}${hl}配置文件将保存在 /home/${home}/tool/nginx/conf/vhost/${domain}.conf${reset}"
