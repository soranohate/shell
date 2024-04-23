#!/bin/bash

set -e

black="033[30m"		# 黑色字体
red="\033[31m"		# 红色字体
green="\033[32m"	# 绿色字体
yellow="\033[33m"	# 黄色字体
blue="\033[34m"		# 蓝色字体
purple="\033[35m"	# 紫色字体
sblue="\033[36m"	# 天蓝色字体
white="\033[37m"	# 白色字体


blackb="\033[40m"	# 黑色背景
redb="\033[41m"		# 红色背景
greenb="\033[42m"	# 绿色背景
yellowb="\033[43m"	# 黄色背景
blueb="\033[44m"	# 蓝色背景
purpleb="\033[45m"	# 紫色背景
sblueb="\033[46m"	# 天蓝色背景
whiteb="\033[47m"	# 白色背景

hl="\033[1m"		# 高亮
ul="\033[4m"		# 下划线
fl="\033[5m"		# 闪烁
rev="\033[7m"		# 反显
xy="\033[8m"		# 显隐
uc="\033[1A"		# 光标上移一格
dc="\033[1B"		# 光标下移一格
rc="\033[1C"		# 光标右移一格
lc="\033[1D"		# 光标左移一格
fc="\033[0G"		# 光标移动到首行
cal="\033[K"		# 清除从光标到行尾的内容
rec="\033[0;0H"		# 重置光标到0,0处，前一个为y，后一个为x
cl="\033[2J"		# 清屏
hc="\033[?25l"		# 隐藏光标
sc="\033[?25h"		# 显示光标


reset="\033[0;39m"	#重置字体及背景颜色

value=  
function askvalue(){
    value=$1
    while [[ -z "$value" ]]; do
        echo -e "$2"
        read readvalue
        if [[ -n "$3" ]]; then
	    if [[ "$3" == "null" ]]; then
		value="$readvalue"
	    else
                if echo "${readvalue}" | grep -Eq "$3"; then
                    value="$readvalue"
                fi
            fi

            if [[ -n "$4" && -z "$value" ]]; then
		value="$4"
	    fi
        else
            value="$readvalue"
        fi
    done            
}

apt install curl -y
bashdomain="bash.vin"
temfile="/tmp/dockertempfile.sh"
function execbash(){
    url=$(curl -LsS "${bashdomain}" | grep -E "$1" | sed -En "s/.*\(.* (http.+)\).*/\1/p")
    if [[ -z "$url" ]]; then
	echo -e "${red}${hl}无法从${bashdomain}中获取脚本:$1${reset}"
    fi
    touch "$temfile"
    curl -L "$url" > "$temfile"
    bash "$temfile" "$2" "$3" "$4" "$5"
    rm "$temfile"
}

apt install jq -y
newestver=
newestname=
function githubversion(){
    releaseInfo=$(curl -LsS "https://api.github.com/repos/$1/$2/releases/latest")
    #newestver=$(echo "$releaseInfo" | jq -r '.tag_name | split("v")[1]')
    newestver=$(echo "$releaseInfo" | jq -r '.tag_name')
    newestname=$(echo "$releaseInfo" | jq -r '.name')
}

dockerHome=$1
version=$2

askvalue "$dockerHome" "${yellow}请给出docker文件要放置的目录(留空默认使用 ${green}${HOME}${yellow})：${reset}" "null" "${HOME}"
dockerHome="$value"
dockercomposePath="${dockerHome}/docker"
mkdir -p "${dockercomposePath}"
touch "${dockercomposePath}/docker-compose.yml"

githubversion "docker" "compose"

askvalue "$version" "${yellow}请选择要安装的版本(留空默认使用最新版本：${green}${newestname}${yellow})：${reset}" "null" "$newestver"
version="$value"

execbash "docker.sh"


curl -LsS "https://github.com/docker/compose/releases/download/${version}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod u+x /usr/local/bin/docker-compose

echo -e "${yellow}${hl}docekr-compose目录保存在 ${blue}${dockercomposePath} ${reset}"
echo -e "${yellow}${hl}编辑该目录下 ${green}docker-compose.yml ${yellow}文件后${reset}"
echo -e "${yellow}${hl}在该目录下使用 ${purple}docker-compose up -d ${yellow}命令即可启动docker程序${reset}"
