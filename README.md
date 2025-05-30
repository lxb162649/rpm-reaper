# rpm收割机

## 介绍

适用系统 CentOS RHEL，可将本地或远程主机上的 rpm 包复制到本地指定目录下（/var/www/html/myrepo），并创建 yum 仓库

## 获取代码

```bash
# 拉取代码
git clone https://gitee.com/lxb162649/rpm-reaper.git

# 查看帮助信息
cd rpm-reaper
./copy_rpm.sh -h
```

## 使用方法

### 1.将本地的 rpm 包复制到本地指定目录下，并创建 yum 仓库

参数1：本地 rpm 搜索地址（默认："/ -path '/var/lib/mock' -prune -o"）

./copy_rpm.sh 参数1

示例：
```bash
# 将本地除 /var/lib/mock 目录下的 rpm 包复制到本地目录下，并创建 yum 仓库
./copy_rpm.sh
# 命令提示行输入回车
```


### 2.将远程主机上的 rpm 包复制到本地，并创建 yum 仓库

参数1：远程主机用户和 ip（默认：root@172.16.2.49）

参数2：远程主机密码（默认：qwe123,./l;'）

参数3：远程 rpm 搜索地址（默认："/ -path '/var/lib/mock' -prune -o"）

./copy_rpm.sh 参数1 参数2 参数3

示例：
```bash
# 将远程主机（172.16.2.49）除 /var/lib/mock 目录下的 rpm 包复制到本地目录下，并创建 yum 仓库
./copy_rpm.sh
# 命令提示行输入 y 或 yes
```




