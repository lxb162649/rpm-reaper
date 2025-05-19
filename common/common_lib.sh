#!/usr/bin/bash

# #############################################
# @Author    :   lixuebing
# @Contact   :   lixuebing@cqsoftware.com.cn
# @Date      :   2025-05-19 9:28:01
# ############################################

# 说明
function help(){
	if [[ $1 == "-h" || $1 == "--help" ]]; then
    cat << EOF
功能：将本地或远程主机上的 rpm 包复制到本地指定目录下（/var/www/html/myrepo），并创建 yum 仓库

使用方法
1.将本地的 rpm 包复制到本地指定目录下，并创建 yum 仓库

参数1：远程 rpm 搜索地址（默认："/ -path '/var/lib/mock' -prune -o"）

./copy_rpm.sh 参数1
示例：
./copy_rpm.sh
将本地除 /var/lib/mock 目录下的 rpm 包复制到本地目录下，并创建 yum 仓库

2.将远程主机上的 rpm 包复制到本地，并创建 yum 仓库

参数1：远程主机用户和 ip（默认：root@172.16.2.49）
参数2：远程主机密码（默认：qwe123,./l;'）
参数3：远程 rpm 搜索地址（默认："/ -path '/var/lib/mock' -prune -o"）

./copy_rpm.sh 参数1 参数2 参数3
示例：
./copy_rpm.sh
将远程主机（172.16.2.49）除 /var/lib/mock 目录下的 rpm 包复制到本地目录下，并创建 yum 仓库

EOF
exit 0
fi
}

# 检查上调命令是否成功执行，失败返回失败行，并退出
function CHECK_RESULT() {
    actual_result=$1
    expect_result=${2-0}
    mode=${3-0}
    error_log=$4

    if [ -z "$*" ]; then
        echo "Missing parameter error code."
	((exec_result++))
        return 1
    fi

    if [ "$mode" -eq 0 ]; then
        test "$actual_result"x != "$expect_result"x && {
            test -n "$error_log" && echo "$error_log"
            ((exec_result++))
            echo "${BASH_SOURCE[1]} line ${BASH_LINENO[0]}"
            exit 1;
        }
    else
        test "$actual_result"x == "$expect_result"x && {
            test -n "$error_log" && echo "$error_log"
            ((exec_result++))
            echo "${BASH_SOURCE[1]} line ${BASH_LINENO[0]}"
            exit 1;
        }
    fi
    return 0
}

# 安装
function INSTALL() {
	dnf install -y sshpass httpd createrepo | tee -a "$LOG_FILE"
}

function GET_REPOPATH(){
    systemctl enable --now httpd | tee -a "$LOG_FILE"

    repodata=$(find /var/www/html -name repodata -type d -print -quit 2>/dev/null)

    if [ -n "$repodata" ]; then
        REPOPATH=$(dirname "$repodata")
        echo "仓库路径为：$REPOPATH" | tee -a "$LOG_FILE"
    else
        mkdir -p /var/www/html/myrepo
        REPOPATH="/var/www/html/myrepo"
        echo "仓库路径为：$REPOPATH" | tee -a "$LOG_FILE"
    fi
    REPONAME=$(basename $REPOPATH)
}
function GET_IP(){
    DEFAULT_IF=$(ip route | grep default | awk '{print $5}')  # 获取默认网卡名
    IP=$(ip -4 addr show "$DEFAULT_IF" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
    echo "本地IP：$IP" | tee -a "$LOG_FILE"
}

function CREATEREPO(){
    GET_IP
    if [ ! -f "/etc/yum.repos.d/$REPONAME.repo" ];then
        cat > /etc/yum.repos.d/$REPONAME.repo << EOF
[$REPONAME]
name=$REPONAME
baseurl=http://$IP/$REPONAME
gpgcheck=0
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CYOS

EOF
    fi
    if [ -n "$repodata" ]; then
        createrepo --update $REPOPATH | tee -a "$LOG_FILE"
        CHECK_RESULT $? 0 0 "更新仓库失败"
    else
        createrepo $REPOPATH | tee -a "$LOG_FILE"
        CHECK_RESULT $? 0 0 "创建仓库失败"
    fi
    yum clean all && yum makecache
}

# 定义清理函数
function cleanup() {
    echo -e "\n[$(date)] 操作被用户中断" | tee -a "$LOG_FILE"
    echo "已成功复制 $processed 个文件，失败 $failed 个" | tee -a "$LOG_FILE"
    exit 1
}

function main() {
    help "$@"
    if [ -n "$(type -t post_test)" ]; then
        trap post_test EXIT INT HUP TERM || exit 1
    fi

    if [ -n "$(type -t config_params)" ]; then
        config_params "$@"
    fi

    if [ -n "$(type -t pre_test)" ]; then
        pre_test "$@"
    fi

    if [ -n "$(type -t run_test)" ]; then
        run_test "$@"
    fi
}
