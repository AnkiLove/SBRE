#!/usr/bin/env bash
#
# Description: 自动系统信息和I/O测试及中国网络测试脚本
# Author: Anki
#

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
SKYBLUE='\033[0;36m'
PLAIN='\033[0m'
BrowserUA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36"
GeekbenchTest='Y'

about() {
	echo ""
	echo " ========================================================= "
	echo " \                 SBRE-CN  By: Anki                     / "
	echo " ========================================================= "
	echo ""
	echo ""
}

cancel() {
	echo ""
	next;
	echo " 正在中止 ..."
	echo " 正在清理 ..."
	cleanup;
	echo " 完成"
	exit
}

trap cancel SIGINT

benchinit() {
	if [ -f /etc/redhat-release ]; then
	    release="centos"
	elif cat /etc/issue | grep -Eqi "debian"; then
	    release="debian"
	elif cat /etc/issue | grep -Eqi "ubuntu"; then
	    release="ubuntu"
	elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
	    release="centos"
	elif cat /proc/version | grep -Eqi "debian"; then
	    release="debian"
	elif cat /proc/version | grep -Eqi "ubuntu"; then
	    release="ubuntu"
	elif cat /proc/version | grep -Eqi "rockylinux"; then
	    release="rockylinux"
	elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
	    release="centos"
	fi

	[[ $EUID -ne 0 ]] && echo -e "${RED}错误:${PLAIN} 此脚本必须以root权限运行!" && exit 1
	
	# 检测主机架构
	ARCH=$(uname -m)
	if [[ $ARCH = *x86_64* ]]; then
		# 主机运行64位内核
		ARCH="x64"
	elif [[ $ARCH = *i?86* ]]; then
		# 主机运行32位内核
		ARCH="x86"
	elif [[ $ARCH = *aarch* || $ARCH = *arm* ]]; then
		KERNEL_BIT=`getconf LONG_BIT`
		if [[ $KERNEL_BIT = *64* ]]; then
			# 主机运行ARM 64位内核
			ARCH="aarch64"
		else
			# 主机运行ARM 32位内核
			ARCH="arm"
		fi
		echo -e "\nARM兼容性被认为是 *实验性的*"
	else
		# 主机运行不支持的内核
		echo -e "SBRE不支持此架构."
		exit 1
	fi

	if  [[ "$(command -v dmidecode)" == "" ]]; then
		echo " 正在安装 Dmidecode ..."
		if [[ ! -z "$(type -p yum)" ]]; then
			yum -y install dmidecode > /dev/null 2>&1
		else
			apt-get update > /dev/null 2>&1
			apt-get -y install dmidecode > /dev/null 2>&1
		fi
	fi
	
	if  [[ "$(command -v curl)" == "" ]]; then
		echo " 正在安装 Curl ..."
		if [[ ! -z "$(type -p yum)" ]]; then
			yum -y install curl > /dev/null 2>&1
		else
			apt-get update > /dev/null 2>&1
			apt-get -y install curl > /dev/null 2>&1
		fi
	fi

	if  [[ "$(command -v tar)" == "" ]]; then
		echo " 正在安装 Tar ..."
		if [[ ! -z "$(type -p yum)" ]]; then
			yum -y install tar > /dev/null 2>&1
		else
			apt-get update > /dev/null 2>&1
			apt-get -y install tar > /dev/null 2>&1
		fi
	fi
	
	if  [[ "$(command -v wget)" == "" ]]; then
		echo " 正在安装 Wget ..."
		if [[ ! -z "$(type -p yum)" ]]; then
			yum -y install wget > /dev/null 2>&1
		else
			apt-get update > /dev/null 2>&1
			apt-get -y install wget > /dev/null 2>&1
		fi
	fi

	if [[ "$(command -v unzip)" == "" ]]; then
		echo " 正在安装 UnZip ..."
		if [[ ! -z "$(type -p yum)" ]]; then
			yum -y install unzip > /dev/null 2>&1
		else
			apt-get update > /dev/null 2>&1
			apt-get -y install unzip > /dev/null 2>&1
		fi
	fi
	
	IsGlobal="0"
	delay="$(ping -4 -c 2 -w 2 www.google.com | grep rtt | cut -d'/' -f4 | awk '{ print $3 }' | sed -n '/^[0-9]\+\(\.[0-9]\+\)\?$/p')";
	if [ "$delay" != "" ] ; then
		IsGlobal="1"
	fi

	if  [ ! -e './speedtest-cli/speedtest' ]; then
		echo " 正在安装 Speedtest-cli ..."
		wget --no-check-certificate -qO speedtest.tgz https://down.vpsaff.net/linux/speedtest/ookla-speedtest/1.2.0/ookla-speedtest-1.2.0-linux-$(uname -m).tgz > /dev/null 2>&1
	fi
	mkdir -p speedtest-cli && tar zxvf speedtest.tgz -C ./speedtest-cli/ > /dev/null 2>&1 && chmod a+rx ./speedtest-cli/speedtest
	
	# nexttrace
	if [ ! -e './nexttrace' ]; then
		if [[ "$ARCH" == "x64" ]]; then
			wget --no-check-certificate -T 10 -qO nexttrace https://down.vpsaff.net/linux/nexttrace/nexttrace_linux_amd64 > /dev/null 2>&1
		elif [[ "$ARCH" == "x86" ]]; then
			wget --no-check-certificate -T 10 -qO nexttrace https://down.vpsaff.net/linux/nexttrace/nexttrace_linux_386 > /dev/null 2>&1
		elif [[ "$ARCH" == "aarch64" ]]; then
			wget --no-check-certificate -T 10 -qO nexttrace https://down.vpsaff.net/linux/nexttrace/nexttrace_linux_amd64 > /dev/null 2>&1
		fi
	fi
	chmod +x ./nexttrace
	
	if [[ "$GeekbenchTest" == "Y" ]]; then
		if [[ ! -e './geekbench' ]]; then
			mkdir geekbench
		fi
		GeekbenchVer=6
		if [[ $ARCH = *x86* ]]; then
			download_geekbench4;
			$GeekbenchVer=4
		elif [[ $ARCH != *aarch64* && $ARCH != *arm* ]]; then
			if [ ! -e './geekbench/geekbench6' ]; then
				echo " 正在安装 Geekbench 6..."
				wget --no-check-certificate -qO- https://down.vpsaff.net/linux/geekbench/Geekbench-6.3.0-Linux.tar.gz  | tar xz --strip-components=1 -C ./geekbench &>/dev/null
			fi
			chmod +x ./geekbench/geekbench6
		elif [[ $ARCH == *aarch64* ]]; then
			if [ ! -e './geekbench/geekbench6' ]; then
				echo " 正在安装 Geekbench 6..."
				wget --no-check-certificate -qO- https://down.vpsaff.net/linux/geekbench/Geekbench-6.3.0-LinuxARMPreview.tar.gz  | tar xz --strip-components=1 -C ./geekbench &>/dev/null
			fi
			chmod +x ./geekbench/geekbench6
		else
			if [ ! -e './geekbench/geekbench5' ]; then
				echo " 正在安装 Geekbench 5..."
				wget -qO- https://down.vpsaff.net/linux/geekbench/Geekbench-5.4.4-LinuxARMPreview.tar.gz  | tar xz --strip-components=1 -C ./geekbench &>/dev/null
			fi
			chmod +x ./geekbench/geekbench5
		fi
	fi

	sleep 5

	start=$(date +%s) 
}

download_geekbench4(){
	if [[ ! -d ./geekbench ]]; then
		mkdir geekbench
	fi
	if [[ ! -d ./geekbench/geekbench4 ]]; then
		echo -n -e " 正在安装 Geekbench 4..."
		wget -qO- https://down.vpsaff.net/linux/geekbench/Geekbench-4.4.4-Linux.tar.gz | tar xz --strip-components=1 -C ./geekbench &>/dev/null
	fi
	chmod +x ./geekbench/geekbench4
}

download_geekbench5(){
	if [[ ! -d ./geekbench ]]; then
		mkdir geekbench
	fi
	if [[ ! -d ./geekbench/geekbench5 ]]; then
		echo " 正在安装 Geekbench 5..."
		wget -qO- https://down.vpsaff.net/linux/geekbench/Geekbench-5.4.4-Linux.tar.gz  | tar xz --strip-components=1 -C ./geekbench &>/dev/null
	fi
	chmod +x ./geekbench/geekbench5
}

get_opsy() {
    [ -f /etc/redhat-release ] && awk '{print ($1,$3~/^[0-9]/?$3:$4)}' /etc/redhat-release && return
    [ -f /etc/os-release ] && awk -F'[= "]' '/PRETTY_NAME/{print $3,$4,$5}' /etc/os-release && return
    [ -f /etc/lsb-release ] && awk -F'[="]+' '/DESCRIPTION/{print $2}' /etc/lsb-release && return
}

next() {
    printf "%-82s\n" "-" | sed 's/\s/-/g' | tee -a $log
}

speed_test(){
	if [[ $1 == '' ]]; then
		speedtest-cli/speedtest -p no --accept-license --accept-gdpr > $speedLog 2>&1
		is_upload=$(cat $speedLog | grep 'Upload')
		result_speed=$(cat $speedLog | awk -F ' ' '/Result/{print $3}')
		if [[ ${is_upload} ]]; then
	        local REDownload=$(cat $speedLog | awk -F ' ' '/Download/{print $3}')
	        local reupload=$(cat $speedLog | awk -F ' ' '/Upload/{print $3}')
	        local relatency=$(cat $speedLog | awk -F ' ' '/Idle/{print $3}')
	        local packetLoss=$(cat $speedLog | awk -F ' ' '/Packet/{print $3}')
			local result=$(cat $speedLog | grep "Packet Loss: Not available.")
			if [[ "$result" != "" ]]; then
				packetLoss="不可用"
			fi
	        temp=$(echo "$relatency" | awk -F '.' '{print $1}')
        	if [[ ${temp} -gt 50 ]]; then
            	relatency="(*)"${relatency}
        	fi
	        local nodeName=$2

	        temp=$(echo "${REDownload}" | awk -F ' ' '{print $1}')
	        if [[ $(awk -v num1=${temp} -v num2=0 'BEGIN{print(num1>num2)?"1":"0"}') -eq 1 ]]; then
	        	printf "${YELLOW}%-18s${GREEN}%-18s${RED}%-20s${SKYBLUE}%-12s${PLAIN}%-20s\n" " ${nodeName}" "${reupload} Mbit/s" "${REDownload} Mbit/s" "${relatency} ms" "${packetLoss}" | tee -a $log
	        fi
		else
	        local cerror="错误"
		fi
	else
		speedtest-cli/speedtest -p no -s $1 --accept-license --accept-gdpr > $speedLog 2>&1
		is_upload=$(cat $speedLog | grep 'Upload')
		if [[ ${is_upload} ]]; then
	        local REDownload=$(cat $speedLog | awk -F ' ' '/Download/{print $3}')
	        local reupload=$(cat $speedLog | awk -F ' ' '/Upload/{print $3}')
	        local relatency=$(cat $speedLog | awk -F ' ' '/Idle/{print $3}')
	        local packetLoss=$(cat $speedLog | awk -F ' ' '/Packet/{print $3}')
			local result=$(cat $speedLog | grep "Packet Loss: Not available.")
			if [[ "$result" != "" ]]; then
				packetLoss="不可用"
			fi
	        local nodeName=$2

	        temp=$(echo "${REDownload}" | awk -F ' ' '{print $1}')
	        if [[ $(awk -v num1=${temp} -v num2=0 'BEGIN{print(num1>num2)?"1":"0"}') -eq 1 ]]; then
	        	printf "${YELLOW}%-18s${GREEN}%-18s${RED}%-20s${SKYBLUE}%-12s${PLAIN}%-20s\n" " ${nodeName}" "${reupload} Mbit/s" "${REDownload} Mbit/s" "${relatency} ms" "${packetLoss}" | tee -a $log
			fi
		else
	        local cerror="错误"
		fi
	fi
}

print_china_speedtest() {
	printf "%-18s%-18s%-20s%-12s%-20s\n" " 节点名称" "上传速度" "下载速度" "延迟" "丢包率" | tee -a $log
    speed_test '' 'Speedtest.net'
	speed_test '36663' '镇江 5G     CT'
    speed_test '26352' '南京 5G     CT'
    speed_test '35722' '天津        CT'
    speed_test '59386' '杭州        CT'
	speed_test '5145'  '北京        CU'
	speed_test '24447' '上海 5G     CU'
	speed_test '27154' '天津 5G     CU'
	speed_test '54432' '三亚        CU'
	speed_test '13704' '南京        CU'
	speed_test '25637' '上海 5G     CM'
	speed_test '26940' '银川        CM'
	speed_test '27249' '南京 5G     CM'
	speed_test '25858' '北京        CM'
	speed_test '4575'  '成都        CM'
	speed_test '54312' '杭州 5G     CM'
	speed_test '35527' '成都        BN'
}

print_global_speedtest() {
	printf "%-18s%-18s%-20s%-12s%-20s\n" " 节点名称" "上传速度" "下载速度" "延迟" "丢包率" | tee -a $log
    speed_test '1536'  '香港        CN'
	speed_test '18611' '台湾        CN'
	speed_test '40508' '新加坡      SG'
	speed_test '56935' '东京        JP'
	speed_test '67514' '首尔        KR'
    speed_test '18229' '洛杉矶      US'
	speed_test '24281' '伦敦        UK'
	speed_test '53651' '法兰克福    DE'
	speed_test '21268' '法国        FR'
}

print_speedtest_fast() {
	printf "%-18s%-18s%-20s%-12s%-20s\n" " 节点名称" "上传速度" "下载速度" "延迟" "丢包率" | tee -a $log
    speed_test '' 'Speedtest.net'
    speed_test '3633'  '上海        CT'
	speed_test '27594' '广州 5G     CT'
	speed_test '24447' '上海 5G     CU'
	speed_test '9484'  '长春        CU'
	speed_test '45170' '无锡        CU'
	speed_test '25637' '上海 5G     CM'
	speed_test '15863' '南宁        CM'
	speed_test '4575'  '成都        CM'
	speed_test '5505'  '北京        BN'
	speed_test '35527' '成都        BN'
	 
	rm -rf speedtest*
}

io_test() {
    (LANG=C dd if=/dev/zero of=test_file_$$ bs=512K count=$1 conv=fdatasync && rm -f test_file_$$ ) 2>&1 | awk -F, '{io=$NF} END { print io}' | sed 's/^[ \t]*//;s/[ \t]*$//'
}

calc_disk() {
    local total_size=0
    local array=$@
    for size in ${array[@]}
    do
        [ "${size}" == "0" ] && size_t=0 || size_t=`echo ${size:0:${#size}-1}`
        [ "`echo ${size:(-1)}`" == "K" ] && size=0
        [ "`echo ${size:(-1)}`" == "M" ] && size=$( awk 'BEGIN{printf "%.1f", '$size_t' / 1024}' )
        [ "`echo ${size:(-1)}`" == "T" ] && size=$( awk 'BEGIN{printf "%.1f", '$size_t' * 1024}' )
        [ "`echo ${size:(-1)}`" == "G" ] && size=${size_t}
        total_size=$( awk 'BEGIN{printf "%.1f", '$total_size' + '$size'}' )
    done
    echo ${total_size}
}

power_time() {

	result=$(smartctl -a $(result=$(cat /proc/mounts) && echo $(echo "$result" | awk '/data=ordered/{print $1}') | awk '{print $1}') 2>&1) && power_time=$(echo "$result" | awk '/Power_On/{print $10}') && echo "$power_time"
}

ip_info4(){
	local org="$(wget -q -T10 -O- ipinfo.io/org)"
    local city="$(wget -q -T10 -O- ipinfo.io/city)"
    local country="$(wget -q -T10 -O- ipinfo.io/country)"
    local region="$(wget -q -T10 -O- ipinfo.io/region)"
	if [[ -n "$org" ]]; then
		echo -e " 组织                 : ${YELLOW}$org${PLAIN}" | tee -a $log
	fi
	if [[ -n "$city" && -n "country" ]]; then
		echo -e " 位置                 : ${SKYBLUE}$city / ${YELLOW}$country${PLAIN}" | tee -a $log
	fi
	if [[ -n "$region" ]]; then
		echo -e " 地区                 : ${SKYBLUE}$region${PLAIN}" | tee -a $log
	fi
}

virt_check(){
	if hash ifconfig 2>/dev/null; then
		eth=$(ifconfig)
	fi

	virtualx=$(dmesg) 2>/dev/null

    if  [[ "$(command -v dmidecode)" != ""  ]]; then
		sys_manu=$(dmidecode -s system-manufacturer) 2>/dev/null
		sys_product=$(dmidecode -s system-product-name) 2>/dev/null
		sys_ver=$(dmidecode -s system-version) 2>/dev/null
	else
		sys_manu=""
		sys_product=""
		sys_ver=""
	fi
	
	if grep docker /proc/1/cgroup -qa; then
	    virtual="Docker"
	elif grep lxc /proc/1/cgroup -qa; then
		virtual="Lxc"
	elif grep -qa container=lxc /proc/1/environ; then
		virtual="Lxc"
	elif [[ -f /proc/user_beancounters ]]; then
		virtual="OpenVZ"
	elif [[ "$virtualx" == *kvm-clock* ]]; then
		virtual="KVM"
	elif [[ "$cname" == *KVM* ]]; then
		virtual="KVM"
	elif [[ "$cname" == *QEMU* ]]; then
		virtual="KVM"
	elif [[ "$virtualx" == *"VMware Virtual Platform"* ]]; then
		virtual="VMware"
	elif [[ "$virtualx" == *"Parallels Software International"* ]]; then
		virtual="Parallels"
	elif [[ "$virtualx" == *VirtualBox* ]]; then
		virtual="VirtualBox"
	elif [[ -e /proc/xen ]]; then
		virtual="Xen"
	elif [[ "$sys_manu" == *"Microsoft Corporation"* ]]; then
		if [[ "$sys_product" == *"Virtual Machine"* ]]; then
			if [[ "$sys_ver" == *"7.0"* || "$sys_ver" == *"Hyper-V" ]]; then
				virtual="Hyper-V"
			else
				virtual="Microsoft Virtual Machine"
			fi
		fi
	else
		virtual="物理机"
	fi
}

freedisk() {
	freespace=$( df -m . | awk 'NR==2 {print $4}' )
	if [[ $freespace == "" ]]; then
		$freespace=$( df -m . | awk 'NR==3 {print $3}' )
	fi
	if [[ $freespace -gt 1024 ]]; then
		printf "%s" $((1024*2))
	elif [[ $freespace -gt 512 ]]; then
		printf "%s" $((512*2))
	elif [[ $freespace -gt 256 ]]; then
		printf "%s" $((256*2))
	elif [[ $freespace -gt 128 ]]; then
		printf "%s" $((128*2))
	else
		printf "1"
	fi
}

print_io() {
	if [[ $1 == "fast" ]]; then
		writemb=$((128*2))
	else
		writemb=$(freedisk)
	fi
	
	writemb_size="$(( writemb / 2 ))MB"
	if [[ $writemb_size == "1024MB" ]]; then
		writemb_size="1.0GB"
	fi

	if [[ $writemb != "1" ]]; then
		echo -n " I/O 速度( $writemb_size )  : " | tee -a $log
		io1=$( io_test $writemb )
		echo -e "${YELLOW}$io1${PLAIN}" | tee -a $log
		echo -n " I/O 速度( $writemb_size )  : " | tee -a $log
		io2=$( io_test $writemb )
		echo -e "${YELLOW}$io2${PLAIN}" | tee -a $log
		echo -n " I/O 速度( $writemb_size )  : " | tee -a $log
		io3=$( io_test $writemb )
		echo -e "${YELLOW}$io3${PLAIN}" | tee -a $log
		ioraw1=$( echo $io1 | awk 'NR==1 {print $1}' )
		[ "`echo $io1 | awk 'NR==1 {print $2}'`" == "GB/s" ] && ioraw1=$( awk 'BEGIN{print '$ioraw1' * 1024}' )
		ioraw2=$( echo $io2 | awk 'NR==1 {print $1}' )
		[ "`echo $io2 | awk 'NR==1 {print $2}'`" == "GB/s" ] && ioraw2=$( awk 'BEGIN{print '$ioraw2' * 1024}' )
		ioraw3=$( echo $io3 | awk 'NR==1 {print $1}' )
		[ "`echo $io3 | awk 'NR==1 {print $2}'`" == "GB/s" ] && ioraw3=$( awk 'BEGIN{print '$ioraw3' * 1024}' )
		ioall=$( awk 'BEGIN{print '$ioraw1' + '$ioraw2' + '$ioraw3'}' )
		ioavg=$( awk 'BEGIN{printf "%.1f", '$ioall' / 3}' )
		echo -e " 平均 I/O 速度        : ${YELLOW}$ioavg MB/s${PLAIN}" | tee -a $log
	else
		echo -e " ${RED}空间不足!${PLAIN}"
	fi
}

print_system_info() {
	echo -e " CPU 型号             : ${SKYBLUE}$cname${PLAIN}" | tee -a $log
	echo -e " CPU 核心             : ${YELLOW}$cores 核心 ${SKYBLUE}$freq MHz $arch${PLAIN}" | tee -a $log
	if [[ -n "$coresL3cache" ]]; then
		echo -e " CPU 缓存             : ${SKYBLUE}L2 $coresL2cache & ${YELLOW}L3 $coresL3cache${PLAIN}" | tee -a $log
	else
		echo -e " CPU 缓存             : ${SKYBLUE}$corescache ${PLAIN}" | tee -a $log
	fi
	echo -e " CPU 特性             : ${SKYBLUE}AES-NI $aes & ${YELLOW}VM-x/AMD-V $virt ${PLAIN}" | tee -a $log
	echo -e " 操作系统             : ${SKYBLUE}$opsy ($lbit 位) ${YELLOW}$virtual${PLAIN}" | tee -a $log
	echo -e " 内核版本             : ${SKYBLUE}$kern${PLAIN}" | tee -a $log
	echo -e " 总存储空间           : ${SKYBLUE}$disk_used_size GB / ${YELLOW}$disk_total_size GB ${PLAIN}" | tee -a $log
	echo -e " 总内存大小           : ${SKYBLUE}$uram MB / ${YELLOW}$tram MB ${SKYBLUE}($bram MB 缓存)${PLAIN}" | tee -a $log
	echo -e " 总交换空间           : ${SKYBLUE}$uswap MB / $swap MB${PLAIN}" | tee -a $log
	echo -e " 系统运行时间         : ${SKYBLUE}$up${PLAIN}" | tee -a $log
	echo -e " 系统负载             : ${SKYBLUE}$load${PLAIN}" | tee -a $log
	echo -e " TCP 拥塞控制         : ${SKYBLUE}$tcpctrl + ${YELLOW}$qdisc${PLAIN}" | tee -a $log
}

print_end_time() {
	end=$(date +%s) 
	time=$(( $end - $start ))
	if [[ $time -gt 60 ]]; then
		min=$(expr $time / 60)
		sec=$(expr $time % 60)
		echo -ne " 总用时间 : ${min} 分 ${sec} 秒" | tee -a $log
	else
		echo -ne " 总用时间 : ${time} 秒" | tee -a $log
	fi

	printf '\n' | tee -a $log

	bj_time=$(curl -s https://api.idcoffer.com/time)

	if [[ $(echo $bj_time | grep "html") ]]; then
		bj_time=$(date -u +%Y-%m-%d" "%H:%M:%S -d '+8 hours')
	fi
	echo " 测试时间    : $bj_time GMT+8" | tee -a $log
	echo " 测试结果    : $log"
}

get_system_info() {
	cname=$( awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//' )
	cores=$( awk -F: '/model name/ {core++} END {print core}' /proc/cpuinfo )
	freq=$( awk -F: '/cpu MHz/ {freq=$2} END {print freq}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//' )
	corescache=$( awk -F: '/cache size/ {cache=$2} END {print cache}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//' )
	if [[ -e /sys/devices/system/cpu/cpu0/cache/index2/size ]]; then
		coresL2cache=$(cat /sys/devices/system/cpu/cpu0/cache/index2/size)
    fi
	if [[ -e /sys/devices/system/cpu/cpu0/cache/index3/size ]]; then
		coresL3cache=$(cat /sys/devices/system/cpu/cpu0/cache/index3/size)
    fi
	aes=$(cat /proc/cpuinfo | grep aes)
	[[ -z "$aes" ]] && aes="禁用" || aes="启用"
	virt=$(cat /proc/cpuinfo | grep 'vmx\|svm')
	[[ -z "$virt" ]] && virt="禁用" || virt="启用"
	tram=$( free -m | awk '/Mem/ {print $2}' )
	uram=$( free -m | awk '/Mem/ {print $3}' )
	bram=$( free -m | awk '/Mem/ {print $6}' )
	swap=$( free -m | awk '/Swap/ {print $2}' )
	uswap=$( free -m | awk '/Swap/ {print $3}' )
	up=$( awk '{a=$1/86400;b=($1%86400)/3600;c=($1%3600)/60} {printf("%d 天 %d 小时 %d 分钟\n",a,b,c)}' /proc/uptime )
	load=$( w | head -1 | awk -F'load average:' '{print $2}' | sed 's/^[ \t]*//;s/[ \t]*$//' )
	opsy=$( get_opsy )
	arch=$( uname -m )
	lbit=$( getconf LONG_BIT )
	kern=$( uname -r )

	disk_size1=$( LANG=C df -hPl | grep -wvE '\-|none|tmpfs|overlay|shm|udev|devtmpfs|by-uuid|chroot|Filesystem' | awk '{print $2}' )
	disk_size2=$( LANG=C df -hPl | grep -wvE '\-|none|tmpfs|overlay|shm|udev|devtmpfs|by-uuid|chroot|Filesystem' | awk '{print $3}' )
	disk_total_size=$( calc_disk ${disk_size1[@]} )
	disk_used_size=$( calc_disk ${disk_size2[@]} )
	if [[ -e /proc/sys/net/ipv4/tcp_congestion_control ]]; then
		tcpctrl=$( sysctl net.ipv4.tcp_congestion_control | awk -F ' ' '{print $3}' )
	fi
	if [[ -e /proc/sys/net/core/default_qdisc ]]; then
		qdisc=$(sysctl -n net.core.default_qdisc)
	fi

	virt_check
}

traceroute_test() {
	#NextTrace
	if [ "$2" = "tcp" ] || [ "$2" = "TCP" ]; then
        echo -e "\n路由追踪到 $4 (TCP 模式, 最大 $3 跳)" | tee -a $log
        echo -e "============================================================" | tee -a $log
        ./nexttrace $1 -m $3 -g en -T -q 1 2>&1 | tail -n +4 | head -n -1 | tee -a $log
    else
        echo -e "\n路由追踪到 $4 (ICMP 模式, 最大 $3 跳)" | tee -a $log
        echo -e "============================================================" | tee -a $log
        ./nexttrace $1 -m $3 -g en -q 1 2>&1 | tail -n +4 | head -n -1 | tee -a $log
    fi
}

print_traceroute_test(){
	traceroute_test "113.108.209.1" "TCP" "30" "中国, 广州 CT"
	traceroute_test "180.153.28.5" "TCP" "30" "中国, 上海 CT"
    traceroute_test "180.149.128.9" "TCP" "30" "中国, 北京 CT"
	traceroute_test "210.21.4.130" "TCP" "30" "中国, 广州 CU"
	traceroute_test "58.247.8.158" "TCP" "30" "中国, 上海 CU"
	traceroute_test "123.125.99.1" "TCP" "30" "中国, 北京 CU"
	traceroute_test "120.196.212.25" "TCP" "30" "中国, 广州 CM"
    traceroute_test "221.183.55.22" "TCP" "30" "中国, 上海 CM"
	traceroute_test "211.136.25.153" "TCP" "30" "中国, 北京 CM"
	traceroute_test "211.167.230.100" "TCP"  "30" "中国, 北京 鹏博士网络IDC"	
}

geekbench() {
	echo -e " Geekbench v${GeekbenchVer} 测试  :" | tee -a $log
	if test -f "geekbench.license"; then
		./geekbench/geekbench$GeekbenchVer --unlock `cat geekbench.license` > /dev/null 2>&1
	fi
	
	GEEKBENCH_TEST=$(./geekbench/geekbench$GeekbenchVer --upload 2>/dev/null | grep "https://browser")
	
	if [[ -z "$GEEKBENCH_TEST" ]]; then
		echo -e " ${RED}Geekbench v${GeekbenchVer} 测试失败。请手动运行以确定原因。${PLAIN}" | tee -a $log
		GEEKBENCH_URL=''
		if [[ $ARCH != *aarch64* && $ARCH != *arm* ]]; then
			if [[ $GeekbenchVer == *6* ]]; then
				rm -rf geekbench
				download_geekbench5;
				echo -n -e "\r" | tee -a $log
				GeekbenchVer=5;
				geekbench;
			elif [[ $GeekbenchVer == *5* ]]; then
				rm -rf geekbench
				download_geekbench4;
				echo -n -e "\r" | tee -a $log
				GeekbenchVer=4;
				geekbench;
			fi
		fi
	else
		GEEKBENCH_URL=$(echo -e $GEEKBENCH_TEST | head -1)
		GEEKBENCH_URL_CLAIM=$(echo $GEEKBENCH_URL | awk '{ print $2 }')
		GEEKBENCH_URL=$(echo $GEEKBENCH_URL | awk '{ print $1 }')
		sleep 5
		([[ $GeekbenchVer == *6* ]] || [[ $GeekbenchVer == *5* ]]) && GEEKBENCH_SCORES=$(curl -s $GEEKBENCH_URL | grep "div class='score'") || GEEKBENCH_SCORES=$(curl -s $GEEKBENCH_URL | grep "span class='score'")
		GEEKBENCH_SCORES_SINGLE=$(echo $GEEKBENCH_SCORES | awk -v FS="(>|<)" '{ print $3 }')
		GEEKBENCH_SCORES_MULTI=$(echo $GEEKBENCH_SCORES | awk -v FS="(>|<)" '{ print $7 }')
		
		echo -e "       单核心          : ${YELLOW}$GEEKBENCH_SCORES_SINGLE  $grank${PLAIN}"  | tee -a $log
		echo -e "       多核心          : ${YELLOW}$GEEKBENCH_SCORES_MULTI${PLAIN}" | tee -a $log
		[ ! -z "$GEEKBENCH_URL_CLAIM" ] && echo -e "$GEEKBENCH_URL_CLAIM" >> geekbench_claim.url 2> /dev/null
	fi
	rm -rf geekbench
}

function UnlockNetflixTest() {
    local result1=$(curl --user-agent "${BrowserUA}" -fsL --write-out %{http_code} --output /dev/null --max-time 10 "https://www.netflix.com/title/81280792" 2>&1)
    local result12=$(curl --user-agent "${BrowserUA}" -fsL --write-out %{http_code} --output /dev/null --max-time 10 "https://www.netflix.com/title/70143836" 2>&1)
	
    if [[ "$result1" == "404" ]] && [[ "$result12" == "404" ]];then
        echo -e " Netflix              : ${YELLOW}仅原创内容${PLAIN}" | tee -a $log
	elif  [[ "$result1" == "403" ]];then
        echo -e " Netflix              : ${RED}否${PLAIN}" | tee -a $log
	elif [[ "$result1" == "200" ]];then
		local region=`tr [:lower:] [:upper:] <<< $(curl --user-agent "${BrowserUA}" -fs --max-time 10 --write-out %{redirect_url} --output /dev/null "https://www.netflix.com/title/80018499" | cut -d '/' -f4 | cut -d '-' -f1)` ;
		if [[ ! -n "$region" ]];then
			region="US";
		fi
		echo -e " Netflix              : ${GREEN}是 (地区: ${region})${PLAIN}" | tee -a $log
	elif  [[ "$result1" == "000" ]];then
		echo -e " Netflix              : ${RED}网络连接失败${PLAIN}" | tee -a $log
    fi   
}

function UnlockYouTubePremiumTest() {
    local tmpresult=$(curl --max-time 10 -sS -H "Accept-Language: en" "https://www.youtube.com/premium" 2>&1 )
    local region=$(curl --user-agent "${BrowserUA}" -sL --max-time 10 "https://www.youtube.com/premium" | grep "countryCode" | sed 's/.*"countryCode"//' | cut -f2 -d'"')
	if [ -n "$region" ]; then
        sleep 0
	else
		isCN=$(echo $tmpresult | grep 'www.google.cn')
		if [ -n "$isCN" ]; then
			region=CN
		else	
			region=US
		fi	
	fi	
	
    if [[ "$tmpresult" == "curl"* ]];then
        echo -e " YouTube Premium      : ${RED}网络连接失败${PLAIN}"  | tee -a $log
        return;
    fi
    
    local result=$(echo $tmpresult | grep 'Premium is not available in your country')
    if [ -n "$result" ]; then
        echo -e " YouTube Premium      : ${RED}否${PLAIN} ${PLAIN}${GREEN} (地区: $region)${PLAIN}" | tee -a $log
        return;
		
    fi
    local result=$(echo $tmpresult | grep 'YouTube and YouTube Music ad-free')
    if [ -n "$result" ]; then
        echo -e " YouTube Premium      : ${GREEN}是 (地区: $region)${PLAIN}" | tee -a $log
        return;
	else
		echo -e " YouTube Premium      : ${RED}失败${PLAIN}" | tee -a $log
    fi
}

function YouTubeCDNTest() {
	local tmpresult=$(curl -sS --max-time 10 https://redirector.googlevideo.com/report_mapping 2>&1)    
    if [[ "$tmpresult" == "curl"* ]];then
        echo -e " YouTube CDN          : ${RED}网络连接失败${PLAIN}" | tee -a $log
        return;
    fi
	
	local IATACode=$(curl -s --retry 3 --max-time 10 "https://down.vpsaff.net/iata/IATACode.txt");
    local iata=$(echo $tmpresult | grep '=>'| awk "NR==1" | awk '{print $3}' | cut -f2 -d'-' | cut -c 1-3 | tr [:lower:] [:upper:])
    if [ -n "$iata" ] && [ ${#iata} -eq 3 ]; then
        local lineNo=$(echo "$IATACode" | cut -f3 -d"|" | sed -n "/${iata}/=")
		if [ -n "$lineNo" ]; then
			local location=$(echo "$IATACode" | awk "NR==${lineNo}" | cut -f1 -d"|" | sed -e 's/^[[:space:]]*//')
		else
			local location="$iata"
		fi
    fi
    local isIDC=$(echo $tmpresult | grep "router")
    if [ -n "$iata" ] && [ -z "$isIDC" ]; then
        local CDN_ISP=$(echo $tmpresult | awk "NR==1" | awk '{print $3}' | cut -f1 -d"-" | tr [:lower:] [:upper:])
		echo -e " YouTube CDN          : ${YELLOW}$CDN_ISP 位于 $location${PLAIN}" | tee -a $log
        return
    elif [ -n "$iata" ] && [ -n "$isIDC" ]; then
		echo -e " YouTube CDN          : ${GREEN}$location${PLAIN}" | tee -a $log
        return
    else
		echo -e " YouTube CDN          : ${RED}无法检测${PLAIN}" | tee -a $log
        return
    fi
}

function UnlockBilibiliTest() {
	#Test Mainland
    local randsession="$(cat /dev/urandom | head -n 32 | md5sum | head -c 32)";
    local result=$(curl --user-agent "${BrowserUA}" -fsSL --max-time 10 "https://api.bilibili.com/pgc/player/web/playurl?avid=82846771&qn=0&type=&otype=json&ep_id=307247&fourk=1&fnver=0&fnval=16&session=${randsession}&module=bangumi" 2>&1);
	if [[ "$result" != "curl"* ]]; then
        result="$(echo "${result}" | grep '"code"' | awk -F 'code":' '{print $2}' | awk -F ',' '{print $1}')";
        if [ "${result}" = "0" ]; then
            echo -e " 哔哩哔哩 中国        : ${GREEN}是 (地区: 仅限中国大陆)${PLAIN}" | tee -a $log
			return;
        fi
    else
        echo -e " 哔哩哔哩 中国        : ${RED}网络连接失败${PLAIN}" | tee -a $log
		return;
    fi
	
	#Test Hongkong/Macau/Taiwan
	randsession="$(cat /dev/urandom | head -n 32 | md5sum | head -c 32)";
	result=$(curl --user-agent "${BrowserUA}" -fsSL --max-time 10 "https://api.bilibili.com/pgc/player/web/playurl?avid=18281381&cid=29892777&qn=0&type=&otype=json&ep_id=183799&fourk=1&fnver=0&fnval=16&session=${randsession}&module=bangumi" 2>&1);
    if [[ "$result" != "curl"* ]]; then
        result="$(echo "${result}" | grep '"code"' | awk -F 'code":' '{print $2}' | awk -F ',' '{print $1}')";
        if [ "${result}" = "0" ]; then
            echo -e " 哔哩哔哩 中国        : ${GREEN}是 (地区: 仅限港澳台)${PLAIN}" | tee -a $log
			return;
        fi
    else
        echo -e " 哔哩哔哩 中国        : ${RED}网络连接失败${PLAIN}" | tee -a $log
		return;
    fi
	
	#Test Taiwan
	randsession="$(cat /dev/urandom | head -n 32 | md5sum | head -c 32)";
	result=$(curl --user-agent "${BrowserUA}" -fsSL --max-time 10 "https://api.bilibili.com/pgc/player/web/playurl?avid=50762638&cid=100279344&qn=0&type=&otype=json&ep_id=268176&fourk=1&fnver=0&fnval=16&session=${randsession}&module=bangumi" 2>&1);
	if [[ "$result" != "curl"* ]]; then
		result="$(echo "${result}" | grep '"code"' | awk -F 'code":' '{print $2}' | awk -F ',' '{print $1}')";
		if [ "${result}" = "0" ]; then
            echo -e " 哔哩哔哩 中国        : ${GREEN}是 (地区: 仅限台湾)${PLAIN}" | tee -a $log
			return;
		fi
	else
		echo -e " 哔哩哔哩 中国        : ${RED}网络连接失败${PLAIN}" | tee -a $log
		return;
	fi
	echo -e " 哔哩哔哩 中国        : ${RED}否${PLAIN}" | tee -a $log
}

function UnlockTiktokTest() {
	local result=$(curl --user-agent "${BrowserUA}" -fsSL --max-time 10 "https://www.tiktok.com/" 2>&1);
    if [[ "$result" != "curl"* ]]; then
        result="$(echo ${result} | grep 'vregion' | awk -F 'vregion":"' '{print $2}' | awk -F '"' '{print $1}')";
		if [ -n "$result" ]; then
			if [[ "$result" == "The #TikTokTraditions"* ]] || [[ "$result" == "This LIVE isn't available"* ]]; then
				echo -e " TikTok               : ${RED}否${PLAIN}" | tee -a $log
			else
				echo -e " TikTok               : ${GREEN}是 (地区: ${result})${PLAIN}" | tee -a $log
			fi
		else
			echo -e " TikTok               : ${RED}失败${PLAIN}" | tee -a $log
			return
		fi
    else
		echo -e " TikTok               : ${RED}网络连接失败${PLAIN}" | tee -a $log
	fi
}

function UnlockiQiyiIntlTest() {
	curl --user-agent "${BrowserUA}" -s -I --max-time 10 "https://www.iq.com/" >/tmp/iqiyi
    if [ $? -eq 1 ]; then
        echo -e " 爱奇艺 国际版         : ${RED}网络连接失败${PLAIN}" | tee -a $log
        return
    fi

    local result="$(cat /tmp/iqiyi | grep 'mod=' | awk '{print $2}' | cut -f2 -d'=' | cut -f1 -d';')";
	rm -f /tmp/iqiyi

    if [ -n "$result" ]; then
        if [[ "$result" == "ntw" ]]; then
            result=TW
            echo -e " 爱奇艺 国际版         : ${GREEN}是 (地区: ${result})${PLAIN}" | tee -a $log
            return
        else
            result=$(echo $result | tr [:lower:] [:upper:])
            echo -e " 爱奇艺 国际版         : ${GREEN}是 (地区: ${result})${PLAIN}" | tee -a $log
            return
        fi
    else
        echo -e " 爱奇艺 国际版         : ${RED}失败${PLAIN}" | tee -a $log
        return
    fi
}

function UnlockChatGPTTest() {
	if [[ $(curl --max-time 10 -sS https://chat.openai.com/ -I 2>&1 | grep "text/plain") != "" ]]
	then
        echo -e " ChatGPT              : ${RED}IP 被屏蔽${PLAIN}" | tee -a $log
        return
	fi
    local countryCode="$(curl --max-time 10 -sS https://chat.openai.com/cdn-cgi/trace 2>&1 | grep "loc=" | awk -F= '{print $2}')";
	if [ $? -eq 1 ]; then
        echo -e " ChatGPT              : ${RED}网络连接失败${PLAIN}" | tee -a $log
        return
    fi
	if [ -n "$countryCode" ] && [ "$countryCode" != *curl* ]; then
        support_countryCodes=(T1 XX AL DZ AD AO AG AR AM AU AT AZ BS BD BB BE BZ BJ BT BA BW BR BG BF CV CA CL CO KM CR HR CY DK DJ DM DO EC SV EE FJ FI FR GA GM GE DE GH GR GD GT GN GW GY HT HN HU IS IN ID IQ IE IL IT JM JP JO KZ KE KI KW KG LV LB LS LR LI LT LU MG MW MY MV ML MT MH MR MU MX MC MN ME MA MZ MM NA NR NP NL NZ NI NE NG MK NO OM PK PW PA PG PE PH PL PT QA RO RW KN LC VC WS SM ST SN RS SC SL SG SK SI SB ZA ES LK SR SE CH TH TG TO TT TN TR TV UG AE US UY VU ZM BO BN CG CZ VA FM MD PS KR TW TZ TL GB)
		if [[ "${support_countryCodes[@]}"  =~ "${countryCode}" ]];  then
            echo -e " ChatGPT              : ${GREEN}是 (地区: ${countryCode})${PLAIN}" | tee -a $log
            return
        else
			echo -e " ChatGPT              : ${RED}否${PLAIN}" | tee -a $log
            return
        fi
    else
        echo -e " ChatGPT              : ${RED}失败${PLAIN}" | tee -a $log
        return
    fi
}

function StreamingMediaUnlockTest(){
	echo -e " 解锁测试             :" | tee -a $log
	UnlockNetflixTest
	UnlockYouTubePremiumTest
	YouTubeCDNTest
	UnlockBilibiliTest
	UnlockTiktokTest
	UnlockiQiyiIntlTest
	UnlockChatGPTTest
}

print_intro() {
	printf ' SBRE -- By：Anki = 最爱你咯\n' | tee -a $log
	printf " 模式  : \e${GREEN}%s\e${PLAIN}    版本 : \e${GREEN}%s${PLAIN}\n" $mode_name 1.3.13-Anki | tee -a $log
	printf ' 用法 : bash <(wget -qO- https://cdn.jsdelivr.net/gh/AnkiLove/SBRE@main/SBRE.sh)\n' | tee -a $log
}

function get_json_value() {
	local json=$1
	local key=$2

	if [[ -z "$3" ]]; then
		local num=1
	else
		local num=$3
	fi

	local value=$(echo "${json}" | awk -F"[,:}]" '{for(i=1;i<=NF;i++){if($i~/'${key}'\042/){print $(i+1)}}}' | tr -d '"' | sed -n ${num}p)

	echo ${value}
}

sharetest() {
	if [[ -n "$GEEKBENCH_URL" ]] || [[ -n "$result_speed" ]]; then
		echo " 分享结果:" | tee -a $log
	else
		echo " 分享结果:"
	fi
	if [[ -n "$GEEKBENCH_URL" ]]; then
		echo " · $GEEKBENCH_URL" | tee -a $log
	fi
	if [[ -n "$result_speed" ]]; then
		echo " · $result_speed" | tee -a $log
	fi
	log_preupload
	case $1 in
	'ubuntu')
		share_link="https://paste.ubuntu.com"$( curl -v --data-urlencode "content@$log_up" -d "poster=anki.com" -d "syntax=text" "https://paste.ubuntu.com" 2>&1 | \
			grep "Location" | awk '{print $3}' );;
	'haste' )
		share_link=$( curl -X POST -s -d "$(cat $log)" https://hastebin.com/documents | awk -F '"' '{print "https://hastebin.com/"$4}' );;
	'clbin' )
		share_link=$( curl -sF 'clbin=<-' https://clbin.com < $log );;
	'ptpb' )
		share_link=$( curl -sF c=@- https://ptpb.pw/?u=1 < $log );;
	'debian' )
		share_link="https://paste.debian.net/"$( curl -v --data-urlencode "code@$log_up" -d "poster=anki" -d "expire=-1" -d "lang=-1" "https://paste.debian.net/" 2>&1 | \
			grep Location | awk '{print $3}');;
	esac

	echo " · $share_link" | tee -a $log
	next
	echo ""
	rm -f $log_up

}

log_preupload() {
	log_up="$HOME/superbench_upload.log"
	true > $log_up
	$(cat superbench.log 2>&1 | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" > $log_up)
}

cleanup() {
	rm -f test_file_*
	rm -rf speedtest*
	rm -rf besttrace4*
	rm -rf geekbench*
	rm -rf ./worsttrace
	rm -rf ./nexttrace
}

bench_all(){
	mode_name="标准模式"
	about;
	benchinit;
	clear
	next;
	print_intro;
	next;
	get_system_info;
	print_system_info;
	ip_info4;
	next;
	StreamingMediaUnlockTest;
	next;
	print_io;
	if [[ "$GeekbenchTest" == "Y" ]]; then
		next;
		geekbench;
	fi
	next;
	print_china_speedtest;
	next;
	print_global_speedtest;
	next;
	print_traceroute_test;
	next;
	print_end_time;
	next;
	cleanup;
	sharetest debian;
}

fast_bench(){
	mode_name="快速模式"
	about;
	benchinit;
	clear
	next;
	print_intro;
	next;
	get_system_info;
	print_system_info;
	ip_info4;
	next;
	StreamingMediaUnlockTest;
	next;
	print_io fast;
	next;
	print_speedtest_fast;
	next;
	print_end_time;
	next;
	cleanup;
}

log="./superbench.log"
true > $log
speedLog="./speedtest.log"
true > $speedLog

case $1 in
	'info'|'-i'|'--i'|'-info'|'--info' )
		GeekbenchTest='N';
		about;sleep 3;next;get_system_info;print_system_info;next;;
    'version'|'-v'|'--v'|'-version'|'--version')
		GeekbenchTest='N';
		next;about;next;;
   	'io'|'-io'|'--io'|'-drivespeed'|'--drivespeed' )
		next;print_io;next;;
	'speed'|'-speed'|'--speed'|'-speedtest'|'--speedtest'|'-speedcheck'|'--speedcheck' )
		GeekbenchTest='N';
		about;benchinit;clear;next;print_china_speedtest;next;cleanup;;
	'ip'|'-ip'|'--ip'|'geoip'|'-geoip'|'--geoip' )
		about;benchinit;next;ip_info4;next;cleanup;;
	'bench'|'-a'|'--a'|'-all'|'--all'|'-bench'|'--bench' )
		bench_all;;
	'besttrace'|'-b'|'--b'|'--besttrace' )
		GeekbenchTest='N';
		about;benchinit;clear;print_traceroute_test;next;cleanup;;
	'about'|'-about'|'--about' )
		GeekbenchTest='N';
		about;;
	'fast'|'-f'|'--f'|'-fast'|'--fast' )
		fast_bench;;
	'geekbench'|'-g'|'--geekbench' )
		GeekbenchVer=6;
		about;benchinit;clear;geekbench;next;cleanup;;
	'--no-geekbench' )
		GeekbenchTest='N';
		bench_all;;
	'media'|'-m'|'--media' )
		GeekbenchTest='N';
		mode_name="MediaTest";
		start=$(date +%s)
		about;sleep 3;clear;next;print_intro;next;ip_info4;next;
		StreamingMediaUnlockTest;next;
		print_end_time;
		next;
		sharetest debian;;
	'share'|'-s'|'--s'|'-share'|'--share' )
		bench_all;
		is_share="share"
		if [[ $2 == "" ]]; then
			sharetest debian;
		else
			sharetest $2;
		fi
		;;
	'debug'|'-d'|'--d'|'-debug'|'--debug' )
		get_ip_whois_org_name;;
*)
    bench_all;;
esac

if [[  ! $is_share == "share" ]]; then
	case $2 in
		'share'|'-s'|'--s'|'-share'|'--share' )
			if [[ $3 == '' ]]; then
				sharetest debian;
			else
				sharetest $3;
			fi
			;;
	esac
fi
