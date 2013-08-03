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

    *)
        echo "Error: Not supported OS: $OSTYPE"
        exit 0
        ;;
    esac

    if which lsb_release &> /dev/null; then
        OSDIST=`lsb_release -is`
        OSVERSION=`lsb_release -rs`
        OSNAME=`lsb_release -cs`
    else
        echo "Error: Not found lsb_release!"
    fi
    echo "Detected $OSTYPE system: $OSDIST $OSVERSION $OSNAME"
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
ospkgset apt-get            yum                pacman
ospkgset build-essential    build-essential    base-devel
ospkgset lsb-release        redhat-lsb-core    redhat-lsb-core
ospkgset coreutils          coreutils          coreutils
ospkgset gawk               gawk               gawk
ospkgset gnuplot            gnuplot            gnuplot
ospkgset openssh-client     openssh-clients    openssh-clients
ospkgset parted             parted             parted
ospkgset xfsprogs           xfsprogs           xfsprogs
ospkgset perl               perl               perl
ospkgset dnsmasq            dnsmasq            dnsmasq
ospkgset p7zip              p7zip              p7zip
ospkgset nfs-common         nfs-common         nfs-common
ospkgset nfs-kernel-server  nfs-kernel-server  nfs-kernel-server
ospkgset portmap            portmap            portmap
ospkgset subversion         svn                svn
ospkgset git-all            git                git
ospkgset tcpdump            tcpdump            tcpdump
ospkgset tcptrace           tcptrace           tcptrace
ospkgset octave             octave             octave

install_package () {
    PARAM_NAME=$*
    INSTALLER=`ospkgget $OSTYPE apt-get`
    PKGLST=
    for i in $PARAM_NAME ; do
        PKG=`ospkgget $OSTYPE $i`
        echo "try to install package: $PKG($i)"
        PKGLST="${PKGLST} ${PKG}"
    done
    sudo $INSTALLER install -y ${PKGLST}
}

detect_os_type

#for h in ${!hash*}; do indirect=$hash$h; echo ${!indirect}; done
#hiter hash
#install_package apt-get subversion
#exit 0

######################################################################
EXEC_SSH="$(which ssh)"
if [ ! -x "${EXEC_SSH}" ]; then
  echo "Try to install ssh." >> "/dev/stderr"
  install_package openssh-client
fi

EXEC_SSH="$(which ssh)"
if [ ! -x "${EXEC_SSH}" ]; then
  echo "Error: Not exist ssh!" >> "/dev/stderr"
  exit 1
fi
EXEC_SSH="$(which ssh) -oBatchMode=yes -CX"

EXEC_AWK="$(which gawk)"
if [ ! -x "${EXEC_AWK}" ]; then
  echo "Try to install gawk." >> "/dev/stderr"
  install_package gawk
fi

EXEC_AWK="$(which gawk)"
if [ ! -x "${EXEC_AWK}" ]; then
  echo "Error: Not exist awk!" >> "/dev/stderr"
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
    echo "test host: ${PARAM_SSHURL}"
    $EXEC_SSH "${PARAM_SSHURL}" "ls > /dev/null"
    if [ ! "$?" = "0" ]; then
        echo "copy id to ${PARAM_SSHURL} ..."
        ssh-copy-id -i ~/.ssh/id_rsa.pub "${PARAM_SSHURL}"
    else
        echo "pass id : ${PARAM_SSHURL}."
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
