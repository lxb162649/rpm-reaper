#!/bin/bash
# #############################################
# @Author    :   lixuebing
# @Contact   :   lixuebing@cqsoftware.com.cn
# @Date      :   2025-05-19 9:28:01
# ############################################

source "./common/common_lib.sh"

function pre_test() {
    # 日志文件
    mkdir logs
    LOG_FILE="logs/cp_rpm.log"
    ERROR_FILE="logs/cp_rpm_errors.log"
    INSTALL
    GET_REPOPATH
    # 提示用户是否执行命令
    read -p "是否要收集远程主机上的 RPM 包？(输入 y 或 yes 执行，其他输入则收集本地的 RPM 包)" choice
    # 将用户输入转换为小写，方便统一判断
    choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]')

    # 判断用户输入并执行相应操作
    if [ "$choice" = "y" ] || [ "$choice" = "yes" ]; then
        # 远程主机信息
        REMOTE_HOST=${1:-root@172.16.2.49}
        REMOTE_PASSWORD=${2:-"qwe123,./l;'"}
        # 远程 rpm 搜索地址
        SEARCH_PATH=${3:-"/ -path /var/lib/mock -prune -o"}
        echo "远程主机: $REMOTE_HOST" | tee -a "$LOG_FILE"
        echo "远程密码: $REMOTE_PASSWORD" | tee -a "$LOG_FILE"
    else
        # 本地 rpm 搜索地址
        SEARCH_PATH=${1:-"/ -path /var/lib/mock -prune -o"}
    fi
    echo "本地 RPM 路径: $REPOPATH" | tee -a "$LOG_FILE"
    echo "rpm 搜索路径: $SEARCH_PATH" | tee -a "$LOG_FILE"
    sleep 3
    # 捕获 Ctrl+C 信号并执行清理函数
    trap cleanup SIGINT
}

function run_test() {
    # 初始化日志
    echo "=== $(date) 开始收集 RPM 包 ===" > "$LOG_FILE"
    echo "=== $(date) 错误日志 ===" > "$ERROR_FILE"

    # 判断用户输入并执行相应操作
    if [ "$choice" = "y" ] || [ "$choice" = "yes" ]; then
        # 收集远程 RPM 包位置（排除 /var/lib/mock 目录）
        echo "正在收集远程主机上的RPM包位置..." | tee -a "$LOG_FILE"
        sshpass -p "$REMOTE_PASSWORD" ssh "$REMOTE_HOST" \
        "find $SEARCH_PATH -name '*.rpm' -print 2>/dev/null | grep -E 'noarch|x86_64'" \
        > logs/repo.list.tmp | tee -a "$LOG_FILE"
    else
        # 收集本地 RPM 包位置（排除 /var/lib/mock 目录）
        echo "正在收集本地 RPM 包位置..." | tee -a "$LOG_FILE"
        find $SEARCH_PATH -name '*.rpm' -print 2>/dev/null | grep -E 'noarch|x86_64' > logs/repo.list.tmp
    fi
    CHECK_RESULT $? 0 0

    echo "已收集 $(wc -l < logs/repo.list.tmp) 个RPM包路径" | tee -a "$LOG_FILE"

    # 筛选最高版本的RPM包
    echo "正在筛选最高版本的RPM包..." | tee -a "$LOG_FILE"
    python3 ./common/filter-rpm.py | tee -a "$LOG_FILE"
    CHECK_RESULT $? 0 0

    sleep 3
    # 创建目标目录
    mkdir -p $REPOPATH/RPMS/{noarch,x86_64}

    # 按架构复制 RPM 包
    echo "开始复制RPM包..." | tee -a "$LOG_FILE"
    processed=0
    failed=0

    while IFS= read -r remote_path; do
        # 跳过空行
        if [ -z "$remote_path" ]; then
            continue
        fi
        
        # 获取 RPM 包的架构
        arch=$(echo "$remote_path" | grep -oP '[^.-]+(?=\.rpm$)')
        
        # 根据架构决定本地目标目录
        case "$arch" in
            noarch)
                target_dir="$REPOPATH/RPMS/noarch"
                ;;
            x86_64)
                target_dir="$REPOPATH/RPMS/x86_64"
                ;;
        esac
        
        # 创建目标目录（如果不存在）
        mkdir -p "$target_dir"
        
        # 获取文件名
        filename=$(basename "$remote_path")
        
        if [ -f $target_dir/$filename ]; then
            echo "已存在 $filename，无需复制" | tee -a "$LOG_FILE"
            continue
        fi

        # 复制文件
        echo "[$((processed+1))/$(wc -l < logs/repo.list)] 正在复制 $filename 到 $target_dir..." | tee -a "$LOG_FILE"

        # 判断用户输入并执行相应操作
        if [ "$choice" = "y" ] || [ "$choice" = "yes" ]; then
            # 复制远程 RPM 包到指定路径
            if sshpass -p "$REMOTE_PASSWORD" scp "$REMOTE_HOST:$remote_path" "$target_dir/" 2>> "$ERROR_FILE"; then
                ((processed++))
                echo "  ✔ 成功复制" | tee -a "$LOG_FILE"
            else
                ((failed++))
                echo "  ✖ 复制失败: $remote_path" | tee -a "$LOG_FILE"
                echo "[$(date)] 错误: 无法复制 $remote_path" >> "$ERROR_FILE"
            fi
        else
            # 复制本地 RPM 包到指定路径
            if cp "$remote_path" "$target_dir/" 2>> "$ERROR_FILE"; then
                ((processed++))
                echo "  ✔ 成功复制" | tee -a "$LOG_FILE"
            else
                ((failed++))
                echo "  ✖ 复制失败: $remote_path" | tee -a "$LOG_FILE"
                echo "[$(date)] 错误: 无法复制 $remote_path" >> "$ERROR_FILE"
            fi
        fi
        
    done < logs/repo.list
    CREATEREPO
}


function post_test() {
    # 输出结果统计
    echo "=== 完成 ===" | tee -a "$LOG_FILE"
    echo "成功: $processed 个" | tee -a "$LOG_FILE"
    echo "失败: $failed 个" | tee -a "$LOG_FILE"
    echo "查看详细日志: $LOG_FILE"
    echo "查看错误日志: $ERROR_FILE"
    # 重置 trap
    trap - SIGINT
}

main "$@"
