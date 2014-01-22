#!/bin/bash
# bash library
# some useful bash script functions:
#   ssh
#   IPv4 address handle
#   install functions for RedHat/CentOS/Ubuntu/Arch
#
# Copyright 2013 Yunhui Fu
# License: GPL v3.0 or later

EXEC_SSH="$(which ssh) -oBatchMode=yes -CX"
EXEC_SCP="$(which scp)"
EXEC_AWK="$(which awk)"
EXEC_SED="$(which sed)"

#####################################################################
# System distribution detection
EXEC_APTGET="sudo $(which apt-get)"

OSTYPE=unknown
OSDIST=unknown
OSVERSION=unknown
OSNAME=unknown

detect_os_type () {
    test -e /etc/debian_version && OSDIST="Debian" && OSTYPE="Debian"
    grep Ubuntu /etc/lsb-release &> /dev/null && OSDIST="Ubuntu" && OSTYPE="Debian"
    test -e /etc/redhat-release && OSTYPE="RedHat"
    test -e /etc/fedora-release && OSTYPE="RedHat"
    test -e $(which pacman) && OSTYPE="Arch"

    OSDIST=
    OSVERSION=
    OSNAME=

    case "$OSTYPE" in
    Debian)
        if ! which lsb_release &> /dev/null; then
            $EXEC_APTGET install -y lsb-release
        fi
        ;;

    RedHat)
        EXEC_APTGET="sudo `which yum`"
        #yum whatprovides */lsb_release
        if ! which lsb_release &> /dev/null; then
            $EXEC_APTGET --skip-broken install -y redhat-lsb-core
        fi
        ;;

    Arch)
        if [ -f "/etc/os-release" ]; then
            OSDIST=$(cat /etc/os-release | grep ^ID= | awk -F= '{print $2}')
            OSVERSION=1
            OSNAME=arch
        fi
        ;;
    *)
        echo "[ERR] Not supported OS: $OSTYPE"
        exit 0
        ;;
    esac

    if which lsb_release &> /dev/null; then
        OSDIST=`lsb_release -is`
        OSVERSION=`lsb_release -rs`
        OSNAME=`lsb_release -cs`
    fi
    if [ "${OSDIST}" = "" ]; then
        echo "Error: Not found lsb_release!"
    fi
    echo "[INFO] Detected $OSTYPE system: $OSDIST $OSVERSION $OSNAME"
    export OSTYPE
    export OSDIST
    export OSVERSION
    export OSNAME
}

hput () {
  KEY=`echo "$1" | tr '[:punct:][:blank:]' '_'`
  eval export hash"$KEY"='$2'
}

hget () {
  KEY=`echo "$1" | tr '[:punct:][:blank:]' '_'`
  eval echo '${hash'"$KEY"'#hash}'
}

hiter() { 
    for h in $(eval echo '${!'$1'*}') ; do
        key=${h#$1*}
        echo "$key=`hget $key`"
    done
}

ospkgset() {
    PARAM_KEY=$1
    shift
    PARAM_REDHAT=$1
    shift
    PARAM_ARCH=$1
    shift
    hput "pkg_RedHat_$PARAM_KEY" "$PARAM_REDHAT"
    hput "pkg_Arch_$PARAM_KEY" "$PARAM_ARCH"
}

ospkgget () {
    PARAM_OS=$1
    shift
    PARAM_KEY=$1
    shift
    if [ "$PARAM_OS" = "Debian" ]; then
        echo "${PARAM_KEY}"
        return
    fi
    hget "pkg_${PARAM_OS}_${PARAM_KEY}"
}

# Debian/Ubuntu, RedHat/Fedora/CentOS, Arch
ospkgset apt-get            yum                 pacman
ospkgset build-essential    build-essential     base-devel
ospkgset lsb-release        redhat-lsb-core     redhat-lsb-core
ospkgset openssh-client     openssh-clients     openssh-clients
ospkgset parted             parted              parted
ospkgset subversion         svn                 svn
ospkgset git-all            git                 git
ospkgset dhcp3-server       dhcp                dhcp
ospkgset dhcp3-client       dhcp                dhcpcd
ospkgset tftpd-hpa          tftp-server         tftp-hpa
ospkgset syslinux           syslinux            syslinux
ospkgset nfs-kernel-server  nfs-utils           nfs-utils
ospkgset nfs-common         nfs-utils           nfs-utils
ospkgset bind9              bind                bind
ospkgset portmap            portmap             ""

patch_centos_gawk () {
    yum -y install rpmdevtools readline-devel #libsigsegv-devel
    yum -y install gcc byacc
    rpmdev-setuptree

    #FILELIST="gawk.spec gawk-3.1.8.tar.bz2 gawk-3.1.8-double-free-wstptr.patch gawk-3.1.8-syntax.patch"
    #URL="http://archive.fedoraproject.org/pub/archive/fedora/linux/updates/14/SRPMS/gawk-3.1.8-3.fc14.src.rpm"
    FILELIST="gawk.spec gawk-4.0.1.tar.gz"
    URL="http://archive.fedoraproject.org/pub/archive/fedora/linux/updates/17/SRPMS/gawk-4.0.1-1.fc17.src.rpm"
    cd ~/rpmbuild/SOURCES/; rm -f ${FILELIST}; cd - ; rm -f ${FILELIST}
    wget -c "${URL}" -O ~/rpmbuild/SRPMS/$(basename "${URL}")
    rpm2cpio ~/rpmbuild/SRPMS/$(basename "${URL}") | cpio -div
    mv ${FILELIST} ~/rpmbuild/SOURCES/
    sed -i 's@configure @configure --enable-switch --disable-libsigsegv @g' ~/rpmbuild/SOURCES/$(echo "${FILELIST}" | awk '{print $1}')
    sed -i 's@--with-libsigsegv-prefix=[^ ]*@@g' ~/rpmbuild/SOURCES/$(echo "${FILELIST}" | awk '{print $1}')
    sed -i 's@Conflicts: filesystem@#Conflicts: filesystem@g' ~/rpmbuild/SOURCES/$(echo "${FILELIST}" | awk '{print $1}')
    rpmbuild -bb --clean ~/rpmbuild/SOURCES/$(echo "${FILELIST}" | awk '{print $1}')
    sudo rpm -U --force ~/rpmbuild/RPMS/$(uname -i)/gawk-4.0.1-1.el6.$(uname -i).rpm
    ln -s $(which gawk) /bin/gawk
    ln -s $(which gawk) /bin/awk
}

install_package () {
    PARAM_NAME=$*
    INSTALLER=`ospkgget $OSTYPE apt-get`
    PKGLST=
    FLG_GAWK_RH=0
    for i in $PARAM_NAME ; do
        PKG=$(ospkgget $OSTYPE $i)
        if [ "${PKG}" = "" ]; then
            PKG="$i"
        fi
        echo "try to install package: $PKG($i)"
        if [ "$i" = "gawk" ]; then
            if [ "$OSTYPE" = "RedHat" ]; then
                echo "[DBG] patch gawk to support 'switch'"
                echo | gawk '{a = 1; switch(a) { case 0: break; } }'
                if [ $? = 1 ]; then
                    FLG_GAWK_RH=1
                    PKG="rpmdevtools libsigsegv-devel readline-devel"
                fi
            fi
        fi

        echo "[DBG] OSTYPE = $OSTYPE"
        if [ "$OSTYPE" = "Arch" ]; then
            if [ "$i" = "portmap" ]; then
                echo "[DBG] Ignore $i"
                PKG=""
            fi
            if [ "$i" = "syslinux" ]; then
                MACH=$(uname -m)
                case "$MACH" in
                x86_64|i386|i686)
                    echo "[DBG] use standard method"
                    ;;

                *)
                    echo "[DBG] Arch $MACH yet another installation of $i"
                    PKG=""
                    echo "[DBG] Download package for $MACH"
                    cd /tmp
                    DATE1=$(date +%Y-%m-%d)
                    rm -f index.html*
                    URL_ORIG="https://www.archlinux.org/packages/core/i686/syslinux/download/"
                    URL_REAL=$(wget --no-check-certificate ${URL_ORIG} 2>&1 | grep pkg | grep $DATE1 | awk '{print $3}')
                    FN_SYSLI=$(basename ${URL_REAL})
                    if [ ! -f "${FN_SYSLI}" ]; then
                        if [ ! -f index.html ]; then
                            echo "[ERR] not found downloaded file from ${URL_ORIG}(${URL_REAL})"
                        else
                            echo "[DBG] rename index.html to ${FN_SYSLI}"
                            mv index.html "${FN_SYSLI}"
                        fi
                    fi
                    if [ ! -f "${FN_SYSLI}" ]; then
                        echo "[ERR] not found file ${FN_SYSLI}"
                        exit 0
                    fi
                    tar -xf "${FN_SYSLI}"
                    cd -
                    ;;
                esac
            fi
        fi
        PKGLST="${PKGLST} ${PKG}"
    done

    INST_OPTS=""
    case "$OSTYPE" in
    Debian)
        INST_OPTS="install -y"
        ;;

    RedHat)
        INST_OPTS="install -y"
        ;;

    Arch)
        INST_OPTS="-S"
        # install loop module
        lsmod | grep loop
        if [ "$?" != "0" ]; then
            modprobe loop

            grep -Hrn loop /etc/modules-load.d/
            if [ "$?" != "0" ]; then
                echo "loop" > /etc/modules-load.d/tftpboot.conf
            fi
        fi
        ;;
    *)
        echo "[ERR] Not supported OS: $OSTYPE"
        exit 0
        ;;
    esac

    sudo $INSTALLER ${INST_OPTS} ${PKGLST}
    if [ "${FLG_GAWK_RH}" = "1" ]; then
        patch_centos_gawk
    fi
}

detect_os_type

#for h in ${!hash*}; do indirect=$hash$h; echo ${!indirect}; done
#hiter hash
#install_package apt-get subversion
#exit 0

######################################################################
EXEC_SSH="$(which ssh)"
if [ ! -x "${EXEC_SSH}" ]; then
  echo "[DBG] Try to install ssh." >> "/dev/stderr"
  install_package openssh-client
fi

EXEC_SSH="$(which ssh)"
if [ ! -x "${EXEC_SSH}" ]; then
  echo "[ERR] Not exist ssh!" >> "/dev/stderr"
  exit 1
fi
EXEC_SSH="$(which ssh) -oBatchMode=yes -CX"

EXEC_AWK="$(which gawk)"
if [ ! -x "${EXEC_AWK}" ]; then
  echo "[DBG] Try to install gawk." >> "/dev/stderr"
  install_package gawk
fi

EXEC_AWK="$(which gawk)"
if [ ! -x "${EXEC_AWK}" ]; then
  echo "[ERR] Not exist awk!" >> "/dev/stderr"
  exit 1
fi

#DN_EXEC=`echo "$0" | ${EXEC_AWK} -F/ '{b=$1; for (i=2; i < NF; i ++) {b=b "/" $(i)}; print b}'`
DN_EXEC="$(dirname "$0")"
if [ ! "${DN_EXEC}" = "" ]; then
    DN_EXEC="${DN_EXEC}/"
else
    DN_EXEC="./"
fi

############################################################
# ssh
# generate the cert of localhost
if [ ! -f ~/.ssh/id_rsa.pub ]; then
    echo "generate id ..."
    mkdir -p ~/.ssh/
    ssh-keygen
fi

# ensure the success of the connection
# 确保本地 id_rsa.pub 复制到远程机器
ssh_ensure_connection () {
    PARAM_SSHURL="${1}"
    echo "[DBG] test host: ${PARAM_SSHURL}"
    $EXEC_SSH "${PARAM_SSHURL}" "ls > /dev/null"
    if [ ! "$?" = "0" ]; then
        echo "[DBG] copy id to ${PARAM_SSHURL} ..."
        ssh-copy-id -i ~/.ssh/id_rsa.pub "${PARAM_SSHURL}"
    else
        echo "[DBG] pass id : ${PARAM_SSHURL}."
    fi
    if [ "$?" = "0" ]; then
        $EXEC_SSH "${PARAM_SSHURL}" "yum -y install xauth libcanberra-gtk2 dejavu-lgc-sans-fonts"
    fi
}

############################################################
# Math Lib:

# 最大公约数 (Greatest Common Divisor, GCD)
# 最小公倍数 (Least Common Multiple, LCM)
# example:
# gdc 6 15
# 30
gcd () {
    PARAM_NUM1=$1
    shift
    PARAM_NUM2=$1
    shift

    NUM1=$PARAM_NUM1
    NUM2=$PARAM_NUM2
    if [ $(echo | awk -v A=$NUM1 -v B=$NUM2 '{ if (A<B) {print 1;} else {print 0;} }') = 1 ]; then
        NUM1=$PARAM_NUM2
        NUM2=$PARAM_NUM1
    fi

    a=$NUM1
    b=$NUM2
    while (( $b != 0 ));do
        tmp=$(($a % $b))
        a=$b
        b=$tmp
    done
    #echo "GDC=$a"
    #echo "LCM=$(($NUM1 * $NUM2 / $a))"
    echo $(($NUM1 * $NUM2 / $a))
}

############################################################
# IPv4 address Lib:
die() {
    echo "Error: $@" >&2
    exit 1
}

IPv4_check_ok () {
    local IFS=.
    set -- $1
    [ $# -eq 4 ] || return 2
    local var
    for var in $* ;do
        [ $var -lt 0 ] || [ $var -gt 255 ] && return 3
    done
    echo $(( ($1<<24) + ($2<<16) + ($3<<8) + $4))
}

IPv4_from_int () {
    echo $(($1>>24)).$(($1>>16&255)).$(($1>>8&255)).$(($1&255))
}

# convert the string to IPv4 configurations
# Example:
#   IPv4_convert "192.168.1.15/17"
#echo "netIP=$OUTPUT_IPV4_IP"
#echo "netMASK=$OUTPUT_IPV4_MASK"
#echo "netBCST=$OUTPUT_IPV4_BROADCAST"
#echo "network=$OUTPUT_IPV4_NETWORK"
#echo "first ip=${OUTPUT_IPV4_FIRSTIP}"
#echo "DHCP_UNKNOW=${OUTPUT_IPV4_DHCP_UNKNOW_RANGE}"
#echo "DHCP_KNOW=${OUTPUT_IPV4_DHCP_KNOW_RANGE}"
IPv4_convert () {
    PARAM_IP="$1"
    shift

    netIP=$(echo $PARAM_IP | awk -F/ '{print $1}')
    intIP=$(IPv4_check_ok $netIP) || die "Submited IP: '$netIP' is not an IPv4 address."

    LEN=$(echo $PARAM_IP | awk -F/ '{print $2}')
    intMASK0=$((  ( (1<<$LEN) - 1 ) << ( 32 - $LEN )  ))
    #echo "intMASK0=$intMASK0"
    netMASK=$(  IPv4_from_int $intMASK0  )
    intMASK=$(IPv4_check_ok $netMASK) || die "Submited Mask: '$netMASK' not IPv4."
    if [ ! "$intMASK0" = "$intMASK" ]; then
        die "Mask convert error: 0-'$intMASK0'; 1-'$intMASK'"
    fi

    intBCST=$((  intIP | intMASK ^ ( (1<<32) - 1 )  ))
    intBASE=$((  intIP & intMASK  ))
    netBCST=$(  IPv4_from_int $((  intIP | intMASK ^ ( (1<<32) - 1 )  ))  )
    netBASE=$(  IPv4_from_int $((  intIP & intMASK  ))  )

    OUTPUT_IPV4_IP="$netIP"
    OUTPUT_IPV4_MASK="$netMASK"
    OUTPUT_IPV4_BROADCAST="$netBCST"
    OUTPUT_IPV4_NETWORK="$netBASE"
    OUTPUT_IPV4_FIRSTIP=$(  IPv4_from_int $((  intBASE + 1  ))  )

    RESERV_RATIO="4/5"
    #echo "LEN = $LEN"
    #echo "RESERV_RATIO = $RESERV_RATIO"
    SZ=$((  ( 1 << ( 32 - $LEN ) ) - 2  ))
    #echo "SZ-0 = $SZ"
    SZ2=$((  ( $SZ - $SZ * $RESERV_RATIO ) * 3 / 4  ))
    #echo "SZ2-0 = $SZ2"
    [ $SZ2 -lt 100 ] || SZ2=100
    #echo "SZ2-1 = $SZ2"
    [ $SZ2 -gt 0 ] || SZ2=1
    #echo "SZ2-2 = $SZ2"
    SZ1=$((  ( $SZ - $SZ * $RESERV_RATIO ) - $SZ2  ))
    #echo "SZ1-0 = $SZ1"
    [ $SZ1 -lt 10 ] || SZ1=10
    #echo "SZ1-1 = $SZ1"
    [ $SZ1 -gt 0 ] || SZ1=1
    #echo "SZ1-2 = $SZ1"
    SZLEFT=$((  $SZ - $SZ1 - $SZ2  ))
    #echo "SZLEFT-0 = $SZLEFT"
    [ $SZLEFT -gt 0 ] || SZLEFT=$((  ( $SZ / 3 + $SZ ) * $RESERV_RATIO  ))
    #echo "SZLEFT-1 = $SZLEFT"
    [ $SZLEFT -gt 0 ] || SZLEFT=1
    #echo "SZLEFT-2 = $SZLEFT"
    SZ1=$((  ( $SZ - $SZLEFT ) / 2  ))
    [ $SZ1 -lt 10 ] || SZ1=10
    [ $SZ1 -gt 0 ] || SZ1=0
    SZ2=$((  $SZ - $SZLEFT - $SZ1  ))
    [ $SZ2 -lt 100 ] || SZ2=100
    [ $SZ2 -gt 0 ] || SZ2=0
    SZLEFT=$((  $SZ - $SZ1 - $SZ2  ))
    #echo SZ1=$SZ1
    #echo SZ2=$SZ2
    #echo SZLEFT=$SZLEFT

    MID=$((  $intBCST - $SZ2 - 1 ))
    [ $MID -lt $intBCST ] || MID=$((  $intBCST - 1  ))

    #OUTPUT_IPV4_DHCP_ROUTER=
    #  IP unknown range
    OUTPUT_IPV4_DHCP_UNKNOW_RANGE="$(  IPv4_from_int $(( $MID + 1 )) )    $(  IPv4_from_int $((  $intBCST - 1  ))  )"
    #  IP known range
    OUTPUT_IPV4_DHCP_KNOW_RANGE="$(  IPv4_from_int $((  $intBASE + 1 + $SZ1  ))  )    $(  IPv4_from_int $((  $MID  ))  )"
}

############################################################
# http://blog.n01se.net/blog-n01se-net-p-145.html
# redirect tty fds to /dev/null
redirect-std() {
    [[ -t 0 ]] && exec </dev/null
    [[ -t 1 ]] && exec >/dev/null
    [[ -t 2 ]] && exec 2>/dev/null
}

# close all non-std* fds
close-fds() {
    eval exec {3..255}\>\&-
}

# full daemonization of external command with setsid
daemonize() {
    (                   # 1. fork
        redirect-std    # 2.1. redirect stdin/stdout/stderr before setsid
        cd /            # 3. ensure cwd isn't a mounted fs
        # umask 0       # 4. umask (leave this to caller)
        close-fds       # 5. close unneeded fds
        exec setsid "$@"
    ) &
}

# daemonize without setsid, keeps the child in the jobs table
daemonize-job() {
    (                   # 1. fork
        redirect-std    # 2.2.1. redirect stdin/stdout/stderr
        trap '' 1 2     # 2.2.2. guard against HUP and INT (in child)
        cd /            # 3. ensure cwd isn't a mounted fs
        # umask 0       # 4. umask (leave this to caller)
        close-fds       # 5. close unneeded fds
        if [[ $(type -t "$1") != file ]]; then
            "$@"
        else
            exec "$@"
        fi
    ) &
    disown -h $!       # 2.2.3. guard against HUP (in parent)
}

############################################################
