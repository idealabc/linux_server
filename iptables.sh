#!/bin/bash

###########################################################
# 翻译自 https://github.com/suin/iptables
#
# 受信 销毁接收/过境，并指定白名单允许的内容。
# 允许发送 服务器有可能成为踏脚凳，给外部服务器造成麻烦
# 如果您担心，您可能需要重写传输以允许它以及基本的丢弃/白名单以及接收。
###########################################################

###########################################################
# 术语
# 为了清晰起见，统一规则和评论条款如下
# ACCEPT : 充许
# DROP   : 废弃
# REJECT : 拒否
###########################################################

###########################################################
# 备忘单
#
# -A, --append       将一个或多个新规则添加到指定的链中
# -D, --delete       从指定链中删除一个或多个规则
# -P, --policy       设置指定链的策略到指定目标
# -N, --new-chain    创建一个新的用户定义的链
# -X, --delete-chain 删除指定的用户自定义链
# -F                 表初始化
#
# -p, --protocol      指定协议           协议（tcp，udp，icmp，all）
# -s, --source        IP[/mask]源地址    描述IP地址或主机名
# -d, --destination   IP[/mask]目标地址  描述IP地址或主机名
# -i, --in-interface  接口               数据包进入的接口
# -o, --out-interface 接口               数据包输出的接口
# -j, --jump          目标         	    匹配目标条件时指定操作
# -t, --table         表           		指定列表
# -m state --state    状态               指定数据包的条件
#                                       状态可以是 NEW（新建）、ESTABLISHED（建联的）、RELATED（相关的）、INVALID（无效的）
# !                   反转条件（～除外）
###########################################################

# 路径
PATH=/sbin:/usr/sbin:/bin:/usr/bin

###########################################################
# IP 定义
# 根据需要定义，没有定义也可以工作。
###########################################################

# 内部网络，充许的地址/范围
# LOCAL_NET="xxx.xxx.xxx.xxx/xx"

# 内部网络，充许部分限制的地址/范围
# LIMITED_LOCAL_NET="xxx.xxx.xxx.xxx/xx"

# Zabbix服务器IP
# ZABBIX_IP="xxx.xxx.xxx.xxx"

# 定义代表所有IP的设置
# ANY="0.0.0.0/0"

# 可信的主机IP列表，白名单
# ALLOW_HOSTS=(
# 	"xxx.xxx.xxx.xxx"
# 	"xxx.xxx.xxx.xxx"
# 	"xxx.xxx.xxx.xxx"
# )

# 无条件禁止的IP列表，黑名单
# DENY_HOSTS=(
# 	"xxx.xxx.xxx.xxx"
# 	"xxx.xxx.xxx.xxx"
# 	"xxx.xxx.xxx.xxx"
# )

###########################################################
# 端口定义
###########################################################

SSH=22
FTP=20,21
DNS=53
SMTP=25,465,587
POP3=110,995
IMAP=143,993
HTTP=80,443
IDENT=113
NTP=123
MYSQL=3306
NET_BIOS=135,137,138,139,445
DHCP=67,68

###########################################################
# 功能
###########################################################

# iptables 初始化，删除所有规则
initialize() 
{
	iptables -F # 表  初期化
	iptables -X # 删除  链
	iptables -Z # 清除包计数器，字节计数器
	iptables -P INPUT   ACCEPT
	iptables -P OUTPUT  ACCEPT
	iptables -P FORWARD ACCEPT
}

# 设置规则后，保存,并重启防火墙
finailize()
{
	/etc/init.d/iptables save && # 保存
	/etc/init.d/iptables restart && # 重启
	return 0
	return 1
}

# 开关
if [ "$1" == "dev" ]
then
	iptables() { echo "iptables $@"; }
	finailize() { echo "finailize"; }
fi

###########################################################
# iptables 初始化
###########################################################
initialize

###########################################################
# 规则制定
###########################################################
iptables -P INPUT   DROP # 输入全部DROP 覆盖所有端口，然后，留下必要的端口
iptables -P OUTPUT  ACCEPT  # 输出
iptables -P FORWARD DROP   # 转发

###########################################################
# 充许受信任的主机
###########################################################

# 本机
# lo 是本机环路， 指向自己
iptables -A INPUT -i lo -j ACCEPT # SELF -> SELF

# 本地网络
# $LOCAL_NET 充许与内部网络通信的服务器
if [ "$LOCAL_NET" ]
then
	iptables -A INPUT -p tcp -s $LOCAL_NET -j ACCEPT # LOCAL_NET -> SELF
fi

# 受信任的主机
# $ALLOW_HOSTS 充许的IP地址列表
if [ "${ALLOW_HOSTS}" ]
then
	for allow_host in ${ALLOW_HOSTS[@]}
	do
		iptables -A INPUT -p tcp -s $allow_host -j ACCEPT # allow_host -> SELF
	done
fi

###########################################################
# $DENY_HOSTS 禁止的IP地址列表
###########################################################
if [ "${DENY_HOSTS}" ]
then
	for deny_host in ${DENY_HOSTS[@]}
	do
		iptables -A INPUT -s $deny_host -m limit --limit 1/s -j LOG --log-prefix "deny_host: "
		iptables -A INPUT -s $deny_host -j DROP
	done
fi

###########################################################
# 充许会话建立后的分组通信
###########################################################
iptables -A INPUT  -p tcp -m state --state ESTABLISHED,RELATED -j ACCEPT

###########################################################
# 攻击手段: 隐形扫描 Stealth Scan
###########################################################
iptables -N STEALTH_SCAN # "STEALTH_SCAN"  #创建隐形扫描的链表
iptables -A STEALTH_SCAN -j LOG --log-prefix "stealth_scan_attack: "
iptables -A STEALTH_SCAN -j DROP

# 秘密扫描Rashiki包跳转到“STEALTH_SCAN”链
iptables -A INPUT -p tcp --tcp-flags SYN,ACK SYN,ACK -m state --state NEW -j STEALTH_SCAN
iptables -A INPUT -p tcp --tcp-flags ALL NONE -j STEALTH_SCAN


iptables -A INPUT -p tcp --tcp-flags SYN,FIN SYN,FIN         -j STEALTH_SCAN
iptables -A INPUT -p tcp --tcp-flags SYN,RST SYN,RST         -j STEALTH_SCAN
iptables -A INPUT -p tcp --tcp-flags ALL SYN,RST,ACK,FIN,URG -j STEALTH_SCAN

iptables -A INPUT -p tcp --tcp-flags FIN,RST FIN,RST -j STEALTH_SCAN
iptables -A INPUT -p tcp --tcp-flags ACK,FIN FIN     -j STEALTH_SCAN
iptables -A INPUT -p tcp --tcp-flags ACK,PSH PSH     -j STEALTH_SCAN
iptables -A INPUT -p tcp --tcp-flags ACK,URG URG     -j STEALTH_SCAN

###########################################################
# 攻撃対策: 由片段分组的端口扫描,DOS攻撃
# namap -v -sF 対策
###########################################################
iptables -A INPUT -f -j LOG --log-prefix 'fragment_packet:'
iptables -A INPUT -f -j DROP
 
###########################################################
# 攻撃対策: Ping of Death
###########################################################
# 每秒ping 一次，超过10次
iptables -N PING_OF_DEATH # "PING_OF_DEATH" 用这个名字做链表
iptables -A PING_OF_DEATH -p icmp --icmp-type echo-request \
         -m hashlimit \
         --hashlimit 1/s \
         --hashlimit-burst 10 \
         --hashlimit-htable-expire 300000 \
         --hashlimit-mode srcip \
         --hashlimit-name t_PING_OF_DEATH \
         -j RETURN

# 取消超越限制的icmp
iptables -A PING_OF_DEATH -j LOG --log-prefix "ping_of_death_attack: "
iptables -A PING_OF_DEATH -j DROP

# ICMP 是 "PING_OF_DEATH" 跳台
iptables -A INPUT -p icmp --icmp-type echo-request -j PING_OF_DEATH

###########################################################
# 攻撃対策: SYN Flood Attack
# 除了这个对策，还应该有效地使用Syn Cookie 
###########################################################
iptables -N SYN_FLOOD # "SYN_FLOOD" という名前でチェーンを作る
iptables -A SYN_FLOOD -p tcp --syn \
         -m hashlimit \
         --hashlimit 200/s \
         --hashlimit-burst 3 \
         --hashlimit-htable-expire 300000 \
         --hashlimit-mode srcip \
         --hashlimit-name t_SYN_FLOOD \
         -j RETURN

# 解説
# -m hashlimit                       主机上限 limit く hashlimit 
# --hashlimit 200/s                  每秒200次连接是上限
# --hashlimit-burst 3                超过上述上限的连接连续三次被限制
# --hashlimit-htable-expire 300000   管理表中限制的有效期限（単位：ms
# --hashlimit-mode srcip             用发送源地址来管理请求数目。
# --hashlimit-name t_SYN_FLOOD       /proc/net/ipt_hashlimit 被保存的哈希表名
# -j RETURN                          如果在限制范围内，就会返回父母链

# 超过了限制的 SYN 进放废弃分组
iptables -A SYN_FLOOD -j LOG --log-prefix "syn_flood_attack: "
iptables -A SYN_FLOOD -j DROP

# SYN 跳到 "SYN_FLOOD" 
iptables -A INPUT -p tcp --syn -j SYN_FLOOD

###########################################################
# 攻撃対策: HTTP DoS/DDoS Attack
###########################################################
iptables -N HTTP_DOS # "HTTP_DOS" 用这个名字做链表
iptables -A HTTP_DOS -p tcp -m multiport --dports $HTTP \
         -m hashlimit \
         --hashlimit 1/s \
         --hashlimit-burst 100 \
         --hashlimit-htable-expire 300000 \
         --hashlimit-mode srcip \
         --hashlimit-name t_HTTP_DOS \
         -j RETURN

# 解説
# -m hashlimit                       主机上限 limit < hashlimit 
# --hashlimit 1/s                    以每秒1连接为上限。
# --hashlimit-burst 100              如果超过100次以上的上限，就会受到限制
# --hashlimit-htable-expire 300000   管理表中限制的有效期限（単位：ms
# --hashlimit-mode srcip             用发送源地址来管理请求数目。
# --hashlimit-name t_HTTP_DOS        /proc/net/ipt_hashlimit 被保存的哈希表名
# -j RETURN                          如果在限制范围内，就会返回父母链

# 取消超越限制的连接
iptables -A HTTP_DOS -j LOG --log-prefix "http_dos_attack: "
iptables -A HTTP_DOS -j DROP

# HTTP分组 跳到 "HTTP_DOS" 
iptables -A INPUT -p tcp -m multiport --dports $HTTP -j HTTP_DOS

###########################################################
# 攻撃対策: IDENT port probe
# ident 服务器端口探测
# 确认系统是否容易攻击，进行端口扫描
# 都是有可能的
# DROP 邮件服务器等的响应越来越低 REJECT
###########################################################
iptables -A INPUT -p tcp -m multiport --dports $IDENT -j REJECT --reject-with tcp-reset

###########################################################
# 攻撃対策: SSH Brute Force
# SSH 暴力破解
# 1分钟内不能进行5次连接。
# SSH为了防止客户端再次连接 REJECT。
# 如果ssh服务器是口令认证，则将以下进行拒绝。
###########################################################
# iptables -A INPUT -p tcp --syn -m multiport --dports $SSH -m recent --name ssh_attack --set
# iptables -A INPUT -p tcp --syn -m multiport --dports $SSH -m recent --name ssh_attack --rcheck --seconds 60 --hitcount 5 -j LOG --log-prefix "ssh_brute_force: "
# iptables -A INPUT -p tcp --syn -m multiport --dports $SSH -m recent --name ssh_attack --rcheck --seconds 60 --hitcount 5 -j REJECT --reject-with tcp-reset

###########################################################
# 攻撃対策: FTP Brute Force
# FTP 暴力破解
# 1分钟内不能进行5次连接。
# 为了防止ftp客户端重复再次连接，REJECT
# FTP 启动时，使用下面的配置
###########################################################
# iptables -A INPUT -p tcp --syn -m multiport --dports $FTP -m recent --name ftp_attack --set
# iptables -A INPUT -p tcp --syn -m multiport --dports $FTP -m recent --name ftp_attack --rcheck --seconds 60 --hitcount 5 -j LOG --log-prefix "ftp_brute_force: "
# iptables -A INPUT -p tcp --syn -m multiport --dports $FTP -m recent --name ftp_attack --rcheck --seconds 60 --hitcount 5 -j REJECT --reject-with tcp-reset

###########################################################
# 全主机(广播地址，组播地址)的数据包被丢弃。
###########################################################
iptables -A INPUT -d 192.168.1.255   -j LOG --log-prefix "drop_broadcast: "
iptables -A INPUT -d 192.168.1.255   -j DROP
iptables -A INPUT -d 255.255.255.255 -j LOG --log-prefix "drop_broadcast: "
iptables -A INPUT -d 255.255.255.255 -j DROP
iptables -A INPUT -d 224.0.0.1       -j LOG --log-prefix "drop_broadcast: "
iptables -A INPUT -d 224.0.0.1       -j DROP

###########################################################
# 来自所有主机(任何)的输入许可。
###########################################################

# ICMP: ping 响应的设定
iptables -A INPUT -p icmp -j ACCEPT # ANY -> SELF

# HTTP, HTTPS
iptables -A INPUT -p tcp -m multiport --dports $HTTP -j ACCEPT # ANY -> SELF

# SSH: 在限制主机的情况下，在trust_host中写上信任主机并对下述内容进行注释。
iptables -A INPUT -p tcp -m multiport --dports $SSH -j ACCEPT # ANY -> SEL

# FTP
# iptables -A INPUT -p tcp -m multiport --dports $FTP -j ACCEPT # ANY -> SELF

# DNS
# iptables -A INPUT -p tcp -m multiport --sports $DNS -j ACCEPT # ANY -> SELF
# iptables -A INPUT -p udp -m multiport --sports $DNS -j ACCEPT # ANY -> SELF

# SMTP
# iptables -A INPUT -p tcp -m multiport --sports $SMTP -j ACCEPT # ANY -> SELF

# POP3
# iptables -A INPUT -p tcp -m multiport --sports $POP3 -j ACCEPT # ANY -> SELF

# IMAP
# iptables -A INPUT -p tcp -m multiport --sports $IMAP -j ACCEPT # ANY -> SELF

###########################################################
# 本地网络(限制)允许输入
###########################################################

if [ "$LIMITED_LOCAL_NET" ]
then
	# SSH
	iptables -A INPUT -p tcp -s $LIMITED_LOCAL_NET -m multiport --dports $SSH -j ACCEPT # LIMITED_LOCAL_NET -> SELF
	
	# FTP
	iptables -A INPUT -p tcp -s $LIMITED_LOCAL_NET -m multiport --dports $FTP -j ACCEPT # LIMITED_LOCAL_NET -> SELF

	# MySQL
	iptables -A INPUT -p tcp -s $LIMITED_LOCAL_NET -m multiport --dports $MYSQL -j ACCEPT # LIMITED_LOCAL_NET -> SELF
fi

###########################################################
# 特定主机的输入许可。
###########################################################

if [ "$ZABBIX_IP" ]
then
	# Zabbix 联机许可
	iptables -A INPUT -p tcp -s $ZABBIX_IP --dport 10050 -j ACCEPT # Zabbix -> SELF
fi

###########################################################
# 除此之外
# 上面的规则也不适用的东西被废除后作废
###########################################################
iptables -A INPUT  -j LOG --log-prefix "drop: "
iptables -A INPUT  -j DROP

###########################################################
# SSH 截止回避对策
# 在30秒内进行休眠之后，将iptables复位。
# SSH 如果没有结出，就会按住ctrl - c。
###########################################################
trap 'finailize && exit 0' 2 # Ctrl-C  
echo "In 30 seconds iptables will be automatically reset."
echo "Don't forget to test new SSH connection!"
echo "If there is no problem then press Ctrl-C to finish."
sleep 30
echo "rollback..."
initialize





















