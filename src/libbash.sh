#!/bin/bash
# bash library
# some useful bash script functions:
#   ssh
#   IPv4 address handle
#   install functions for RedHat/CentOS/Ubuntu/Arch
#
# Copyright 2013 Yunhui Fu
# License: GPL v3.0 or later
#####################################################################
#DN_EXEC=`echo "$0" | ${EXEC_AWK} -F/ '{b=$1; for (i=2; i < NF; i ++) {b=b "/" $(i)}; print b}'`
DN_EXEC="$(dirname "$0")"
if [ ! "${DN_EXEC}" = "" ]; then
    DN_EXEC="${DN_EXEC}/"
else
    DN_EXEC="./"
fi

# detect if the ~/bin is included in environment variable $PATH
echo $PATH | grep "~/bin"
if [ ! "$?" = "0" ]; then
    echo 'PATH=~/bin/:$PATH' >> ~/.bashrc
    export PATH=~/bin:$PATH
fi

#####################################################################
# the format of the segment file name, it seems 19 is the max value for gawk.
PRIuSZ="%019d"

#####################################################################
# becareful the danger execution, such as rm -rf ...
# use DANGER_EXEC=echo to skip all of such executions.
DANGER_EXEC=echo

FN_STDERR="/dev/stderr"
OUT_ERR=">> ${FN_STDERR}"
if [ ! -f "$FN_STDERR" ]; then
    OUT_ERR=""
    FN_STDERR="/dev/null"
fi

FN_LOG0=mrtrace.log
mr_trace () {
    echo "$(date +"%Y-%m-%d %H:%M:%S,%N" | cut -c1-23) [self=${BASHPID},$(basename $0)] $@" | tee -a ${FN_LOG0} 1>&2
}

fatal_error () {
  PARAM_MSG="$1"
  mr_trace "Fatal error: ${PARAM_MSG}" 1>&2
  #exit 1
}

mr_exec_do () {
    mr_trace "$@"
    $@
}

mr_exec_skip () {
    mr_trace "DEBUG (skip) $@"
}

myexec_ignore () {
    mr_trace "[DBG] (skip) $*"
    A=
    while [ ! "$1" = "" ]; do
        A="$A \"$1\""
        shift
    done
    #mr_trace "[DBG] (skip) $A"
}
myexec_trace () {
    mr_trace "[DBG] $*"
    A=
    while [ ! "$1" = "" ]; do
        A="$A \"$1\""
        shift
    done
    #mr_trace "[DBG] $A"
    eval $A
}

DO_EXEC=mr_exec_do
#DO_EXEC=
if [ "$FLG_SIMULATE" = "1" ]; then
    DO_EXEC=mr_exec_skip
fi


#####################################################################
extract_file () {
  ARG_FN=$1
  shift

  mr_trace "[DBG] Extract compressed file: '${ARG_FN}'"

  if [ -f "${ARG_FN}" ]; then
    DN_CUR=`pwd`
    DN_DIC=`echo "${ARG_FN}" | awk -F/ '{if (NF <= 1) name=""; else name=$1; for (i=2; i < NF; i ++) name=name "/" $i } END {print name}'`
    FN_CUR=`echo "${ARG_FN}" | awk -F/ '{name=$NF; } END {print name}'`
    FN_BASE=`echo "${FN_CUR}" | awk -F. '{name=$1; for (i=2; i < NF; i ++) name=name "." $i } END {print name}'`
    if [ "${DN_DIC}" = "" ]; then
        DN_DIC="${DN_CUR}"
    fi

    mr_trace "DN_CUR=$DN_CUR; DN_DIC=$DN_DIC; FN_CUR=$FN_CUR; FN_BASE=$FN_BASE"; #exit 0

    case "${FN_CUR}" in
    *.tar.Z)
      echo "extract (tar) ${DN_DIC}/${FN_CUR} ..."
      cd "${DN_DIC}"
      #compress -dc file.tar.Z | tar xvf -
      tar -xvZf "${FN_CUR}"
      cd "${DN_CUR}"
      ;;
    *.tar.gz)
      echo "extract (tar) ${DN_DIC}/${FN_CUR} ..."
      cd "${DN_DIC}"
      tar -xzf "${FN_CUR}"
      cd "${DN_CUR}"
      ;;
    *.tar.bz2)
      echo "extract (tar) ${DN_DIC}/${FN_CUR} ..."
      cd "${DN_DIC}"
      tar -xjf "${FN_CUR}"
      cd "${DN_CUR}"
      ;;
    *.tar.xz)
      echo "extract (tar) ${DN_DIC}/${FN_CUR} ..."
      cd "${DN_DIC}"
      xzcat "${FN_CUR}" | tar -x
      cd "${DN_CUR}"
      ;;
    *.cpio.gz)
      echo "extract (cpio) ${DN_DIC}/${FN_CUR} ..."
      cd "${DN_DIC}"
      gzip -dc "${FN_CUR}" | cpio -div
      cd "${DN_CUR}"
      ;;
    *.gz)
      echo "extract (gunzip) ${DN_DIC}/${FN_CUR} ..."
      cd "${DN_DIC}"
      gunzip -d -c "${FN_CUR}" > "${FN_BASE}.tmptmp"
      mv "${FN_BASE}.tmptmp" "${FN_BASE}"
      cd "${DN_CUR}"
      ;;
    *.bz2)
      echo "extract (bunzip2) ${DN_DIC}/${FN_CUR} ..."
      cd "${DN_DIC}"
      bunzip2 -d -c "${FN_CUR}" > "${FN_BASE}.tmptmp"
      mv "${FN_BASE}.tmptmp" "${FN_BASE}"
      cd "${DN_CUR}"
      ;;
    *.rpm)
      echo "extract (rpm) ${DN_DIC}/${FN_CUR} ..."
      cd "${DN_DIC}"
      rpm2cpio "${FN_CUR}" | cpio -div
      cd "${DN_CUR}"
      ;;
    *.rar)
      echo "extract (unrar) ${DN_DIC}/${FN_CUR} ..."
      cd "${DN_DIC}"
      unrar x "${FN_CUR}"
      cd "${DN_CUR}"
      ;;
    *.zip)
      echo "extract (unzip) ${DN_DIC}/${FN_CUR} ..."
      cd "${DN_DIC}"
      unzip "${FN_CUR}"
      cd "${DN_CUR}"
      ;;
    *.deb)
      # ar xv "${FN_CUR}" && tar -xf data.tar.gz
      echo "extract (dpkg) ${DN_DIC}/${FN_CUR} ..."
      cd "${DN_DIC}"
      dpkg -x "${FN_CUR}" .
      cd "${DN_CUR}"
      ;;
    *.dz)
      echo "extract (dictzip) ${DN_DIC}/${FN_CUR} ..."
      cd "${DN_DIC}"
      dictzip -d -c "${FN_CUR}" > "${FN_BASE}.tmptmp"
      mv "${FN_BASE}.tmptmp" "${FN_BASE}"
      cd "${DN_CUR}"
      ;;
    *.Z)
      echo "extract (uncompress) ${DN_DIC}/${FN_CUR} ..."
      cd "${DN_DIC}"
      gunzip -d -c "${FN_CUR}" > "${FN_BASE}.tmptmp"
      mv "${FN_BASE}.tmptmp" "${FN_BASE}"
      cd "${DN_CUR}"
      ;;
    *.a)
      echo "extract (tar) ${DN_DIC}/${FN_CUR} ..."
      cd "${DN_DIC}"
      tar -xv "${FN_BASE}"
      cd "${DN_CUR}"
      ;;
    *.tgz)
      echo "extract (tar) ${DN_DIC}/${FN_CUR} ..."
      cd "${DN_DIC}"
      tar -xzf "${FN_CUR}"
      cd "${DN_CUR}"
      ;;
    *.tbz)
      echo "extract (tar) ${DN_DIC}/${FN_CUR} ..."
      cd "${DN_DIC}"
      tar -xjf "${FN_CUR}"
      cd "${DN_CUR}"
      ;;
    *.cgz)
      echo "extract (cpio) ${DN_DIC}/${FN_CUR} ..."
      cd "${DN_DIC}"
      gzip -dc "${FN_CUR}" | cpio -div
      cd "${DN_CUR}"
      ;;
    *.cpio)
      echo "extract (cpio) ${DN_DIC}/${FN_CUR} ..."
      cd "${DN_DIC}"
      cpio -div "${FN_CUR}"
      cd "${DN_CUR}"
      ;;
    *)
      #echo "skip ${DN_DIC}/${FN_CUR} ..."
      ;;
    esac
  else
    echo "Not found file: ${DN_DIC}/${FN_CUR}"
    return 1
  fi
  return 0;
}

#####################################################################
EXEC_SSH="$(which ssh) -oBatchMode=yes -CX"
EXEC_SCP="$(which scp)"
EXEC_AWK="$(which awk)"
EXEC_SED="$(which sed)"

#####################################################################
# System distribution detection
EXEC_APTGET="${EXEC_SUDO} $(which apt-get)"

OSTYPE=unknown
OSDIST=unknown
OSVERSION=unknown
OSNAME=unknown

detect_os_type () {
    test -e /etc/debian_version && OSDIST="Debian" && OSTYPE="Debian"
    grep Ubuntu /etc/lsb-release &> /dev/null && OSDIST="Ubuntu" && OSTYPE="Debian"
    test -e /etc/redhat-release && OSTYPE="RedHat"
    test -e /etc/fedora-release && OSTYPE="RedHat"
    which pacman 2>&1 > /dev/null && OSTYPE="Arch"
    which opkg 2>&1 > /dev/null && OSTYPE="OpenWrt"

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
        EXEC_APTGET="${EXEC_SUDO} `which yum`"
        #yum whatprovides */lsb_release
        if ! which lsb_release &> /dev/null; then
            $EXEC_APTGET --skip-broken install -y redhat-lsb-core
        fi
        ;;

    Arch)
        EXEC_APTGET="`which pacman`"
        if [ -f "/etc/os-release" ]; then
            OSDIST=$(cat /etc/os-release | grep ^ID= | awk -F= '{print $2}')
            OSVERSION=1
            OSNAME=arch
        fi
        ;;

    OpenWrt)
        EXEC_APTGET="`which opkg`"
        if [ -f "/etc/os-release" ]; then
            OSDIST=$(cat /etc/os-release | grep ^ID= | awk -F= '{print $2}')
            OSVERSION=1
            #OSDIST=$(cat /etc/os-release | grep ^NAME= | awk -F= '{print $2}')
            OSDIST=
            if [ x${OSDIST} = x ]; then
                OSNAME=openwrt
            fi
        fi
        if [ ! -f "/tmp/opkg-lists/reboot_base" ]; then
            $DO_EXEC $EXEC_APTGET update
        fi
        ;;
    *)
        mr_trace "[ERR] Not supported OS: $OSTYPE"
        exit 0
        ;;
    esac

    if which lsb_release &> /dev/null; then
        OSDIST=$(lsb_release -is)
        OSVERSION=$(lsb_release -rs)
        OSNAME=$(lsb_release -cs)
    fi
    if [ "${OSDIST}" = "" ]; then
        mr_trace "Error: Not found lsb_release!"
    fi
    mr_trace "[INFO] Detected $OSTYPE system: $OSDIST $OSVERSION $OSNAME"
    export OSTYPE
    export OSDIST
    export OSVERSION
    export OSNAME
}

hput () {
  KEY=`echo "$1" | tr '[:punct:][:blank:]-' '_'`
  eval export hash"$KEY"='$2'
}

hget () {
  KEY=`echo "$1" | tr '[:punct:][:blank:]-' '_'`
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
    PARAM_OPENWRT=$1
    shift
    hput "pkg_RedHat_$PARAM_KEY" "$PARAM_REDHAT"
    hput "pkg_Arch_$PARAM_KEY" "$PARAM_ARCH"
    hput "pkg_OpenWrt_$PARAM_KEY" "$PARAM_OPENWRT"
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

# Debian/Ubuntu, RedHat/Fedora/CentOS, Arch, OpenWrt
ospkgset apt-get            yum                 pacman              opkg
ospkgset apt-file           yum                 pkgfile             opkg
ospkgset u-boot-tools       uboot-tools         uboot-tools         uboot-envtools
ospkgset mtd-utils          mtd-utils           mtd-utils           mtd-utils
ospkgset build-essential    build-essential     base-devel          ""
ospkgset lsb-release        redhat-lsb-core     redhat-lsb-core     ""
ospkgset openssh-client     openssh-clients     openssh-clients     openssh-client
ospkgset parted             parted              parted              parted
ospkgset subversion         svn                 svn                 subversion-client
ospkgset git-all            git                 git                 git
ospkgset dhcp3-server       dhcp                dhcp                dnsmasq
ospkgset dhcp3-client       dhcp                dhcpcd              dnsmasq
ospkgset tftpd-hpa          tftp-server         tftp-hpa            dnsmasq
ospkgset syslinux           syslinux            syslinux            syslinux
ospkgset nfs-kernel-server  nfs-utils           nfs-utils           nfs-kernel-server
ospkgset nfs-common         nfs-utils           nfs-utils           nfs-utils
ospkgset bind9              bind                bind                bind-server
ospkgset portmap            portmap             ""                  portmap
ospkgset libncurses-dev     libncurses-dev      ncurses             libncurses-dev

ospkgset apache2            httpd               apache              apache
#ospkgset apache2-mpm-prefork
#ospkgset apache2-utils
ospkgset libapache2-mod-php5 php-apache         php-apache          php7-fpm
ospkgset php5-common        php                 php-apache          php7
#ospkgset php5-cli           php                 php                 php7-cli
#ospkgset php5-mcrypt        ""                  ""                  php7-mod-mcrypt
#ospkgset php5-mysql         php-mysql           ""                  php7-mod-mysqli
#ospkgset php5-pgsql         ""                  ""                  
ospkgset php5-sqlite        php-sqlite          php-sqlite          php7-mod-sqlite3
#ospkgset php5-dev           ""                  ""                  ""
#ospkgset php5-curl          ""                  ""                  ""
#ospkgset php5-idn           ""                  ""                  ""
ospkgset php5-imagick       php-imagick         php-imagick         ""
#ospkgset php5-imap          ""                  ""                  ""
#ospkgset php5-memcache      ""                  ""                  ""
#ospkgset php5-ps            ""                  ""                  ""
#ospkgset php5-pspell        ""                  ""                  ""
#ospkgset php5-recode        ""                  ""                  ""
#ospkgset php5-tidy          ""                  ""                  ""
#ospkgset php5-xmlrpc        ""                  ""                  ""
#ospkgset php5-xsl           ""                  ""                  ""
#ospkgset php5-json          ""                  ""                  ""
#ospkgset php5-gd            php-gd              ""                  ""
#ospkgset php5-snmp          php-snmp            ""                  ""
#ospkgset php-versioncontrol-svn ""              ""                  ""
#ospkgset php-pear           php-pear            ""                  ""
ospkgset snmp               net-snmp-utils      net-snmp            snmpd
ospkgset graphviz           graphviz            graphviz            ""
ospkgset php5-mcrypt        php-mcrypt          php-mcrypt          php7-mod-mcrypt
ospkgset mysql-server       mysql-server        mariadb             mysql-server
ospkgset mysql-client       mysql               mariadb-clients     mysql-server
#ospkgset mysql-perl         ?                   perl-dbd-mysql
#ospkgset rrdtool            rrdtool             ""                  rrdtool1
#ospkgset fping              fping               fping               fping
ospkgset imagemagick        ImageMagick         imagemagick         ""
ospkgset whois              jwhois              whois               ""
ospkgset mtr-tiny           mtr                 mtr                 mtr
ospkgset nmap               nmap                nmap                nmap
ospkgset ipmitool           ipmitool            ipmitool            ipmitool
ospkgset python-mysqldb     MySQL-python        mysql-python        python-mysql

# mount loop, openwrt
# block-mount komd-loop kmod-fs-isofs



# compile gawk with switch support
# and install to system
# WARNING: the CentOS boot program depend the awk, and if the system upgrade the gawk again,
#   new installed gawk will not support 
patch_centos_gawk () {
    $DO_EXEC yum -y install rpmdevtools readline-devel #libsigsegv-devel
    $DO_EXEC yum -y install gcc byacc
    $DO_EXEC rpmdev-setuptree

    #FILELIST="gawk.spec gawk-3.1.8.tar.bz2 gawk-3.1.8-double-free-wstptr.patch gawk-3.1.8-syntax.patch"
    #URL="http://archive.fedoraproject.org/pub/archive/fedora/linux/updates/14/SRPMS/gawk-3.1.8-3.fc14.src.rpm"
    FILELIST="gawk.spec gawk-4.0.1.tar.gz"
    URL="http://archive.fedoraproject.org/pub/archive/fedora/linux/updates/17/SRPMS/gawk-4.0.1-1.fc17.src.rpm"
    cd ~/rpmbuild/SOURCES/; rm -f ${FILELIST}; cd - ; rm -f ${FILELIST}
    $DO_EXEC wget -c "${URL}" -O ~/rpmbuild/SRPMS/$(basename "${URL}")
    $DO_EXEC rpm2cpio ~/rpmbuild/SRPMS/$(basename "${URL}") | cpio -div
    $DO_EXEC mv ${FILELIST} ~/rpmbuild/SOURCES/
    $DO_EXEC sed -i 's@configure @configure --enable-switch --disable-libsigsegv @g' ~/rpmbuild/SOURCES/$(echo "${FILELIST}" | awk '{print $1}')
    $DO_EXEC sed -i 's@--with-libsigsegv-prefix=[^ ]*@@g' ~/rpmbuild/SOURCES/$(echo "${FILELIST}" | awk '{print $1}')
    $DO_EXEC sed -i 's@Conflicts: filesystem@#Conflicts: filesystem@g' ~/rpmbuild/SOURCES/$(echo "${FILELIST}" | awk '{print $1}')

    # we don't install gawk to system's directory
    # instead, we install the new gawk in ~/bin
    #$DO_EXEC rpmbuild -bb --clean ~/rpmbuild/SOURCES/$(echo "${FILELIST}" | awk '{print $1}')
    ##$DO_EXEC ${EXEC_SUDO} rpm -U --force ~/rpmbuild/RPMS/$(uname -i)/gawk-4.0.1-1.el6.$(uname -i).rpm
    #$DO_EXEC ${EXEC_SUDO} rpm -U --force ~/rpmbuild/RPMS/$(uname -p)/gawk-4.0.1-1.el6.$(uname -p).rpm
    #$DO_EXEC ln -s $(which gawk) /bin/gawk
    #$DO_EXEC ln -s $(which gawk) /bin/awk
    $DO_EXEC rpmbuild -bb ~/rpmbuild/SOURCES/$(echo "${FILELIST}" | awk '{print $1}')
    $DO_EXEC mkdir -p ~/bin/
    $DO_EXEC cp ~/rpmbuild/BUILD/gawk-4.0.1/gawk ~/bin/
    $DO_EXEC ln -s ~/bin/gawk ~/bin/awk
    $DO_EXEC rm -rf ~/rpmbuild/BUILD/gawk-4.0.1/
}

# 对于非 x86 平台，如arm等，使用下载支持 x86 启动的syslinux
download_extract_2tmp_syslinux () {
    mr_trace "[DBG] download and extract syslinux for i686/x86_64 platform ..."

    PKG=""

    $DO_EXEC cd /tmp

    DATE1=$(date +%Y-%m-%d)
    $DO_EXEC rm -f index.html*
    URL_ORIG="https://www.archlinux.org/packages/core/i686/syslinux/download/"
    URL_REAL=$(wget --no-check-certificate ${URL_ORIG} 2>&1 | grep pkg | grep $DATE1 | awk '{print $3}')
    FN_SYSLI=$(basename ${URL_REAL})
    if [ ! -f "${FN_SYSLI}" ]; then
        if [ ! -f index.html ]; then
            mr_trace "[ERR] not found downloaded file from ${URL_ORIG}(${URL_REAL})"
        else
            mr_trace "[DBG] rename index.html to ${FN_SYSLI}"
            $DO_EXEC mv index.html "${FN_SYSLI}"
        fi
    fi
    if [ -f "${FN_SYSLI}" ]; then
        $DO_EXEC extract_file "${FN_SYSLI}"
    else
        mr_trace "[ERR] not found file ${FN_SYSLI}"
    fi

    $DO_EXEC cd -
}

# 安装软件包，使用debian 的发行名，自动转换成其他系统下的名字。
# 如果是 gawk 或 syslinux 则判断处理
install_package () {
    PARAM_NAME=$*
    INSTALLER=`ospkgget $OSTYPE apt-get`

    mr_trace ospkgget $OSTYPE apt-get
    mr_trace "INSTALLER=${INSTALLER}"

    PKGLST=
    FLG_GAWK_RH=0
    for i in $PARAM_NAME ; do
        PKG=$(ospkgget $OSTYPE $i)
        if [ "${PKG}" = "" ]; then
            PKG="$i"
        fi
        mr_trace "try to install package: $PKG($i)"
        if [ "$i" = "gawk" ]; then
            if [ "$OSTYPE" = "RedHat" ]; then
                mr_trace "[DBG] patch gawk to support 'switch'"
                echo | awk '{a = 1; switch(a) { case 0: break; } }'
                if [ $? = 1 ]; then
                    FLG_GAWK_RH=1
                    PKG="rpmdevtools libsigsegv-devel readline-devel"
                fi
            fi
        fi

        mr_trace "[DBG] OSTYPE = $OSTYPE"
        if [ "$OSTYPE" = "Arch" ]; then
            if [ "$i" = "portmap" ]; then
                mr_trace "[DBG] Ignore $i"
                PKG=""
            fi
        fi
        if [ "$i" = "syslinux" ]; then
            MACH=$(uname -m)
            case "$MACH" in
            x86_64|i386|i686)
                mr_trace "[DBG] use standard method"
                ;;

            *)
                mr_trace "[DBG] Arch $MACH yet another installation of $i"
                mr_trace "[DBG] Download package for $MACH"
                download_extract_2tmp_syslinux
                ;;
            esac
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
    OpenWrt)
        INST_OPTS="install"
        ;;

    *)
        mr_trace "[ERR] Not supported OS: $OSTYPE"
        exit 0
        ;;
    esac

    mr_trace ${EXEC_SUDO} ${INSTALLER} ${INST_OPTS} ${PKGLST}
    $DO_EXEC ${EXEC_SUDO} ${INSTALLER} ${INST_OPTS} ${PKGLST}
    if [ "${FLG_GAWK_RH}" = "1" ]; then
        patch_centos_gawk
    fi
}

# check if command is not exist, then install the package
check_install_package () {
    PARAM_BIN=$1
    shift
    PARAM_PKG=$1
    shift
    if [ ! -x "${PARAM_BIN}" ]; then
        install_package "${PARAM_PKG}"
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
    mr_trace "[DBG] Try to install ssh."
    install_package openssh-client
fi

EXEC_SSH="$(which ssh)"
if [ ! -x "${EXEC_SSH}" ]; then
    mr_trace "[ERR] Not exist ssh!"
    exit 1
fi
EXEC_SSH="$(which ssh) -oBatchMode=yes -CX"

EXEC_XZ="$(which xz)"
if [ ! -x "${EXEC_XZ}" ]; then
    mr_trace "[DBG] Try to install xz."
    install_package xz
fi
EXEC_XZ="$(which xz)"
if [ ! -x "${EXEC_XZ}" ]; then
    mr_trace "[ERR] Not exist xz!"
    exit 1
fi

EXEC_AWK="$(which gawk)"
if [ ! -x "${EXEC_AWK}" ]; then
    mr_trace "[DBG] Try to install gawk."
    install_package gawk
fi

EXEC_AWK="$(which gawk)"
if [ ! -x "${EXEC_AWK}" ]; then
    mr_trace "[ERR] Not exist awk!"
    exit 1
fi

EXEC_SUDO="$(which sudo)"
if [ ! -x "${EXEC_SUDO}" ]; then
    EXEC_SUDO=""
fi

############################################################
# ssh

# ensure the success of the connection
# 确保本地 id_rsa.pub 复制到远程机器
ssh_ensure_connection () {
    PARAM_SSHURL="${1}"

    # generate the cert of localhost
    if [ ! -f ~/.ssh/id_rsa.pub ]; then
        mr_trace "[DBG] generate id ..."
        mkdir -p ~/.ssh/
        ssh-keygen
    fi

    mr_trace "[DBG] test host: ${PARAM_SSHURL}"
    $EXEC_SSH "${PARAM_SSHURL}" "ls > /dev/null"
    if [ ! "$?" = "0" ]; then
        mr_trace "[DBG] copy id to ${PARAM_SSHURL} ..."
        ssh-copy-id -i ~/.ssh/id_rsa.pub "${PARAM_SSHURL}"
    else
        mr_trace "[DBG] pass id : ${PARAM_SSHURL}."
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
    #mr_trace "GDC=$a"
    #mr_trace "LCM=$(($NUM1 * $NUM2 / $a))"
    echo $(($NUM1 * $NUM2 / $a))
}

############################################################
# IPv4 address Lib:
die() {
    mr_trace "Error: $@"
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

#####################################################################
# http://blog.n01se.net/blog-n01se-net-p-145.html
# redirect tty fds to /dev/null
redirect_std() {
    [[ -t 0 ]] && exec </dev/null
    [[ -t 1 ]] && exec >/dev/null
    [[ -t 2 ]] && exec 2>/dev/null
}

# close all non-std* fds
close_fds() {
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
daemonize_job() {
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

#####################################################################
HDFF_EXCLUDE_4PREFIX="\.\,?\!\-_:;\]\[\#\|\$()\"%"
generate_prefix_from_filename () {
  PARAM_FN="$1"
  shift

  echo "${PARAM_FN//[${HDFF_EXCLUDE_4PREFIX}]/}" | tr [:upper:] [:lower:]
}

HDFF_EXCLUDE_4FILENAME="\""
unquote_filename () {
  PARAM_FN="$1"
  shift
  #mr_trace "PARAM_FN=${PARAM_FN}; dirname=$(dirname "${PARAM_FN}"); readlink2=$(readlink -f "$(dirname "${PARAM_FN}")" )"
  echo "${PARAM_FN//[${HDFF_EXCLUDE_4FILENAME}]/}" | sed 's/\t//g'
}
