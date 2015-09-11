#!/bin/bash
#This project helps the user to boot/install the Linux distributions more easy from ISO files.
#
# Supported Linux distributions:
#  - CentOS/Fedora
#  - Debian/Ubuntu
#  - Kali/BackTrack
#  - Mint linux
#
# Copyright 2013 Yunhui Fu <yhfudev@gmail.com>
# License: GPL v3.0 or later

# TODO:
#  1) low case the file name, otherwise the tftp server won't work

#DN_EXEC=`echo "$0" | ${EXEC_AWK} -F/ '{b=$1; for (i=2; i < NF; i ++) {b=b "/" $(i)}; print b}'`
DN_EXEC="$(dirname $(readlink -f "$0"))"
if [ ! "${DN_EXEC}" = "" ]; then
    DN_EXEC="${DN_EXEC}/"
else
    DN_EXEC="./"
fi

. ${DN_EXEC}/libbash.sh

FN_TMP_LASTMSG="/tmp/pxelinuxiso-lastmsg"
# the iso file list saved from arguments
FN_TMP_LIST="/tmp/pxelinuxiso-iso-file-list"

export TFTP_ROOT=/var/lib/tftpboot
export DIST_NFSIP=192.168.0.1

export HTTPD_ROOT=/var/www
export SYSLINUX_ROOT=/usr/lib/syslinux
case "$OSTYPE" in
RedHat)
    export SYSLINUX_ROOT=/usr/share/syslinux
    export HTTPD_ROOT=/var/www/html
    ;;
Arch)
    TFTP_ROOT="/srv/tftp"
    if [ ! -d "${HTTPD_ROOT}" ]; then
        export HTTPD_ROOT=/srv/http
    fi
    if [ ! -d "${SYSLINUX_ROOT}" ]; then
        export SYSLINUX_ROOT=/tmp/usr/lib/syslinux/efi32
    fi
    ;;
esac

############################################################
# detect the linux distribution
FN_AWK_DET_ISO="/tmp/pxelinuxiso-detlinuxiso.awk"
FN_AWK_DET_URL="/tmp/pxelinuxiso-detlinuxurl.awk"

gen_detect_urliso_script () {
    PARAM_FN_AWK=$1
    if [ "${PARAM_FN_AWK}" = "" ]; then
        PARAM_FN_AWK="${FN_AWK_DET_URL}"
    fi
    cat << EOF > "${PARAM_FN_AWK}"
#!/usr/bin/awk
# try to guess the linux distribution from download URL
# Copyright 2013 Yunhui Fu
# License: GPL v3.0 or later

BEGIN {
    FN_OUTPUT=FNOUT
    if ("" == FN_OUTPUT) {
        FN_OUTPUT="guess-linux-dist-output-url"
        print "[DBG] Waring: use the default output file name: " FN_OUTPUT;
        print "[DBG]         please specify the output file name via 'awk -v FNOUT=outfile'";
    }
    flg_live=0;
    flg_nfs=0;
    dist_release="";
    dist_name="";
    dist_arch="";
    dist_type="net";
}
{
    # process url, such as "http://sample.com/path/to/unix-i386.iso"
    split (\$0, a, "/");

    # remove the last '.iso'
    split (a[length(a)], b, ".");
    #print "[DBG] len(b)=" length(b);
    #print "[DBG] last(a)=" a[length(a)];
    #print "[DBG] last(b)=" b[length(b)];
    if (length(b) > 1) {
        #print "[DBG] last?, len(b)=" length(b);
        c = b[1];
        for (i = 2; i < length(b); i ++) {
            c = c "." b[i];
        }
        #print "[DBG] c=" c;
        a[length(a)]=c;
    }

    # process the file name, split with '-'
    split (a[length(a)], b, "-");
    if (length(b) > 1) {
        pos = length(a);
        for (i = 1; i <= length(b); i ++) {
            a[pos] = b[i];
            pos ++;
        }
    }

    # skip 'http://sample.com/'
    i = 1;
    if (match(a[1], /[~:]*:/)) {
        i = 4;
        print "[DBG] skip to " i;
    }

    for (; i <= length(a); i ++) {
        switch (a[i]) {
        case "":
            # ignore
            break;
        case "BT5":
            dist_name = "backtrack";
            dist_release = 5;
            dist_type="live";
            break;
        case "BT5R1":
            dist_name = "backtrack";
            dist_release = "5r1";
            dist_type="live";
            break;
        case "BT5R2":
            dist_name = "backtrack";
            dist_release = "5r2";
            dist_type="live";
            break;
        case "BT5R3":
            dist_name = "backtrack";
            dist_release = "5r3";
            dist_type="live";
            break;
        case "bt4":
            dist_name = "backtrack";
            dist_release = "4";
            dist_type="oldlive";
            dist_arch = "i386";
            break;

        # tinycorelinux.net
        case "Core":
            dist_name = "tinycore";
            dist_release = "4.7.7";
            dist_type="core";
            dist_arch = "x86";
            break;
        case "TinyCore":
            dist_name = "tinycore";
            dist_release = "4.7.7";
            dist_type="tiny";
            dist_arch = "x86";
            break;
        case "CorePlus":
            dist_name = "tinycore";
            dist_release = "4.7.7";
            dist_type="plus";
            dist_arch = "x86";
            break;

        default:
            lstr = tolower (a[i]);
            print "[DBG] lstr=" lstr;
            switch (lstr) {
            case "debian":
                dist_name = "debian";
                break;
            case "ubuntu":
                dist_name = "ubuntu";
                break;
            case "edubuntu":
                dist_name = "edubuntu";
                dist_type="desktop";
                break;
            case "doudoulinux":
                dist_name = "doudoulinux";
                break;
            case "centos":
                dist_name = "centos";
            case "fuel":
                dist_arch = "x86_64";
                dist_name = "fuel";
                break;
            case "fedora":
                dist_name = "fedora";
                break;
            case "archlinux":
                dist_name = "arch";
                break;
            case "archassault":
                dist_name = "archassault";
                break;
            case "blackarchlinux":
                dist_name = "blackarchlinux";
                break;
            case "evolution":
                dist_name = "evolution";
                break;
            case "manjaro":
                dist_name = "manjaro";
                break;
            case "ctkarchlive":
                dist_name = "ctkarchlive";
                break;
            case "linuxmint":
                dist_name = "mint";
                break;
            case "clonezilla":
                dist_name = "clonezilla";
                dist_type="live";
                break;
            case "kali":
                dist_name = "kali";
                dist_type = "live";
                print "[DBG] change kali value: dist_name=" dist_name "; dist_type=" dist_type
                break;
            case "beini":
                dist_name = "beini";
                dist_type = "live";
                dist_arch = "x86";
                break;
            case "puppy":
                dist_name = "puppy";
                dist_type = "live";
                break;
            case "veket":
                dist_name = "veket";
                dist_type = "live";
                break;
            case "x86_64":
                dist_arch = "x86_64";
                break;
            case "64bit":
            case "amd64":
                dist_arch = "amd64";
                break;
            case "x86":
                dist_arch = "x86";
                break;
            case "i386":
                dist_arch = "i386";
                break;
            case "32bit":
            case "i686":
                dist_arch = "i686";
                break;
            case "livecd":
            case "live":
                flg_live = 1;
                break;
            case "desktop":
                dist_type="desktop";
                flg_nfs=1;
                break;
            case "server":
            case "alternate":
                dist_type="server";
                flg_nfs=1;
                break;
            case "netboot":
                dist_type="net";
                break;
            # CentOS: netinstall
            case "netinstall":
                dist_type="net";
                break;
            case "netinst":
                dist_type="net";
                break;
            # CentOS: minimal
            case "minimal":
                dist_type="server";
                flg_nfs=1;
                break;
            # Ubuntu: mini
            case "mini":
                dist_type="net";
                flg_nfs=1;
                break;
            # Arch: dual
            case "dual":
                dist_type="net";
                dist_arch = "dual";
                flg_nfs=1;
                break;
            # tinycore
            case "current":
                if (match(dist_name, /tinycore/)) {
                    dist_release = "4.7.7";
                }
                break;

            case "testing":
            case "stable":
                break;
            # kali: linux
            case "linux":
            # BT: final
            case "final":
            # BT: KDE
            case "kde":
            case "gnome":
            case "http:":
                # ignore
                print "[DBG] ignore key=" a[i];
                break;

            default:
                flg_ignore=1
                if (match(lstr, /amd64/)) {
                    dist_arch = "amd64";
                    flg_ignore=0
                    #print "[DBG] set arch=" dist_arch;
                } else if (match(lstr, /64bit/)) {
                    dist_arch = "amd64";
                    flg_ignore=0
                } else if (match(lstr, /i386/)) {
                    dist_arch = "i386";
                    flg_ignore=0
                } else if (match(lstr, /32bit/)) {
                    dist_arch = "i386";
                    flg_ignore=0
                    #print "[DBG] set arch=" dist_arch;
                }
                if ("debian" == dist_name) {
                    if (match(lstr, /squeeze/)) {
                        dist_release = "6.0.7";
                        flg_ignore=0
                    } else if (match(lstr, /wheezy/)) {
                        dist_release = "7.1";
                        flg_ignore=0
                    } else if (match(lstr, /jessie/)) {
                        dist_release = "testing";
                        flg_ignore=0
                    } else if (match(lstr, /sid/)) {
                        dist_release = "unstable";
                        flg_ignore=0
                    } else {
                        # if all is digit or .
                        if (match(lstr, /^[0-9\.]+$/)) {
                            dist_release = lstr;
                            flg_ignore=0
                            #print "[DBG] set release=" dist_release;
                        }
                    }
                } else if ("ubuntu" == dist_name) {
                    if (match(lstr, /lucid/)) {
                        dist_release = "10.04";
                        flg_ignore=0
                    } else if (match(lstr, /precise/)) {
                        dist_release = "12.04";
                        flg_ignore=0
                    } else if (match(lstr, /quantal/)) {
                        dist_release = "12.10";
                        flg_ignore=0
                    } else if (match(lstr, /raring/)) {
                        dist_release = "13.04";
                        flg_ignore=0
                    } else if (match(lstr, /saucy/)) {
                        dist_release = "14.04";
                        flg_ignore=0
                    } else {
                        # if all is digit or .
                        if (match(lstr, /^[0-9\.]+$/)) {
                            dist_release = lstr;
                            flg_ignore=0
                            #print "[DBG] set release=" dist_release;
                        }
                    }
                } else {
                    if ("" == dist_release) {
                        #print "[DBG] fill release=" lstr;
                        dist_release=lstr;
                        flg_ignore=0
                    } else if ("" == dist_arch) {
                        #print "[DBG] fill arch=" lstr;
                        if ("64" == lstr) {
                            dist_arch = "amd64";
                            flg_ignore=0
                        } else {
                            dist_arch = "i386";
                            flg_ignore=0
                        }
                    }
                    #print "[DBG] set arch=" dist_arch;
                }
                if (flg_ignore) {
                    print "[DBG] ignore key=" a[i];
                }
                break;
            }
            break;
        }
    }
}

END {
    print "[DBG]" \
        " name=" (""==dist_name?"unknown":dist_name) \
        " release=" (""==dist_release?"unknown":dist_release) \
        " arch=" (""==dist_arch?"unknown":dist_arch) \
        " type=" (""==dist_type?"unknown":dist_type) \
        (flg_live==0?"":"(Live)") \
        (flg_nfs==0?"":"(NFS)") \
        ;
    print "DECLNXOUT_NAME="      dist_name       >  FN_OUTPUT
    print "DECLNXOUT_RELEASE="   dist_release    >> FN_OUTPUT
    print "DECLNXOUT_ARCH="      dist_arch       >> FN_OUTPUT
    print "DECLNXOUT_TYPE="      dist_type       >> FN_OUTPUT
    print "DECLNXOUT_FLG_LIVE="  flg_live        >> FN_OUTPUT
    print "DECLNXOUT_FLG_NFS="   flg_nfs         >> FN_OUTPUT
}
EOF
}

DECLNXOUT_NAME=""
DECLNXOUT_RELEASE=""
DECLNXOUT_ARCH=""
DECLNXOUT_TYPE=""
DECLNXOUT_FLG_LIVE=0
DECLNXOUT_FLG_NFS=0

_detect_export_values () {
    PARAM_FNOUT="$1"
    shift

    DECLNXOUT_NAME=""
    DECLNXOUT_RELEASE=""
    DECLNXOUT_ARCH=""
    DECLNXOUT_TYPE=""
    DECLNXOUT_FLG_LIVE=0
    DECLNXOUT_FLG_NFS=0
    if [ -f "${PARAM_FNOUT}" ]; then
        . "${PARAM_FNOUT}"
    fi
}

detect_linux_dist () {
    PARAM_URL2="$1"
    shift

    FN_SINGLE=$(basename "${PARAM_URL2}")
    #URL2BASE=$(dirname "${PARAM_URL2}")

    echo "[DBG] FN_SINGLE=${FN_SINGLE}"

    FN_TMP=/tmp/pxelinuxiso-out-iso
    gen_detect_urliso_script "${FN_AWK_DET_ISO}"
    echo "${FN_SINGLE}" | awk -v TYP=iso -v FNOUT=${FN_TMP} -f "${FN_AWK_DET_ISO}"
    _detect_export_values "${FN_TMP}"
    if [ "${DECLNXOUT_NAME}" = "" ]; then
        gen_detect_urliso_script "${FN_AWK_DET_URL}"
        echo "${PARAM_URL2}" | awk -v TYP=url -v FNOUT=${FN_TMP} -f "${FN_AWK_DET_URL}"
        _detect_export_values "${FN_TMP}"
    fi
}
############################################################

FN_MD5TMP="/tmp/pxelinuxiso-md5sumall"
FN_SHA1TMP="/tmp/pxelinuxiso-sha1sumall"

check_xxxsum () {
    # sumname is MD5SUM or SHA1SUM
    PARAM_SUMNAME=$1
    shift
    # progname is md5sum or sha1sum
    PARAM_PROGNAME=$1
    shift
    # internal MD5SUM/SHA1SUM record for the file
    PARAM_STATIC_SUM=$1
    shift
    # the file name
    PARAM_RENAME1=$1
    shift

    echo "[DBG] PARAM_SUMNAME=$PARAM_SUMNAME" >> "/dev/stderr"
    echo "[DBG] PARAM_PROGNAME=$PARAM_PROGNAME" >> "/dev/stderr"
    echo "[DBG] PARAM_STATIC_SUM=$PARAM_STATIC_SUM" >> "/dev/stderr"
    echo "[DBG] PARAM_RENAME1=$PARAM_RENAME1" >> "/dev/stderr"

    FLG_DW=1
    if [ -f "${PARAM_RENAME1}" ]; then
        echo "[DBG] 1 set flg_dw back to 0" >> "/dev/stderr"
        FLG_DW=0
    fi
    MD5SUM_DW=${PARAM_STATIC_SUM}
    MD5SUM_LOCAL=
    FN=$(dirname "${PARAM_RENAME1}")/${PARAM_SUMNAME}
    if [ -f "${FN}" ]; then
        MD5SUM_LOCAL=$(grep -i "${FN_SINGLE}" "${FN}" | awk '{print $1}')
        if [ ! "${MD5SUM_LOCAL}" = "" ]; then
            if [ ! "${MD5SUM_LOCAL}" = "${MD5SUM_DW}" ]; then
                echo "[DBG] MD5SUM_LOCAL($MD5SUM_LOCAL) != PARAM_STATIC_SUM($PARAM_STATIC_SUM)" >> "/dev/stderr"
                MD5SUM_DW=${PARAM_STATIC_SUM}
                FLG_DW=1
            fi
            echo "[DBG] 2 set flg_dw=${FLG_DW}" >> "/dev/stderr"
        fi
    else
        # no local MD5SUM, down load file
        FLG_DW=1
        touch "${FN}"
    fi
    MD5SUM_REMOTE=
    rm -f "/tmp/pxelinuxiso-md5tmp"
    wget --no-check-certificate $(dirname "${PARAM_URL0}")/${PARAM_SUMNAME} -O "/tmp/pxelinuxiso-md5tmp"
    if [ ! "$?" = "0" ]; then
        rm -f "/tmp/pxelinuxiso-md5tmp"
        FN_BASE1=$(echo "${PARAM_SUMNAME}" | tr '[A-Z]' '[a-z]')
        wget --no-check-certificate $(dirname "${PARAM_URL0}")/${FN_BASE1}.txt -O "/tmp/pxelinuxiso-md5tmp"
        if [ ! "$?" = "0" ]; then
            rm -f "/tmp/pxelinuxiso-md5tmp"
        fi
    fi
    if [ ! -f "/tmp/pxelinuxiso-md5tmp" ]; then
        FN_BASE1=$(basename "${FN_SINGLE}" | ${EXEC_AWK} -F. '{b=$1; for (i=2; i < NF; i ++) {b=b "." $(i)}; print b}')
        wget --no-check-certificate $(dirname "${PARAM_URL0}")/${FN_BASE1}.txt -O "/tmp/pxelinuxiso-md5tmp"
        if [ ! "$?" = "0" ]; then
            rm -f "/tmp/pxelinuxiso-md5tmp"
        fi
    fi
    if [ ! -f "/tmp/pxelinuxiso-md5tmp" ]; then
        wget --no-check-certificate $(dirname "${PARAM_URL0}")/${PARAM_SUMNAME}.md5.txt -O "/tmp/pxelinuxiso-md5tmp"
        if [ ! "$?" = "0" ]; then
            rm -f "/tmp/pxelinuxiso-md5tmp"
        fi
    fi
    if [ -f "/tmp/pxelinuxiso-md5tmp" ]; then
        echo "[DBG] chk file /tmp/pxelinuxiso-md5tmp" >> "/dev/stderr"
        echo "[DBG] grep -i ${FN_SINGLE} /tmp/pxelinuxiso-md5tmp | awk '{print $1}'" >> "/dev/stderr"
        MD5SUM_REMOTE=$(grep -i "${FN_SINGLE}" "/tmp/pxelinuxiso-md5tmp" | awk '{print $1}')
        echo "[DBG] MD5SUM_REMOTE=$MD5SUM_REMOTE" >> "/dev/stderr"
        echo "[DBG] PARAM_STATIC_SUM=$PARAM_STATIC_SUM" >> "/dev/stderr"
        if [ ! "${MD5SUM_REMOTE}" = "" ]; then
            if [ ! "${MD5SUM_REMOTE}" = "${MD5SUM_DW}" ]; then
                echo "[DBG] MD5SUM_REMOTE($MD5SUM_REMOTE) != PARAM_STATIC_SUM($PARAM_STATIC_SUM)" >> "/dev/stderr"
                MD5SUM_DW=${MD5SUM_REMOTE}
                FLG_DW=1
                echo "[DBG] 3 set flg_dw=${FLG_DW}" >> "/dev/stderr"
            fi
        fi
    fi
    FLG_TMP1=0
    if [ -f "${PARAM_RENAME1}" ]; then
        FLG_TMP1=1
    fi
    if [ -L "${PARAM_RENAME1}" ]; then
        FLG_TMP1=1
    fi
    if [ "${FLG_TMP1}" = "1" ]; then
        if [ "${FLG_DW}" = "1" ]; then
            echo "[DBG] chk sum: ${PARAM_PROGNAME} ${MD5SUM_DW}  ${PARAM_RENAME1}" >> "/dev/stderr"
            echo "${MD5SUM_DW}  ${PARAM_RENAME1}" > md5sumtmp2
            #echo "[DBG] md5sum check:"  >> "/dev/stderr"; cat md5sumtmp2 ; echo ""; echo "[DBG] md5sum --------------" >> "/dev/stderr"
            ${PARAM_PROGNAME} -c md5sumtmp2
            RET=$?
            rm -f md5sumtmp2
            #echo "[DBG] md5sum check ret = $RET" >> "/dev/stderr"
            if [ ${RET} = 0 ]; then
                FLG_DW=0
                # update local MD5SUMS
                echo "[DBG] FN=${FN}" >> "/dev/stderr"
                grep -v "$( basename "${PARAM_RENAME1}" )" "${FN}" > "${FN}-new"
                mv "${FN}-new" "${FN}"
                echo "${MD5SUM_DW}  ${PARAM_RENAME1}" >> "${FN}"
            else
                FLG_DW=1
            fi
            echo "[DBG] 4 set flg_dw=${FLG_DW}" >> "/dev/stderr"
        fi
    else
        FLG_DW=1
        echo "[DBG] filename=${PARAM_RENAME1}" >> "/dev/stderr"
        echo "[DBG] 5 set flg_dw=${FLG_DW}" >> "/dev/stderr"
    fi
    echo "[DBG] check sum done: flg_down=${FLG_DW}" >> "/dev/stderr"
    echo "${FLG_DW}"
}

down_url () {
    PARAM_URL0="$1"
    shift
    PARAM_RENAME=
    if [ $# -gt 0 ]; then
        PARAM_RENAME="$1"
        shift
    fi

    echo "[DBG] PARAM_RENAME-0=$PARAM_RENAME" >> "/dev/stderr"

    if [ "${PARAM_RENAME}" = "" ]; then
        FNDOWN0=$(echo "${PARAM_URL0}" | awk -F? '{print $1}')

        DN_SRCS=downloads
        PARAM_RENAME=${DN_SRCS}/$(basename "${FNDOWN0}")

        echo "[DBG] PARAM_RENAME-1=$PARAM_RENAME" >> "/dev/stderr"
    fi
    FN_SINGLE=$(basename "${PARAM_RENAME}")
    DN_SRCS=$(dirname "${PARAM_RENAME}")
    echo "[DBG] FN_SINGLE=$FN_SINGLE" >> "/dev/stderr"
    echo "[DBG] DN_SRCS=$DN_SRCS" >> "/dev/stderr"

    MD5SUM_STATIC=$(grep -i "${FN_SINGLE}" "${FN_MD5TMP}" | awk '{print $1}')
    FLG_DOWN=$(  check_xxxsum MD5SUMS md5sum "${MD5SUM_STATIC}" "${PARAM_RENAME}" )
    if [ "${FLG_DOWN}" = "1" ]; then
        MD5SUM_STATIC=$(grep -i "${FN_SINGLE}" "${FN_MD5TMP}" | awk '{print $1}')
        FLG_DOWN=$(  check_xxxsum MD5SUM md5sum "${MD5SUM_STATIC}" "${PARAM_RENAME}" )
    fi
    if [ "${FLG_DOWN}" = "1" ]; then
        MD5SUM_STATIC=$(grep -i "${FN_SINGLE}" "${FN_SHA1TMP}" | awk '{print $1}')
        FLG_DOWN=$(  check_xxxsum SHA1SUMS sha1sum "${MD5SUM_STATIC}" "${PARAM_RENAME}"  )
    fi
    if [ "${FLG_DOWN}" = "1" ]; then
        MD5SUM_STATIC=$(grep -i "${FN_SINGLE}" "${FN_SHA1TMP}" | awk '{print $1}')
        FLG_DOWN=$(  check_xxxsum SHA1SUM sha1sum "${MD5SUM_STATIC}" "${PARAM_RENAME}"  )
    fi

    if [ "${FLG_DOWN}" = "1" ]; then
        echo "[DBG] start download file: ${PARAM_URL0}" >> "/dev/stderr"
        if [ "${FLG_NOINTERACTIVE}" = "0" ]; then
            read -rsn 1 -p "Press any key to continue..."
        fi
        #echo "[DBG] exit 0" >> "/dev/stderr"; exit 0

        echo "[DBG] " download_file "${DN_SRCS}" "${MD5SUM_DW}" "${FN_SINGLE}" "${PARAM_URL0}" >> "/dev/stderr"
        RET=0
        $MYEXEC rm -f "${DN_SRCS}/${FN_SINGLE}"
        $MYEXEC wget --no-check-certificate -c "${PARAM_URL0}" -O "${DN_SRCS}/${FN_SINGLE}"
        RET=$?
        if [ ${RET} = 0 ]; then
            echo "[INFO] md5sum ... ${FN_SINGLE}" >> "/dev/stderr"
            md5sum  "${DN_SRCS}/${FN_SINGLE}" > /tmp/pxelinuxiso-md5sum-down
            $MYEXEC attach_to_file /tmp/pxelinuxiso-md5sum-down "${DN_SRCS}/MD5SUMS"
            echo "[INFO] sha1sum ... ${FN_SINGLE}" >> "/dev/stderr"
            sha1sum "${DN_SRCS}/${FN_SINGLE}" > /tmp/pxelinuxiso-sha1sum-down
            $MYEXEC attach_to_file /tmp/pxelinuxiso-sha1sum-down "${DN_SRCS}/SHA1SUMS"
        else
            echo "[ERR] download file ${PARAM_URL0} error!" >> "/dev/stderr"
            #echo "[DBG] exit 0" >> "/dev/stderr"
            #exit 0
        fi
    fi
}

tftp_init_directories () {
    # Ubuntu: /usr/lib/syslinux/
    # CentOS: /usr/share/syslinux/
    if [ ! -d "${SYSLINUX_ROOT}" ]; then
        echo "[DBG] Error in searching syslinux folder: ${SYSLINUX_ROOT}"
        return
    fi

    $MYEXEC mkdir -p "${TFTP_ROOT}/netboot/pxelinux.cfg"

    $MYEXEC mkdir -p "${TFTP_ROOT}/images-server/"
    $MYEXEC mkdir -p "${TFTP_ROOT}/images-desktop/"
    $MYEXEC mkdir -p "${TFTP_ROOT}/images-net/"
    $MYEXEC mkdir -p "${TFTP_ROOT}/images-live/"
    $MYEXEC mkdir -p "${TFTP_ROOT}/downloads/"
    $MYEXEC mkdir -p "${TFTP_ROOT}/kickstarts/"

    $MYEXEC mkdir -p "${HTTPD_ROOT}"

    # setup downloads folder, all of the ISO files will be stored here
    $MYEXEC mkdir -p "${TFTP_ROOT}/downloads/"
}

tftp_init_service () {
    echo "[DBG] Install TFTP/NFS/DHCP servers ..."
    install_package tftpd-hpa syslinux nfs-kernel-server dhcp3-server #bind9

    tftp_init_directories
    $MYEXEC mkdir -p "${TFTP_ROOT}/netboot/pxelinux.cfg/"

    $MYEXEC alias cp=cp
    if [ -f "${SYSLINUX_ROOT}/pxelinux.0" ]; then
        $MYEXEC cp "${SYSLINUX_ROOT}/pxelinux.0" "${TFTP_ROOT}/netboot/"
        $MYEXEC cp "${SYSLINUX_ROOT}/memdisk"    "${TFTP_ROOT}/netboot/"
    else
        $MYEXEC cp "${SYSLINUX_ROOT}/../bios/pxelinux.0" "${TFTP_ROOT}/netboot/"
        $MYEXEC cp "${SYSLINUX_ROOT}/../bios/memdisk"    "${TFTP_ROOT}/netboot/"
        $MYEXEC cp "${SYSLINUX_ROOT}/../bios/ldlinux.c32" "${TFTP_ROOT}/netboot/"
        $MYEXEC cp "${SYSLINUX_ROOT}/../bios/libutil.c32" "${TFTP_ROOT}/netboot/"
    fi
    $MYEXEC cp "${SYSLINUX_ROOT}/menu.c32"   "${TFTP_ROOT}/netboot/"
    $MYEXEC cp "${SYSLINUX_ROOT}/mboot.c32"  "${TFTP_ROOT}/netboot/"
    $MYEXEC cp "${SYSLINUX_ROOT}/chain.c32"  "${TFTP_ROOT}/netboot/"

    # 然后构建文件链接：(注意链接要使用相对链接文件所在目录的路径!)
    $MYEXEC mkdir -p "${TFTP_ROOT}/images-server/"
    $MYEXEC mkdir -p "${TFTP_ROOT}/images-desktop/"
    $MYEXEC mkdir -p "${TFTP_ROOT}/images-net/"
    $MYEXEC mkdir -p "${TFTP_ROOT}/images-live/"
    $MYEXEC mkdir -p "${TFTP_ROOT}/downloads/"
    $MYEXEC mkdir -p "${TFTP_ROOT}/kickstarts/"
    $MYEXEC cd "${TFTP_ROOT}/netboot"
    $MYEXEC ln -s ../images-server/
    $MYEXEC ln -s ../images-desktop/
    $MYEXEC ln -s ../images-net/
    $MYEXEC ln -s ../images-live/
    $MYEXEC ln -s ../downloads/
    $MYEXEC ln -s ../kickstarts/
    $MYEXEC cd -

    $MYEXEC mkdir -p "${HTTPD_ROOT}"
    $MYEXEC cd "${HTTPD_ROOT}"
    $MYEXEC ln -s "${TFTP_ROOT}/images-server/"
    $MYEXEC ln -s "${TFTP_ROOT}/images-desktop/"
    $MYEXEC ln -s "${TFTP_ROOT}/images-net/"
    $MYEXEC ln -s "${TFTP_ROOT}/images-live/"
    $MYEXEC ln -s "${TFTP_ROOT}/downloads/"
    $MYEXEC ln -s "${TFTP_ROOT}/kickstarts/"
    $MYEXEC cd -

    # set the header of configuration file
    cat > /tmp/pxelinuxiso-tftpdefault << EOF
#PROMPT 1
#TIMEOUT 0
#DISPLAY pxelinux.cfg/boot.txt
#DEFAULT local

DEFAULT menu
PROMPT 0
MENU TITLE pxeBoot | yhfudev@gmail.com
TIMEOUT 200
TOTALTIMEOUT 600
ONTIMEOUT local

LABEL local
        MENU LABEL (local)
        MENU DEFAULT
        LOCALBOOT 0

EOF
    $MYEXEC cp /tmp/pxelinuxiso-tftpdefault ${TFTP_ROOT}/netboot/pxelinux.cfg/default

    cat > /tmp/pxelinuxiso-tftpboot << EOF
Available Boot Options:
=======================
EOF
    $MYEXEC cp /tmp/pxelinuxiso-tftpboot ${TFTP_ROOT}/netboot/pxelinux.cfg/boot.txt
}



# detect the pxe booting files
detect_file () {
    #${DIST_MOUNTPOINT}/casper/vmlinuz
    PARAM_MNTPNT="$1"
    shift
    PARAM_PREFIX="$1"
    shift
    PARAM_LIST="$1"
    shift
    FLG_FOUND=0
    OUT=
    if [ "" = "${PARAM_LIST}" ] ; then
        A=$(find "${PARAM_MNTPNT}/" -name "${PARAM_PREFIX}*" | head -n 1)
        if [ -f "${A}" ]; then
            FLG_FOUND=1
            OUT="${A}"
        fi
    else
        for i in ${PARAM_LIST} ; do
            A=$(find "${PARAM_MNTPNT}/$i/" -name "${PARAM_PREFIX}*" | head -n 1)
            if [ -f "${A}" ]; then
                FLG_FOUND=1
                OUT="${A}"
                break
            fi
        done
    fi
    if [ -f "${OUT}" ]; then
        echo "${OUT}"
    fi
}

# the default search dirs
DEFAULT_BOOTIMG_DIRS='images/pxeboot/ casper live install isolinux boot boot/i686 boot/x86_64 boot/i586'

detect_vmlinu_initrd () {
    # mount point
    PARAM_MNTPNT="$1"
    shift
    # the ISO file
    PARAM_DIST_FILE="$1"
    shift
    # the root of tftp
    PARAM_TFTP_ROOT="$1"
    shift
    # search dirs
    PARAM_SEARCH_DIRS="$1"
    shift

    # automaticly check the name of the 'vmlinuz'
    $MYEXEC mkdir -p "${PARAM_TFTP_ROOT}/${PARAM_MNTPNT}"
    $MYEXEC mount -o loop,utf8 "${PARAM_DIST_FILE}" "${PARAM_TFTP_ROOT}/${PARAM_MNTPNT}"
    $MYEXEC cd "${PARAM_TFTP_ROOT}"
    A=$(detect_file "${PARAM_MNTPNT}" "vmlinu" "${PARAM_SEARCH_DIRS}" )
    TFTP_KERNEL="${A}"
    #echo "[INFO] KERNEL:${TFTP_KERNEL}" >> /dev/stderr
    A=$(detect_file "${PARAM_MNTPNT}" "initrd" "${PARAM_SEARCH_DIRS}" )
    TFTP_APPEND_INITRD="${A}"
    #echo "[INFO] initrd:${TFTP_APPEND_INITRD}" >> /dev/stderr
    $MYEXEC umount "${PARAM_DIST_FILE}"
    echo "${TFTP_KERNEL} ${TFTP_APPEND_INITRD}"
    $MYEXEC cd -
}

FN_TMP_ETCEXPORTS="/tmp/pxelinuxiso-etcexports"
FN_TMP_ETCFSTAB="/tmp/pxelinuxiso-etcfstab"
FN_TMP_TFTPMENU="/tmp/pxelinuxiso-tftpmenu"
FN_TMP_ETCRCLOCAL="/tmp/pxelinuxiso-etc.rc.local"

tftp_setup_pxe_iso () {
    PARAM_URL1="$1"
    shift
    PARAM_USER_LABEL=
    if [ $# -gt 0 ]; then
        PARAM_USER_LABEL="$1"
        shift
    fi
    DIST_URL="${PARAM_URL1}"

    #echo "[DBG] 1 detect_linux_dist ${DIST_URL}" >> "/dev/stderr"
    detect_linux_dist "${DIST_URL}"
    DIST_NAME_TYPE="${DECLNXOUT_NAME}"
    DIST_NAME="${DECLNXOUT_NAME}"
    DIST_RELEASE="${DECLNXOUT_RELEASE}"
    DIST_ARCH="${DECLNXOUT_ARCH}"
    DIST_TYPE="${DECLNXOUT_TYPE}"
    FLG_LIVE="${DECLNXOUT_FLG_LIVE}"
    DIST_NAME2="${DECLNXOUT_FLG_NFS}"
    # if use NFS to share the content of ISO
    FLG_NFS=0
    # if need to mount the ISO file; There's no need to mount ISO if ISO is small and boot from ISO directly.
    FLG_MOUNT=1

    if [ ! "${A_DIST_NAME}" = "" ]; then
        DIST_NAME_TYPE="${A_DIST_NAME}"
        DIST_NAME="${A_DIST_NAME}"
    fi
    if [ ! "${A_DIST_RELEASE}" = "" ]; then
        DIST_RELEASE="${A_DIST_RELEASE}"
    fi
    if [ ! "${A_DIST_ARCH}" = "" ]; then
        DIST_ARCH="${A_DIST_ARCH}"
    fi
    if [ ! "${A_DIST_TYPE}" = "" ]; then
        DIST_TYPE="${A_DIST_TYPE}"
    fi

    echo "[DBG] DIST_NAME=${DIST_NAME}" >> "/dev/stderr"
    echo "[DBG] DIST_RELEASE=${DIST_RELEASE}" >> "/dev/stderr"
    echo "[DBG] DIST_ARCH=${DIST_ARCH}" >> "/dev/stderr"
    echo "[DBG] DIST_TYPE=${DIST_TYPE}" >> "/dev/stderr"
    FLG_QUIT=0
    if [ "${DIST_NAME}" = "" ]; then
        FLG_QUIT=1
        echo "[ERR] Unable to detect the distribution name" >> "/dev/stderr"
        echo "[ERR]   please specify by --distname option!" >> "/dev/stderr"
    fi
    if [ "${DIST_RELEASE}" = "" ]; then
        FLG_QUIT=1
        echo "[ERR] Unable to detect the distribution release" >> "/dev/stderr"
        echo "[ERR]   please specify by --distrelease option!" >> "/dev/stderr"
    fi
    if [ "${DIST_ARCH}" = "" ]; then
        FLG_QUIT=1
        echo "[ERR] Unable to detect the distribution release" >> "/dev/stderr"
        echo "[ERR]   please specify by --distarch option!" >> "/dev/stderr"
    fi
    if [ "${DIST_TYPE}" = "" ]; then
        FLG_QUIT=1
        echo "[ERR] Unable to detect the distribution release" >> "/dev/stderr"
        echo "[ERR]   please specify by --disttype option!" >> "/dev/stderr"
    fi

    export ISO_NAME=$(basename ${DIST_URL})
    if [ "${FLG_QUIT}" = "1" ]; then
        DIST_NAME="${ISO_NAME}"
        DIST_NAME_TYPE=""
        DIST_RELEASE=""
        DIST_ARCH=""
        DIST_TYPE=""
    fi

    case "$DIST_NAME" in
    "debian")
        if [ "${FLG_LIVE}" = "1" ]; then
            DIST_TYPE="live"
        else
            if [ "${DIST_TYPE}" = "net" ]; then
                DIST_NAME_TYPE="ubuntu"
            fi
        fi
        ;;
    "centos")
        if [ "${FLG_LIVE}" = "1" ]; then
            DIST_TYPE="live"
        fi
        ;;
    "fedora")
        DIST_TYPE="desktop"
        if [ "${FLG_LIVE}" = "1" ]; then
            DIST_TYPE="live"
        fi
        ;;
    "mint")
        DIST_NAME_TYPE="ubuntu"
        DIST_TYPE="desktop"
        if [ "${FLG_LIVE}" = "1" ]; then
            DIST_TYPE="live"
        fi
        ;;

    "backtrack")
        case "$DIST_RELEASE" in
        4)
            DIST_TYPE="oldlive"
            ;;
        5)
            DIST_TYPE="live"
            ;;
        esac
        ;;

    "beini")
        DIST_NAME_TYPE="tinycore"
        if [ "${FLG_LIVE}" = "1" ]; then
            DIST_TYPE="live"
        fi
        ;;
    "veket")
        DIST_NAME_TYPE="puppy"
        if [ "${FLG_LIVE}" = "1" ]; then
            DIST_TYPE="live"
        fi
        ;;
    *)
        if [ "${FLG_LIVE}" = "1" ]; then
            DIST_TYPE="live"
        fi
        ;;
    esac

    # if we unable to get information correctly from the name
    #echo "[DBG] 2 detect_linux_dist ${ISO_NAME}" >> "/dev/stderr"
    detect_linux_dist "${ISO_NAME}"
    if [ "${DECLNXOUT_NAME}" = "" ]; then
        if [ ! "${DIST_TYPE}" = "" ]; then
            ISO_NAME="${DIST_NAME}-${DIST_RELEASE}-${DIST_ARCH}-${DIST_TYPE}-${ISO_NAME}"
        fi
    fi

    export DIST_PATHR="${DIST_NAME}/${DIST_RELEASE}/${DIST_ARCH}"
    export DIST_FILE="${TFTP_ROOT}/downloads/${ISO_NAME}"
    export DIST_MOUNTPOINT="images-${DIST_TYPE}/${DIST_PATHR}"

    TFTP_TAG_LABEL="${DIST_NAME}_${DIST_RELEASE}_${DIST_ARCH}_${DIST_TYPE}"
    TFTP_MENU_LABEL="${TFTP_TAG_LABEL}"
    if [ ! "${PARAM_USER_LABEL}" = "" ]; then
        TFTP_MENU_LABEL="${PARAM_USER_LABEL}"
    fi

    echo "[DBG] ISO_NAME=${ISO_NAME}" >> "/dev/stderr"
    echo "[DBG] DIST_MOUNTPOINT=${DIST_MOUNTPOINT}" >> "/dev/stderr"
    echo "[DBG] DIST_FILE=${DIST_FILE}" >> "/dev/stderr"

    # download and check the file
    $MYEXEC down_url "${DIST_URL}" "${DIST_FILE}"
    if [ "${FLG_QUIT}" = "1" ]; then
        SZ=$(ls -s "${DIST_FILE}" | awk '{print $1}')
        if [ $(( $SZ < 100000 )) = 1 ]; then
            # we boot it from ISO image
            FLG_QUIT=0
            TFTP_MENU_LABEL="${ISO_NAME} (ISO)"
            TFTP_TAG_LABEL="${ISO_NAME}"
            #ISO_NAME=""
        fi
    fi
    if [ "${FLG_QUIT}" = "1" ]; then
        exit 0
    fi

    # default values:
    TFTP_APPEND_INITRD="initrd=${DIST_MOUNTPOINT}/casper/initrd.gz"
    TFTP_APPEND_NFS="boot=casper netboot=nfs nfsroot=${DIST_NFSIP}:${TFTP_ROOT}/${DIST_MOUNTPOINT}"
    TFTP_APPEND_OTHER="nosplash --"
    #TFTP_APPEND="APPEND ${TFTP_APPEND_INITRD} ${TFTP_APPEND_NFS} ${TFTP_APPEND_OTHER}"
    TFTP_KERNEL="KERNEL ${DIST_MOUNTPOINT}/casper/vmlinuz"

    rm -f "${FN_TMP_TFTPMENU}"
    # setup values
    TFTP_APPEND_NFS=""
    case "$DIST_NAME_TYPE" in
    "gentoo")
            FLG_NFS=1
            TFTP_APPEND_INITRD="initrd=${DIST_MOUNTPOINT}/isolinux/gentoo.igz"
            TFTP_APPEND_NFS="root=/dev/ram0 loop=/image.squashfs init=/linuxrc looptype=squashfs cdroot=1 real_root=/dev/nfs console=tty1 dokeymap netboot=nfs nfsroot=${DIST_NFSIP}:${TFTP_ROOT}/${DIST_MOUNTPOINT}"
            #TFTP_APPEND_OTHER=" ${TFTP_APPEND_OTHER}"
            TFTP_KERNEL="KERNEL ${DIST_MOUNTPOINT}/isolinux/gentoo"
            ;;

    "doudoulinux")
        # debian based live cd
        FLG_NFS=1
        TFTP_APPEND_INITRD="initrd=${DIST_MOUNTPOINT}/live/initrd.img"
        TFTP_APPEND_NFS="root=/dev/nfs boot=live config netboot=nfs nfsroot=${DIST_NFSIP}:${TFTP_ROOT}/${DIST_MOUNTPOINT}  locales=zh_CN.UTF-8 nox11autologin splash nomodeset video=uvesafb:mode_option=640x480-16,mtrr=3,scroll=ywrap live-media=removable persistent persistent-subtext=doudoulinux username=tux hostname=doudoulinux  quiet"
        #TFTP_APPEND_OTHER=" ${TFTP_APPEND_OTHER}"
        TFTP_KERNEL="KERNEL ${DIST_MOUNTPOINT}/live/vmlinuz"

        # automaticly check the name of the 'vmlinuz'
        A=$(detect_vmlinu_initrd "${DIST_MOUNTPOINT}" "${DIST_FILE}" "${TFTP_ROOT}" "${DEFAULT_BOOTIMG_DIRS}")
        B=$(echo ${A} | awk '{print $1}' )
        TFTP_KERNEL="KERNEL ${B}"
        B=$(echo ${A} | awk '{print $2}' )
        TFTP_APPEND_INITRD="initrd=${B}"
        ;;

    "debian")
        echo "[DBG] dist debian" >> "/dev/stderr"
        case "$DIST_TYPE" in
        "server")
            ;;
        "live")
            FLG_NFS=1
            TFTP_APPEND_INITRD="initrd=${DIST_MOUNTPOINT}/live/initrd1.img"
            TFTP_APPEND_NFS="root=/dev/nfs boot=live live-config netboot=nfs nfsroot=${DIST_NFSIP}:${TFTP_ROOT}/${DIST_MOUNTPOINT}"
            #TFTP_APPEND_OTHER=" ${TFTP_APPEND_OTHER}"
            TFTP_KERNEL="KERNEL ${DIST_MOUNTPOINT}/live/vmlinuz1"
            ;;
        *)
            echo "[ERR] Not supported ubuntu type: ${DIST_TYPE}" >> "/dev/stderr"
            exit 0
            ;;
        esac
        ;;

    "ubuntu"|"edubuntu")
        echo "[DBG] dist ubuntu" >> "/dev/stderr"
        case "$DIST_TYPE" in
        "server") # server, alternate
            echo "[DBG] type server" >> "/dev/stderr"
            FLG_NFS=0
            TFTP_APPEND_INITRD="initrd=${DIST_MOUNTPOINT}/install/netboot/ubuntu-installer/${DIST_ARCH}/initrd.gz"
            TFTP_APPEND_NFS=""
            TFTP_KERNEL="KERNEL ${DIST_MOUNTPOINT}/install/netboot/ubuntu-installer/${DIST_ARCH}/linux"

            if [ ! -f "${TFTP_ROOT}/${DIST_MOUNTPOINT}/install/netboot/ubuntu-installer/${DIST_ARCH}/linux" ]; then
                for i in $(find "${TFTP_ROOT}/${DIST_MOUNTPOINT}/install/netboot/ubuntu-installer/${DIST_ARCH}/" -name "*linu*" ) ; do
                    TFTP_KERNEL="KERNEL ${DIST_MOUNTPOINT}/install/netboot/ubuntu-installer/${DIST_ARCH}/$(basename $i)"
                done
            fi
            if [ ! -f "${TFTP_ROOT}/${DIST_MOUNTPOINT}/install/netboot/ubuntu-installer/${DIST_ARCH}/initrd.gz" ]; then
                for i in $(find "${TFTP_ROOT}/${DIST_MOUNTPOINT}/install/netboot/ubuntu-installer/${DIST_ARCH}/" -name "initrd*" ) ; do
                    TFTP_APPEND_INITRD="initrd=${DIST_MOUNTPOINT}/install/netboot/ubuntu-installer/${DIST_ARCH}/$(basename $i)"
                done
            fi

            # for 12 or later
            TFTP_APPEND_NFS="mirror/country=manual mirror/http/hostname=${DIST_NFSIP} mirror/http/directory=/${DIST_MOUNTPOINT} live-installer/net-image=http://${DIST_NFSIP}/${DIST_MOUNTPOINT}/install/filesystem.squashfs"

            if [ "${FLG_NON_PAE}" = "1" ]; then

#TFTP_ROOT="/home/yhfu/homegw/var/lib/tftpboot"
#DIST_MOUNTPOINT="images-server/ubuntu/13.04/i386"
#URL_INITRD="http://bazaar.launchpad.net/~webtom/+junk/linux-image-i386-non-pae/download/head:/initrd3.8.019wtnonpa-20130429091312-e20cgo6obhlyk3fi-1/initrd-3.8.0-19-wt-non-pae_3.8.0-19.29_i386.lz"

#cp "${TFTP_ROOT}/${DIST_MOUNTPOINT}/install/netboot/ubuntu-installer/i386/initrd.gz" cd-initrd.gz
#cp "${TFTP_ROOT}/downloads/$(basename ${URL_INITRD})" url-initrd.lz

#mkdir cd
#cd cd
#gzip -dc ../cd-initrd.gz | cpio -id
#cd ..

#mkdir url
#cd url
#lzma -dc -S .lz ../url-initrd.lz | cpio -id
#cd ..

#cp -rp url/lib/modules/  cd/lib/
#cp -rp url/lib/firmware/ cd/lib/

#cd cd
#find . | cpio --quiet --dereference -o -H newc | gzip -9 > ../new-initrd.gz
## find . | cpio --quiet --dereference -o -H newc | lzma -7 > ../new-initrd.lz
#cd ..


                URL_INITRD="http://${DIST_NFSIP}/initrd-3.8.0-19-wt-non-pae_3.8.0-19.29_i386.gz"
                URL_VMLINUZ="http://bazaar.launchpad.net/~webtom/+junk/linux-image-i386-non-pae/download/head:/vmlinuz3.8.019wtnonp-20130429091312-e20cgo6obhlyk3fi-5/vmlinuz-3.8.0-19-wt-non-pae_3.8.0-19.29_i386"
                TFTP_KERNEL="KERNEL downloads/$(basename ${URL_VMLINUZ})"
                TFTP_APPEND_INITRD="initrd=downloads/$(basename ${URL_INITRD})"
            fi
            ;;

        "desktop")
            # desktop, live?
            FLG_NFS=1
            TFTP_APPEND_INITRD="initrd=${DIST_MOUNTPOINT}/casper/initrd.lz"
            TFTP_APPEND_NFS="root=/dev/nfs boot=casper netboot=nfs nfsroot=${DIST_NFSIP}:${TFTP_ROOT}/${DIST_MOUNTPOINT}"
            #TFTP_APPEND_OTHER=" ${TFTP_APPEND_OTHER}"
            TFTP_KERNEL="KERNEL ${DIST_MOUNTPOINT}/casper/vmlinuz"

            # automaticly check the name of the 'vmlinuz'
            A=$(detect_vmlinu_initrd "${DIST_MOUNTPOINT}" "${DIST_FILE}" "${TFTP_ROOT}" "${DEFAULT_BOOTIMG_DIRS}")
            B=$(echo ${A} | awk '{print $1}' )
            TFTP_KERNEL="KERNEL ${B}"
            B=$(echo ${A} | awk '{print $2}' )
            TFTP_APPEND_INITRD="initrd=${B}"

            if [ "${FLG_NON_PAE}" = "1" ]; then
              URL_VMLINUZ=
              if [ $(echo | awk -v VER=$DIST_RELEASE '{ if (VER < 11) print 1; else print 0; }') = 1 ]; then
                echo "Ubuntu 10 or lower support non-PAE. No need to use special steps" >> "${FN_TMP_LASTMSG}"
              #elif [ $(echo | awk -v VER=$DIST_RELEASE '{ if (VER < 12) print 1; else print 0; }') = 1 ]; then
                ## version 11.x
                #echo ""
              elif [ $(echo | awk -v VER=$DIST_RELEASE '{ if (VER < 13) print 1; else print 0; }') = 1 ]; then
                # version 12.x
                URL_VMLINUZ="http://bazaar.launchpad.net/~webtom/+junk/linux-image-i386-non-pae/download/head:/vmlinuz3.5.017wtnonp-20121104150059-2ifucieir3hr7d7r-1/vmlinuz-3.5.0-17-wt-non-pae_3.5.0-17.28_i386"
                URL_INITRD="http://bazaar.launchpad.net/~webtom/+junk/linux-image-i386-non-pae/download/head:/initrd3.5.017wtnonpa-20121104150054-x38900ty5mmg8bub-1/initrd-3.5.0-17-wt-non-pae_3.5.0-17.28_i386.lz"
                URL_PKG1="http://bazaar.launchpad.net/~webtom/+junk/linux-image-i386-non-pae/download/head:/linuximage3.5.027wtn-20130411174046-2g7c1jtopun2y43m-1/linux-image-3.5.0-27-wt-non-pae_3.5.0-27.46_i386.deb"
                URL_PKG2="http://bazaar.launchpad.net/~webtom/+junk/linux-image-i386-non-pae/download/head:/linuxheaders3.5.027w-20130411174046-2g7c1jtopun2y43m-3/linux-headers-3.5.0-27-wt-non-pae_3.5.0-27.46_i386.deb"
                URL_PKG3="http://bazaar.launchpad.net/~webtom/+junk/linux-image-i386-non-pae/download/head:/linuxheaders3.5.027_-20130411174046-2g7c1jtopun2y43m-2/linux-headers-3.5.0-27_3.5.0-27.46_all.deb"

              elif [ $(echo | awk -v VER=$DIST_RELEASE '{ if (VER < 14) print 1; else print 0; }') = 1 ]; then
                # version 13.x
                URL_INITRD="http://bazaar.launchpad.net/~webtom/+junk/linux-image-i386-non-pae/download/head:/initrd3.8.019wtnonpa-20130429091312-e20cgo6obhlyk3fi-1/initrd-3.8.0-19-wt-non-pae_3.8.0-19.29_i386.lz"
                URL_VMLINUZ="http://bazaar.launchpad.net/~webtom/+junk/linux-image-i386-non-pae/download/head:/vmlinuz3.8.019wtnonp-20130429091312-e20cgo6obhlyk3fi-5/vmlinuz-3.8.0-19-wt-non-pae_3.8.0-19.29_i386"
                URL_PKG1="http://bazaar.launchpad.net/~webtom/+junk/linux-image-i386-non-pae/download/head:/linuximage3.8.019wtn-20130503212031-gaxgocw9r3bsn1mo-3/linux-image-3.8.0-19-wt-non-pae_3.8.0-19.30_i386.deb"
                URL_PKG2="http://bazaar.launchpad.net/~webtom/+junk/linux-image-i386-non-pae/download/head:/linuxheaders3.8.019w-20130503212031-gaxgocw9r3bsn1mo-2/linux-headers-3.8.0-19-wt-non-pae_3.8.0-19.30_i386.deb"
                URL_PKG3="http://bazaar.launchpad.net/~webtom/+junk/linux-image-i386-non-pae/download/head:/linuxheaders3.8.019_-20130503212031-gaxgocw9r3bsn1mo-1/linux-headers-3.8.0-19_3.8.0-19.30_all.deb"
              fi
              if [ ! "${URL_VMLINUZ}" = "" ]; then
                $MYEXEC mkdir -p "${TFTP_ROOT}/downloads/"
                $MYEXEC mkdir -p "${TFTP_ROOT}/kickstarts/"
                $MYEXEC cd "${TFTP_ROOT}/netboot/"
                $MYEXEC ln -s "../downloads/"
                $MYEXEC ln -s "../kickstarts/"
                #$MYEXEC down_url "${URL_INITRD}"
                #$MYEXEC down_url "${URL_VMLINUZ}"
                #$MYEXEC down_url "${URL_PKG1}"
                #$MYEXEC down_url "${URL_PKG2}"
                #$MYEXEC down_url "${URL_PKG3}"
                $MYEXEC wget --no-check-certificate -c "${URL_INITRD}"  -O "${TFTP_ROOT}/downloads/$(basename ${URL_INITRD})"
                $MYEXEC wget --no-check-certificate -c "${URL_VMLINUZ}" -O "${TFTP_ROOT}/downloads/$(basename ${URL_VMLINUZ})"
                $MYEXEC wget --no-check-certificate -c "${URL_PKG1}"    -O "${TFTP_ROOT}/downloads/$(basename ${URL_PKG1})"
                $MYEXEC wget --no-check-certificate -c "${URL_PKG2}"    -O "${TFTP_ROOT}/downloads/$(basename ${URL_PKG2})"
                $MYEXEC wget --no-check-certificate -c "${URL_PKG3}"    -O "${TFTP_ROOT}/downloads/$(basename ${URL_PKG3})"

                TFTP_APPEND_INITRD="initrd=downloads/$(basename ${URL_INITRD})"
                #TFTP_APPEND_OTHER="nosplash ${TFTP_APPEND_OTHER}"
                TFTP_KERNEL="KERNEL downloads/$(basename ${URL_VMLINUZ})"
                TFTP_MENU_LABEL="${TFTP_MENU_LABEL} non-PAE"
                TFTP_TAG_LABEL="${TFTP_TAG_LABEL}_nonpae"
                # kickstart:
                FN_KS="ks-${DIST_NAME}-${DIST_RELEASE}-${DIST_ARCH}-${DIST_TYPE}-nonpae.ks"
                cat << EOF > "${TFTP_ROOT}/kickstarts/${FN_KS}"
%post
#wget --no-check-certificate "http://${DIST_NFSIP}/downloads/$(basename ${URL_PKG1})"
#wget --no-check-certificate "http://${DIST_NFSIP}/downloads/$(basename ${URL_PKG2})"
#wget --no-check-certificate "http://${DIST_NFSIP}/downloads/$(basename ${URL_PKG3})"

wget --no-check-certificate "${URL_PKG1}"
wget --no-check-certificate "${URL_PKG2}"
wget --no-check-certificate "${URL_PKG3}"

dpkg --root=/target -i $(basename ${URL_PKG1})
dpkg --root=/target -i $(basename ${URL_PKG2})
dpkg --root=/target -i $(basename ${URL_PKG3})
%end
EOF
                TFTP_APPEND_OTHER="ks=http://${DIST_NFSIP}/kickstarts/${FN_KS} ${TFTP_APPEND_OTHER}"
                echo "You may want to install non-PAE Linux kernel before the system reboots:" >> "${FN_TMP_LASTMSG}"
                echo "  (press ALT+CTRL+F1 to switch to the console)" >> "${FN_TMP_LASTMSG}"
                echo "    wget '${URL_PKG1}'" >> "${FN_TMP_LASTMSG}"
                echo "    wget '${URL_PKG2}'" >> "${FN_TMP_LASTMSG}"
                echo "    wget '${URL_PKG3}'" >> "${FN_TMP_LASTMSG}"
                echo "    dpkg --root=/target -i $(basename ${URL_PKG1})" >> "${FN_TMP_LASTMSG}"
                echo "    dpkg --root=/target -i $(basename ${URL_PKG2})" >> "${FN_TMP_LASTMSG}"
                echo "    dpkg --root=/target -i $(basename ${URL_PKG3})" >> "${FN_TMP_LASTMSG}"
                FLG_NON_PAE_PROCESSED=1

              fi
            fi
            ;;

        "net")
            # netinstall
            FLG_NFS=0
            TFTP_APPEND_INITRD="initrd=${DIST_MOUNTPOINT}/initrd.gz"
            TFTP_APPEND_NFS=""
            #TFTP_APPEND_OTHER=" ${TFTP_APPEND_OTHER}"
            TFTP_KERNEL="KERNEL ${DIST_MOUNTPOINT}/linux"
            ;;

        *)
            echo "[ERR] Not supported ubuntu type: ${DIST_TYPE}" >> "/dev/stderr"
            exit 0
            ;;
        esac
        ;;

    "backtrack")
        FLG_NFS=1
        echo "[DBG] dist backtrack" >> "/dev/stderr"
        case "$DIST_TYPE" in
        "oldlive")
            TFTP_APPEND_INITRD="initrd=${DIST_MOUNTPOINT}/boot/initrd.gz"
            TFTP_APPEND_NFS="BOOT=casper boot=casper nopersistent rw quite vga=0x317 netboot=nfs nfsroot=${DIST_NFSIP}:${TFTP_ROOT}/${DIST_MOUNTPOINT}"
            #TFTP_APPEND_OTHER=" ${TFTP_APPEND_OTHER}"
            TFTP_KERNEL="KERNEL ${DIST_MOUNTPOINT}/boot/vmlinuz"
            ;;

        "live")
            TFTP_APPEND_INITRD="initrd=${DIST_MOUNTPOINT}/casper/initrd.gz"
            TFTP_APPEND_NFS="boot=casper netboot=nfs nfsroot=${DIST_NFSIP}:${TFTP_ROOT}/${DIST_MOUNTPOINT}"
            #TFTP_APPEND_OTHER=" ${TFTP_APPEND_OTHER}"
            TFTP_KERNEL="KERNEL ${DIST_MOUNTPOINT}/casper/vmlinuz"
            ;;

        *)
            echo "[ERR] Not supported BT type: ${DIST_TYPE}" >> "/dev/stderr"
            exit 0
            ;;
        esac
        ;;

    "kali")
        echo "[DBG] dist kali, type=$DIST_TYPE" >> "/dev/stderr"
        case "$DIST_TYPE" in
        "net"|"mini")
            FLG_NFS=0
            TFTP_APPEND_INITRD="initrd=${DIST_MOUNTPOINT}/initrd.gz"
            TFTP_KERNEL="KERNEL ${DIST_MOUNTPOINT}/linux"
            ;;
        "live")
            FLG_NFS=1
            # ISO: it's not feasible, the size of iso is larger than 2 GB.
            #TFTP_APPEND_INITRD="iso raw"
            #TFTP_KERNEL="KERNEL memdisk\n    INITRD downloads/${ISO_NAME}"

            # NFS:
            TFTP_APPEND_INITRD="initrd=${DIST_MOUNTPOINT}/live/initrd.img"
            TFTP_APPEND_NFS="noconfig=sudo username=root hostname=kali root=/dev/nfs boot=live netboot=nfs nfsroot=${DIST_NFSIP}:${TFTP_ROOT}/${DIST_MOUNTPOINT}"
            TFTP_KERNEL="KERNEL ${DIST_MOUNTPOINT}/live/vmlinuz"

            FLG_DOWNKALIFIX=0
            FN_INITRD=
            URL_INITRD=
            $MYEXEC mkdir -p "${TFTP_ROOT}/downloads/kali1-fix/"
            case "$DIST_RELEASE" in
            "1.0.3")
                FLG_NFS=1
                if [ "${DIST_ARCH}" = "i386" ]; then
                    FN_INITRD=initrd-kali-1.0.3-3.7-trunk-686-pae.img
                    URL_INITRD="https://www.hashdump.org/files/initrd.img"
                    echo "[WARNING] Use the i386 patch from" >> "/dev/stderr"
                    echo "[WARNING]     https://wiki.hashdump.org/index.php/PXE::Kali" >> "/dev/stderr"
                else
                    echo "[ERR] Unable to boot from NFS,  please see" >> "/dev/stderr"
                    echo "[ERR]    https://wiki.hashdump.org/index.php/PXE::Kali" >> "/dev/stderr"
                    echo "[ERR]    for solution." >> "/dev/stderr"
                    exit 0
                    FN_INITRD=initrd-kali-1.0.3-3.7-trunk-amd64.img
                    URL_INITRD="https://downloads.pxe-linux-iso.googlecode.com/git/patches/kali/${FN_INITRD}"
                fi
                DN_SAVE_INITRD="${TFTP_ROOT}/downloads/kali1-fix/"
                $MYEXEC mkdir -p "${DN_SAVE_INITRD}"
                $MYEXEC down_url  "${URL_INITRD}" "${DN_SAVE_INITRD}/${FN_INITRD}"
                TFTP_APPEND_INITRD="initrd=downloads/kali1-fix/${FN_INITRD}"
                ;;

            "1.0.4")
                FLG_NFS=1
                FLG_DOWNKALIFIX=1
                if [ "${DIST_ARCH}" = "i386" ]; then
                    FN_INITRD=initrd-kali-1.0.4-3.7-trunk-686-pae.img
                else
                    FN_INITRD=initrd-kali-1.0.4-3.7-trunk-amd64.img
                fi
                URL_INITRD="https://downloads.pxe-linux-iso.googlecode.com/git/patches/kali/${FN_INITRD}"
                echo "[DBG] kali 1.0.4, URL=${URL_INITRD}, INITRD=${FN_INITRD}"
                ;;

            #"1.1.0")
                #FLG_NFS=1
                #FLG_DOWNKALIFIX=1
                #if [ "${DIST_ARCH}" = "i386" ]; then
                    #FN_INITRD=initrd-kali-1.1.0-3.18.0-kali1-686-pae.img
                #else
                    #FN_INITRD=initrd-kali-1.1.0-3.18.0-kali1-amd64.img
                #fi
                #URL_INITRD="https://downloads.pxe-linux-iso.googlecode.com/git/patches/kali/${FN_INITRD}"
                #echo "[DBG] kali 1.1.0, URL=${URL_INITRD}, INITRD=${FN_INITRD}"
                #;;

            esac
            if [ "${FLG_DOWNKALIFIX}" = "1" ]; then
                echo "[WARNING] Use the ${DIST_ARCH} patch from" >> "/dev/stderr"
                echo "[WARNING]     ${URL_INITRD}" >> "/dev/stderr"

                DN_SAVE_INITRD="${TFTP_ROOT}/downloads/kali1-fix/"
                $MYEXEC mkdir -p "${DN_SAVE_INITRD}"
                $MYEXEC down_url  "${URL_INITRD}" "${DN_SAVE_INITRD}/${FN_INITRD}"
                TFTP_APPEND_INITRD="initrd=downloads/kali1-fix/${FN_INITRD}"
                if [ "${FLG_NON_PAE}" = "1" ]; then
                    echo "Not support Kali non-PAE kernel at present," >> "${FN_TMP_LASTMSG}"
                    echo "You may ask the author to add it in, or" >> "${FN_TMP_LASTMSG}"
                    echo "you want to read this to compile kernel by yourself:" >> "${FN_TMP_LASTMSG}"
                    echo "http://docs.kali.org/pdf/kali-book-en.pdf" >> "${FN_TMP_LASTMSG}"
                    echo "http://samiux.blogspot.com/2013/03/howto-rebuild-kali-linux-101.html" >> "${FN_TMP_LASTMSG}"

#apt-get install git live-build cdebootstrap kali-archive-keyring
#git clone git://git.kali.org/live-build-config.git
#cd live-build-config
#sed -i 's/686-pae/486/g' auto/config
#lb clean
#lb config --architecture i386
#lb build

                fi
            fi
            ;;
        esac
        ;;

    "fedora")
        echo "[DBG] dist fedora" >> "/dev/stderr"
        case "$DIST_TYPE" in
        "desktop"|"live")
            #FLG_NFS=1
            FLG_NFS=0
            TFTP_APPEND_INITRD="initrd=${DIST_MOUNTPOINT}/isolinux/initrd0.img"
            #TFTP_APPEND_NFS="root=/dev/nfs boot=casper netboot=nfs nfsroot=${DIST_NFSIP}:${TFTP_ROOT}/${DIST_MOUNTPOINT}"
            #TFTP_APPEND_OTHER=" ${TFTP_APPEND_OTHER}"
            TFTP_KERNEL="KERNEL ${DIST_MOUNTPOINT}/isolinux/vmlinuz0"

            # automaticly check the name of the 'vmlinuz'
            A=$(detect_vmlinu_initrd "${DIST_MOUNTPOINT}" "${DIST_FILE}" "${TFTP_ROOT}" "${DEFAULT_BOOTIMG_DIRS}")
            B=$(echo ${A} | awk '{print $1}' )
            TFTP_KERNEL="KERNEL ${B}"
            B=$(echo ${A} | awk '{print $2}' )
            TFTP_APPEND_INITRD="initrd=${B} repo=http://${DIST_NFSIP}/${DIST_MOUNTPOINT}/ live:http://${DIST_NFSIP}/${DIST_MOUNTPOINT}/LiveOS/squashfs.img"
            ;;
        *)
            echo "[ERR] Not supported fedora type: ${DIST_TYPE}" >> "/dev/stderr"
            exit 0
            ;;
        esac
        ;;

    "centos")
        case "$DIST_TYPE" in
        "server")
            FLG_NFS=1
            TFTP_APPEND_INITRD="initrd=${DIST_MOUNTPOINT}/isolinux/initrd.img"
            TFTP_APPEND_NFS=""
            #TFTP_APPEND_OTHER=" ${TFTP_APPEND_OTHER}"
            TFTP_KERNEL="KERNEL ${DIST_MOUNTPOINT}/isolinux/vmlinuz"
            ;;
        "net")
            # netinstall
            FLG_NFS=0

            TFTP_APPEND_NFS=""
            #TFTP_APPEND_OTHER=" ${TFTP_APPEND_OTHER}"

            # automaticly check the name of the 'vmlinuz'
            A=$(detect_vmlinu_initrd "${DIST_MOUNTPOINT}" "${DIST_FILE}" "${TFTP_ROOT}" "${DEFAULT_BOOTIMG_DIRS}")
            B=$(echo ${A} | awk '{print $1}' )
            TFTP_KERNEL="KERNEL ${B}"
            B=$(echo ${A} | awk '{print $2}' )
            TFTP_APPEND_INITRD="initrd=${B}"
            ;;
        "desktop"|"live")
            FLG_NFS=1
            TFTP_APPEND_INITRD="initrd=${DIST_MOUNTPOINT}/isolinux/initrd0.img"
            TFTP_APPEND_NFS="root=/dev/nfs boot=casper netboot=nfs nfsroot=${DIST_NFSIP}:${TFTP_ROOT}/${DIST_MOUNTPOINT}"
            #TFTP_APPEND_OTHER=" ${TFTP_APPEND_OTHER}"
            TFTP_KERNEL="KERNEL ${DIST_MOUNTPOINT}/isolinux/vmlinuz0"
            ;;
        *)
            echo "[ERR] Not supported centos type: ${DIST_TYPE}" >> "/dev/stderr"
            exit 0
            ;;
        esac
        ;;

    "arch")
            # dual option 1: load ISO to memory
            # all of the command lines are passed
            cat << EOF > "${FN_TMP_TFTPMENU}"
LABEL ${TFTP_TAG_LABEL}_iso
    MENU LABEL ${TFTP_MENU_LABEL} (ISO)
    KERNEL memdisk
    #LINUX memdisk
    INITRD downloads/${ISO_NAME}
    #APPEND iso
    APPEND iso raw
EOF

            # dual option 2-1: NFS i686 
            FLG_NFS=1
            ITYPE="i686"
            TFTP_APPEND_INITRD="initrd=${DIST_MOUNTPOINT}/arch/boot/${ITYPE}/archiso.img"
            #TFTP_APPEND_NFS="root=/dev/nfs boot=casper netboot=nfs nfsroot=${DIST_NFSIP}:${TFTP_ROOT}/${DIST_MOUNTPOINT}"
            TFTP_APPEND_NFS="archisobasedir=arch archiso_nfs_srv=${DIST_NFSIP}:${TFTP_ROOT}/${DIST_MOUNTPOINT} ip=:::::eth0:dhcp -"
            TFTP_APPEND_HTTP="archiso_http_srv=http://${DIST_NFSIP}:${TFTP_ROOT}/${DIST_MOUNTPOINT}"
            TFTP_APPEND_OTHER="arch=i686"
            TFTP_KERNEL="KERNEL ${DIST_MOUNTPOINT}/arch/boot/${ITYPE}/vmlinuz"
            TFTP_APPEND="APPEND ${TFTP_APPEND_INITRD} ${TFTP_APPEND_NFS} ${TFTP_APPEND_OTHER}"

            cat << EOF >> "${FN_TMP_TFTPMENU}"
LABEL ${TFTP_TAG_LABEL}_i686
    MENU LABEL ${TFTP_MENU_LABEL} (i686)
    ${TFTP_KERNEL}
    ${TFTP_APPEND}
EOF

            # dual option 2-2: NFS x86_64
            ITYPE="x86_64"
            TFTP_APPEND_INITRD="initrd=${DIST_MOUNTPOINT}/arch/boot/${ITYPE}/archiso.img"
            TFTP_APPEND_NFS="archisobasedir=arch archiso_nfs_srv=${DIST_NFSIP}:${TFTP_ROOT}/${DIST_MOUNTPOINT} ip=:::::eth0:dhcp -"
            TFTP_APPEND_OTHER=""
            TFTP_KERNEL="KERNEL ${DIST_MOUNTPOINT}/arch/boot/${ITYPE}/vmlinuz"
            #TFTP_APPEND="APPEND ${TFTP_APPEND_INITRD} ${TFTP_APPEND_NFS} ${TFTP_APPEND_OTHER}"
            TFTP_MENU_LABEL="${TFTP_MENU_LABEL} (x86_64)"

            # or http?
            # TFTP_APPEND_NFS="archisobasedir=arch archiso_pxe_http=${DIST_NFSIP}/${DIST_MOUNTPOINT} ip=:::::eth0:dhcp -"
        ;;

    "archassault"|"blackarchlinux"|"evolution")
            #FLG_MOUNT=0
            #echo "archassault|blackarchlinux|evolution is not support PXE?"
            FLG_NFS=1
            ITYPE="${DIST_ARCH}"
            TFTP_APPEND_INITRD="initrd=${DIST_MOUNTPOINT}/arch/boot/${ITYPE}/archiso.img"
            TFTP_APPEND_NFS="archisobasedir=arch archiso_nfs_srv=${DIST_NFSIP}:${TFTP_ROOT}/${DIST_MOUNTPOINT} ip=:::::eth0:dhcp -"
            TFTP_APPEND_HTTP="archiso_http_srv=http://${DIST_NFSIP}:${TFTP_ROOT}/${DIST_MOUNTPOINT}"
            TFTP_APPEND_OTHER="arch=${DIST_ARCH}"
            TFTP_KERNEL="KERNEL ${DIST_MOUNTPOINT}/arch/boot/${ITYPE}/vmlinuz"

            # automaticly check the name of the 'vmlinuz'
            A=$(detect_vmlinu_initrd "${DIST_MOUNTPOINT}" "${DIST_FILE}" "${TFTP_ROOT}" "arch/boot ${DEFAULT_BOOTIMG_DIRS}")
            B=$(echo ${A} | awk '{print $1}' )
            TFTP_KERNEL="KERNEL ${B}"
        ;;

    "tinycore")
        case "$DIST_TYPE" in
        "plus")
            TFTP_KERNEL="KERNEL ${DIST_MOUNTPOINT}/boot/vmlinuz"
            TFTP_APPEND_INITRD="initrd=${DIST_MOUNTPOINT}/boot/core.gz"
            DNR_TCE="cde/optional"
            ;;
        *)
            TFTP_KERNEL="KERNEL ${DIST_MOUNTPOINT}/boot/bzImage"
            TFTP_APPEND_INITRD="initrd=${DIST_MOUNTPOINT}/boot/tinycore.gz"
            DNR_TCE="tce"
            ;;
        esac

        DNR_TINYCORE="downloads/tinycore-fix/"
        $MYEXEC mkdir -p "${DN_SAVE_INITRD}"
        FN_NFSUTILS=tinycore-${DIST_RELEASE}-nfs-utils.tcz
        $MYEXEC down_url "http://tinycorelinux.net/4.x/${DIST_ARCH}/tcz/nfs-utils.tcz" "${TFTP_ROOT}/${DNR_TINYCORE}/${FN_NFSUTILS}"
        echo "/${DNR_TINYCORE}/${FN_NFSUTILS}" > "${TFTP_ROOT}/${DNR_TINYCORE}/${ISO_NAME}-nfs.list"
        TFTP_APPEND_NFS="nfsmount=${DIST_NFSIP}:${TFTP_ROOT}/${DIST_MOUNTPOINT} tftplist=${DIST_NFSIP}:/${DNR_TINYCORE}/${ISO_NAME}-nfs.list tce=${DNR_TINYCORE}"

        ;;

    "clonezilla")
        echo "[DBG] dist fedora" >> "/dev/stderr"
        case "$DIST_TYPE" in
        "live")
            # http://clonezilla.org/livepxe.php
            FLG_NFS=0
            TFTP_APPEND_INITRD="initrd=${DIST_MOUNTPOINT}/live/initrd.img"
            TFTP_APPEND_NFS=""
            TFTP_APPEND_OTHER="boot=live config noswap nolocales edd=on nomodeset ocs_live_run=\"ocs-live-general\" ocs_live_extra_param=\"\" keyboard-layouts=\"\" ocs_live_batch=\"no\" locales=\"\" vga=788 nosplash noprompt fetch=tftp://${DIST_NFSIP}/${DIST_MOUNTPOINT}/live/filesystem.squashfs"
            TFTP_KERNEL="KERNEL ${DIST_MOUNTPOINT}/live/vmlinuz"
            ;;
        *)
            echo "[ERR] Not supported fedora type: ${DIST_TYPE}" >> "/dev/stderr"
            exit 0
            ;;
        esac
        ;;

    "puppy")
        # http://vercot.com/~serva/an/NonWindowsPXE3.html
        #$MYEXEC wget -c http://vercot.com/~serva/download/INITRD_N01.GZ -O ${TFTP_ROOT}/downloads/puppy-initrd_n01.gz
        #cat << EOF > "${FN_TMP_TFTPMENU}"
#LABEL ${TFTP_TAG_LABEL}_iso
    #MENU LABEL ${TFTP_MENU_LABEL}
    #IPAPPEND 2
    #KERNEL ${DIST_MOUNTPOINT}/vmlinuz
    #INITRD ${DIST_MOUNTPOINT}/initrd.gz,downloads/puppy-initrd_n01.gz
    #APPEND netpath=http://${DIST_NFSIP}/${DIST_MOUNTPOINT}/
#EOF
        check_install_package "$(which cpio)" cpio
        $MYEXEC rm -rf ${TFTP_ROOT}/temp
        $MYEXEC mkdir ${TFTP_ROOT}/temp
        $MYEXEC cd ${TFTP_ROOT}/temp
        zcat ${TFTP_ROOT}/${DIST_MOUNTPOINT}/initrd.gz | cpio -i -d
        $MYEXEC cp ${TFTP_ROOT}/${DIST_MOUNTPOINT}/*.sfs ${TFTP_ROOT}/temp/
        find . | cpio -o -H newc | gzip -4 > ${TFTP_ROOT}/downloads/${DIST_NAME}-${DIST_ARCH}-${DIST_RELEASE}-initrd.gz
        $MYEXEC cd ..
        $MYEXEC rm -rf ${TFTP_ROOT}/temp
        $MYEXEC cp ${TFTP_ROOT}/${DIST_MOUNTPOINT}/vmlinuz ${TFTP_ROOT}/downloads/${DIST_NAME}-${DIST_ARCH}-${DIST_RELEASE}-vmlinuz
        $MYEXEC umount ${TFTP_ROOT}/${DIST_MOUNTPOINT}
        TFTP_KERNEL="KERNEL downloads/${DIST_NAME}-${DIST_ARCH}-${DIST_RELEASE}-vmlinuz"
        TFTP_APPEND_INITRD="initrd=downloads/${DIST_NAME}-${DIST_ARCH}-${DIST_RELEASE}-initrd.gz"
        ;;

    *)
        echo "[ERR] Not supported distribution: ${DIST_NAME}" >> "/dev/stderr"
        FLG_MOUNT=0
        #exit 0
        ;;
    esac

    if [ "${FLG_MOUNT}" = "1" ]; then
        TFTP_APPEND="APPEND ${TFTP_APPEND_INITRD} ${TFTP_APPEND_NFS} ${TFTP_APPEND_OTHER}"
        cat << EOF >> "${FN_TMP_TFTPMENU}"
LABEL ${TFTP_TAG_LABEL}
    MENU LABEL ${TFTP_MENU_LABEL}
    ${TFTP_KERNEL}
    ${TFTP_APPEND}
EOF
    else
        cat << EOF > "${FN_TMP_TFTPMENU}"
LABEL ${TFTP_TAG_LABEL}_iso
    MENU LABEL ${TFTP_MENU_LABEL}
    KERNEL memdisk
    INITRD downloads/${ISO_NAME}
    APPEND iso raw
EOF
        # FIXME: the iso file has to be the real file, and should exists at the same folder as pxelinux.0
    fi

    if [ "${FLG_MOUNT}" = "1" ]; then
        echo "${DIST_FILE} ${TFTP_ROOT}/${DIST_MOUNTPOINT} udf,iso9660 auto,user,loop,utf8 0 0" > "${FN_TMP_ETCFSTAB}"
    fi
    if [ "${FLG_NFS}" = "1" ]; then
        echo "${TFTP_ROOT}/${DIST_MOUNTPOINT} *(ro,sync,no_wdelay,insecure_locks,no_subtree_check,no_root_squash,insecure)" > "${FN_TMP_ETCEXPORTS}"
    fi

    if [ "${FLG_MOUNT}" = "1" ]; then
        echo "[INFO] ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++" >> "/dev/stderr"
        echo "[INFO] You may want to mount the ISO by manual to test the file:" >> "/dev/stderr"
        echo "[INFO]   mkdir -p '${TFTP_ROOT}/${DIST_MOUNTPOINT}'" >> "/dev/stderr"
        echo "[INFO]   mount -o loop,utf8 '${DIST_FILE}' '${TFTP_ROOT}/${DIST_MOUNTPOINT}'" >> "/dev/stderr"
        echo "[INFO] The following content will be attached to the file '/etc/fstab':" >> "/dev/stderr"
        echo "" >> "/dev/stderr"
        cat "${FN_TMP_ETCFSTAB}" >> "/dev/stderr"
        echo "" >> "/dev/stderr"
        echo "[INFO] ==============================================================" >> "/dev/stderr"
    fi

    if [ "${FLG_NFS}" = "1" ]; then
        echo "[INFO] ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++" >> "/dev/stderr"
        echo "[INFO] The following content will be attached to the file '/etc/exports':" >> "/dev/stderr"
        echo "" >> "/dev/stderr"
        cat "${FN_TMP_ETCEXPORTS}" >> "/dev/stderr"
        echo "" >> "/dev/stderr"
        echo "[INFO] ==============================================================" >> "/dev/stderr"
    fi

    echo "[INFO] ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++" >> "/dev/stderr"
    echo "[INFO] The following content will be attached to the file" >> "/dev/stderr"
    echo "[INFO]    '${TFTP_ROOT}/netboot/pxelinux.cfg/default':" >> "/dev/stderr"
    echo "" >> "/dev/stderr"
    cat "${FN_TMP_TFTPMENU}" >> "/dev/stderr"
    echo "" >> "/dev/stderr"
    echo "[INFO] ==============================================================" >> "/dev/stderr"

    if [ "${FLG_NOINTERACTIVE}" = "0" ]; then
        read -rsn 1 -p "Press any key to continue..."
    fi
    #echo "[DBG] exit 0" >> "/dev/stderr"; exit 0
    EXEC_NFSEXT=$(which exportfs)
    if [ ! -e "${EXEC_NFSEXT}" ]; then
        $MYEXEC install_package nfs-common nfs-kernel-server portmap
    fi

    DN_PXEBACKUP="/etc/pxelinuxisobak/"
    mkdir -p "${DN_PXEBACKUP}"
    # -- ISO file mount point: /etc/fstab
    $MYEXEC mkdir -p "${TFTP_ROOT}/${DIST_MOUNTPOINT}/"
    $MYEXEC umount "${DIST_FILE}"
    $MYEXEC umount "${TFTP_ROOT}/${DIST_MOUNTPOINT}"
    #$MYEXEC mount -o loop,utf8 "${DIST_FILE}" ${TFTP_ROOT}/${DIST_MOUNTPOINT}
    if [ ! "${TFTP_ROOT}/${DIST_MOUNTPOINT}" = "/" ]; then
        grep -v "${TFTP_ROOT}/${DIST_MOUNTPOINT}" /etc/fstab > /tmp/bbb
    else
        cp /etc/fstab /tmp/bbb
    fi
    if [ ! "${DIST_FILE}" = "" ]; then
        grep -v "${DIST_FILE}" /tmp/bbb > /tmp/aaa
    else
        cp /tmp/bbb /tmp/aaa
    fi
    diff -Nbu /etc/fstab /tmp/aaa
    RET=$?
    if [ ! "$RET" = "0" ]; then
        # backup the old fstab
        echo "[INFO] the old /etc/fstab saved to ${DN_PXEBACKUP}/fstab-$(date +%Y%m%d-%H%M%S)" >> "/dev/stderr"
        $MYEXEC cp /etc/fstab "${DN_PXEBACKUP}/fstab-$(date +%Y%m%d-%H%M%S)"
        # update the fatab
        $MYEXEC mv /tmp/aaa /etc/fstab
    fi
    $MYEXEC attach_to_file "${FN_TMP_ETCFSTAB}"   /etc/fstab

    echo "mount ${TFTP_ROOT}/${DIST_MOUNTPOINT}" > "${FN_TMP_ETCRCLOCAL}"
    grep -v "${TFTP_ROOT}/${DIST_MOUNTPOINT}" /etc/rc.local > /tmp/aaa
    diff -Nbu /etc/rc.local /tmp/aaa
    RET=$?
    if [ ! "$RET" = "0" ]; then
        # backup the old rc.local
        echo "[INFO] the old /etc/rc.local saved to ${DN_PXEBACKUP}/rc.local-$(date +%Y%m%d-%H%M%S)" >> "/dev/stderr"
        $MYEXEC cp /etc/rc.local "${DN_PXEBACKUP}/rc.local-$(date +%Y%m%d-%H%M%S)"
        # update the rc.local
        $MYEXEC mv /tmp/aaa /etc/rc.local
    fi
    $MYEXEC attach_to_file "${FN_TMP_ETCRCLOCAL}" /etc/rc.local
    #$MYEXEC mount -a
    #chmod 755 "${FN_TMP_ETCRCLOCAL}"
    . "${FN_TMP_ETCRCLOCAL}"

    # -- NFS
    if [ "${FLG_NFS}" = "1" ]; then
        if [ ! "${TFTP_ROOT}/${DIST_MOUNTPOINT}" = "/" ]; then
            grep -v "${TFTP_ROOT}/${DIST_MOUNTPOINT}" /etc/exports > /tmp/aaa
            # backup the old exports
            echo "[INFO] the old /etc/exports saved to ${DN_PXEBACKUP}/exports-$(date +%Y%m%d-%H%M%S)" >> "/dev/stderr"
            $MYEXEC cp /etc/exports "${DN_PXEBACKUP}/exports-$(date +%Y%m%d-%H%M%S)"
            # update exports
            $MYEXEC cp /tmp/aaa /etc/exports
        fi
        $MYEXEC attach_to_file "${FN_TMP_ETCEXPORTS}" /etc/exports
        #$MYEXEC sudo service nfs-kernel-server restart # Debian/Ubuntu
        #$MYEXEC service nfs restart   # RedHat/CentOS
        #$MYEXEC systemctl restart rpc-idmapd.service
        #$MYEXEC systemctl restart rpc-mountd.service
        #$MYEXEC exportfs -arv
        $MYEXEC systemctl restart rpcbind nfs-server
    fi

    # -- TFTP menu: ${TFTP_ROOT}/netboot/pxelinux.cfg/default
    $MYEXEC attach_to_file "${FN_TMP_TFTPMENU}" "${TFTP_ROOT}/netboot/pxelinux.cfg/default"

    # -- TFTP menu msg: ${TFTP_ROOT}/netboot/pxelinux.cfg/boot.txt
    if [ ! "${DIST_NAME}_${DIST_RELEASE}_${DIST_ARCH}_nfs" = "" ]; then
        grep -v "${TFTP_TAG_LABEL}" ${TFTP_ROOT}/netboot/pxelinux.cfg/boot.txt > /tmp/aaa
        $MYEXEC mv /tmp/aaa ${TFTP_ROOT}/netboot/pxelinux.cfg/boot.txt
    fi
    $MYEXEC echo "${TFTP_TAG_LABEL}" >> ${TFTP_ROOT}/netboot/pxelinux.cfg/boot.txt
    $MYEXEC /etc/init.d/tftpd-hpa restart # debian/ubuntu
    $MYEXEC service xinetd restart        # redhat/centos
    $MYEXEC systemctl restart tftpd.socket tftpd.service # arch
}

process_file_list () {
    #FN_MD5SUM=$1
    #shift

    #echo "[DBG] begin 1" >> "/dev/stderr"
    while :
    do
        #echo "[DBG] read 1" >> "/dev/stderr"
        read TMPFN
        if [ "${TMPFN}" = "" ]; then
            #echo "[DBG] End of TMPFN" >> "/dev/stderr"
            break;
        fi
        if [ "${TITLE_BOOT}" = "" ]; then
            echo "[DBG] tftp_setup_pxe_iso '${TMPFN}'" >> "/dev/stderr"
            tftp_setup_pxe_iso "${TMPFN}"
        else
            echo "[DBG] tftp_setup_pxe_iso '${TMPFN}' '${TITLE_BOOT}'" >> "/dev/stderr"
            tftp_setup_pxe_iso "${TMPFN}" "${TITLE_BOOT}"
        fi
    done
}

#####################################################################
# start of script
# read the arguments of commandline
#

usage () {
    PARAM_NAME="$1"

    echo "${PARAM_NAME} v0.1" >> "/dev/stderr"
    echo "" >> "/dev/stderr"
    echo "Prepare the TFTP root directory for Linux distributions' ISO files" >> "/dev/stderr"
    echo "So you can boot the installation CD/DVD from network(PXE)" >> "/dev/stderr"
    echo "Written by yhfudev(yhfudev@gmail.com), 2013-07" >> "/dev/stderr"
    echo "" >> "/dev/stderr"
    echo "${PARAM_NAME} [options] <url>" >> "/dev/stderr"
    echo "" >> "/dev/stderr"
    echo "Options:" >> "/dev/stderr"
    echo "  --help            Print this message" >> "/dev/stderr"
    echo "  --init            Init TFTP directory environment" >> "/dev/stderr"
    echo "  --tftproot <DIR>  set the tftp root folder, default: ${TFTP_ROOT}" >> "/dev/stderr"
    echo "  --nfsip <IP>      set NFS server IP, default: ${DIST_NFSIP}" >> "/dev/stderr"
    echo "  --title <NAME>    set the boot title" >> "/dev/stderr"
    echo "  --nonpae          add non-PAE for old machine" >> "/dev/stderr"

    echo "  --distname <NAME> set the OS type of ISO, such as centos, ubuntu, arch" >> "/dev/stderr"
    echo "  --distarch <NAME> set the arch of the OS, such as amd64, x86_64, i386, i686" >> "/dev/stderr"
    echo "  --distrelease <NAME> set the distribution release, such as quantal,raring" >> "/dev/stderr"
    echo "  --disttype <NAME> set the type of ISO, such as net, server, desktop." >> "/dev/stderr"

    echo "  --nointeractive|-n  no interative" >> "/dev/stderr"
    echo "  --simulate|-s       not do the real work, just show the info" >> "/dev/stderr"
    echo "" >> "/dev/stderr"
    echo "Features" >> "/dev/stderr"
    echo "  1. One single command line to setup a PXE entry to boot from CD/DVD" >> "/dev/stderr"
    echo "  2. Can be run in Redhat/CentOS/Ubuntu/Archlinux" >> "/dev/stderr"
    echo "  2. Support CD/DVDs of Fedora/CentOS/Debian/Ubuntu/Mint/Kali/..." >> "/dev/stderr"
    echo "" >> "/dev/stderr"
    echo "Prerequisites" >> "/dev/stderr"
    echo "" >> "/dev/stderr"
    echo "  1. Installed NFS server. This script will append lines to file /etc/exports;" >> "/dev/stderr"
    echo "  2. Installed TFTP server. This script will append lines to file" >> "/dev/stderr"
    echo "     /var/lib/tftpboot/netboot/pxelinux.cfg/default;" >> "/dev/stderr"
    echo "  3. To mount ISO files as loop device, a line will also be appended to /etc/fstab, and" >> "/dev/stderr"
    echo "     /etc/rc.local;" >> "/dev/stderr"
    echo "  4. Installed syslinux;" >> "/dev/stderr"
    echo "" >> "/dev/stderr"
    echo "Installation" >> "/dev/stderr"
    echo "  Download the source files from GIT repo" >> "/dev/stderr"
    echo "    git clone https://code.google.com/p/pxe-linux-iso/" >> "/dev/stderr"
    echo "" >> "/dev/stderr"
    echo "Initialize directories" >> "/dev/stderr"
    echo "" >> "/dev/stderr"
    echo "  This script use following tree structure to manage the ISO files:" >> "/dev/stderr"
    echo "    /var/lib/tftpboot/" >> "/dev/stderr"
    echo "      |-- downloads          # the downloaded CD/DVD ISO files and patches" >> "/dev/stderr"
    echo "      |-- images-desktop     # mount points for Linux desktop distributions" >> "/dev/stderr"
    echo "      |-- images-server      # mount points for Linux server distributions" >> "/dev/stderr"
    echo "      |-- images-net         # mount points for netinstall" >> "/dev/stderr"
    echo "      |-- netboot            # (tftp default directory)" >> "/dev/stderr"
    echo "          |-- downloads      # symbol link" >> "/dev/stderr"
    echo "          |-- images-desktop # symbol link" >> "/dev/stderr"
    echo "          |-- images-server  # symbol link" >> "/dev/stderr"
    echo "          |-- images-net     # symbol link" >> "/dev/stderr"
    echo "" >> "/dev/stderr"
    echo "  The following files also be initialized with default headers:" >> "/dev/stderr"
    echo "      /var/lib/tftpboot/netboot/pxelinux.cfg/default" >> "/dev/stderr"
    echo "      /var/lib/tftpboot/netboot/pxelinux.cfg/boot.txt" >> "/dev/stderr"
    echo "" >> "/dev/stderr"
    echo "Examples" >> "/dev/stderr"
    echo "" >> "/dev/stderr"
    echo "  0. Help!" >> "/dev/stderr"
    echo "    ${PARAM_NAME} --help" >> "/dev/stderr"
    echo "" >> "/dev/stderr"
    echo "  1. Initialize directories" >> "/dev/stderr"
    echo "    sudo ${PARAM_NAME} --init" >> "/dev/stderr"
    echo "" >> "/dev/stderr"
    echo "  2. Add entries to the PXE server" >> "/dev/stderr"
    echo "" >> "/dev/stderr"
    echo "    2.1 Add Ubuntu mini" >> "/dev/stderr"
    echo "      sudo ${PARAM_NAME} --nfsip 192.168.1.1 'http://mirror.anl.gov/pub/ubuntu/dists/quantal/main/installer-amd64/current/images/netboot/mini.iso'" >> "/dev/stderr"
    echo "" >> "/dev/stderr"
    echo "    2.2 Add Kali" >> "/dev/stderr"
    echo "      sudo ${PARAM_NAME} --nfsip 192.168.1.1 --title 'Kali' 'http://archive-5.kali.org/kali-images/kali-linux-1.0.4-amd64.iso'" >> "/dev/stderr"
    echo "" >> "/dev/stderr"
}

rm -f "${FN_TMP_LIST}"
rm -f "${FN_TMP_LASTMSG}"
touch "${FN_TMP_LASTMSG}"

# init tftp directory?
FLG_INIT_TFTPROOT=0
# add non-PAE installation (for Ubuntu)
FLG_NON_PAE=0
FLG_NON_PAE_PROCESSED=0
# ask user for choices?
FLG_NOINTERACTIVE=0
# simulate
FLG_SIMULATE=0
FN_FULL=""
TITLE_BOOT=""
A_DIST_NAME=""
A_DIST_RELEASE=""
A_DIST_ARCH=""
A_DIST_TYPE=""
while [ ! "$1" = "" ]; do
    case "$1" in
    --help|-h)
        usage "$0"
        exit 0
        ;;
    --init)
        FLG_INIT_TFTPROOT=1
        ;;
    --tftproot)
        shift
        export TFTP_ROOT="$1"
        ;;
    --nfsip)
        shift
        export DIST_NFSIP="$1"
        ;;
    --title)
        shift
        TITLE_BOOT="$1"
        ;;
    --distname)
        shift
        A_DIST_NAME="$1"
        ;;
    --distarch)
        shift
        A_DIST_ARCH="$1"
        ;;
    --distrelease)
        shift
        A_DIST_RELEASE="$1"
        ;;
    --disttype)
        shift
        A_DIST_TYPE="$1"
        ;;
    --nointeractive|-n)
        FLG_NOINTERACTIVE=1
        ;;
    --simulate|-s)
        FLG_SIMULATE=1
        ;;
    --nonpae|--nopae)
        FLG_NON_PAE=1
        ;;
    -*)
        echo "Use option --help to get the usages." >> "/dev/stderr"
        exit 1
        ;;
    *)
        echo "$1" >> "${FN_TMP_LIST}"
        FN_FULL="${FN_FULL} $1"
        break;
        ;;
    esac
    shift
done

echo "[DBG] FN_FULL=$FN_FULL" >> "/dev/stderr"
echo "[DBG] FLG_NON_PAE=$FLG_NON_PAE" >> "/dev/stderr"

# attach the content of a file to the end of another file.
attach_to_file () {
    if [ -f "$1" ]; then
        cat "$1" >> "$2"
    fi
}

FN_CMD=/dev/stderr
FN_DBG=/dev/null
myexec_ignore () {
    echo "[DBG] (skip) $*" >> "${FN_CMD}"
    echo "[DBG] (skip) $*" >> "${FN_DBG}"
    A=
    while [ ! "$1" = "" ]; do
        A="$A \"$1\""
        shift
    done
    #echo "[DBG] (skip) $A" >> "${FN_CMD}"
    echo "[DBG] (skip) $A" >> "${FN_DBG}"
}
myexec_trace () {
    echo "[DBG] $*" >> "${FN_CMD}"
    echo "[DBG] $*" >> "${FN_DBG}"
    A=
    while [ ! "$1" = "" ]; do
        A="$A \"$1\""
        shift
    done
    #echo "[DBG] $A" >> "${FN_CMD}"
    echo "[DBG] $A" >> "${FN_DBG}"
    eval $A
}
MYEXEC=myexec_trace
#MYEXEC=
if [ "$FLG_SIMULATE" = "1" ]; then
    MYEXEC=myexec_ignore
fi

echo "[DBG] Install basic software packages ..."

EXEC_AWK="$(which gawk)"
if [ ! -x "${EXEC_AWK}" ]; then
  install_package gawk
fi
EXEC_AWK="$(which gawk)"
if [ ! -x "${EXEC_AWK}" ]; then
  echo "[ERR] Not exist awk!" >> "/dev/stderr"
  exit 1
fi
echo | awk '{a = 1; switch(a) { case 0: break; } }'
if [ $? = 1 ]; then
  # patch gawk
  install_package gawk
fi


EXEC_WGET="$(which wget)"
if [ ! -x "${EXEC_WGET}" ]; then
  echo "[DBG] Try to install wget." >> "/dev/stderr"
  install_package wget
fi

EXEC_WGET="$(which wget)"
if [ ! -x "${EXEC_WGET}" ]; then
  echo "[ERR] Not exist wget!" >> "/dev/stderr"
  exit 1
fi

EXEC_ENV="$(which env)"
if [ ! -x "${EXEC_ENV}" ]; then
  echo "[DBG] Try to install coreutils." >> "/dev/stderr"
  install_package coreutils
fi

tftp_init_directories
if [ "${FLG_INIT_TFTPROOT}" = "1" ]; then
    tftp_init_service
fi

#if [ "${FN_FULL}" = "" ]; then
    #usage "$0"
    #exit 1
#fi

cat << EOF > ${FN_MD5TMP}
0c5fab6fff4c431a8827754f0b3bc13f  archlinux-2013.07.01-dual.iso
af139d2a085978618dc53cabc67b9269  bt4-final.iso
d324687fb891e695089745d461268576  BT5R3-KDE-32.iso
981b897b7fdf34fb1431ba84fe93249f  BT5R3-KDE-64.iso
afb8c6192a2e1d1ba0fa3db9c531be6d  pentoo-i686-2013.0_RC1.8.iso
9ed0286a23eeae77be6fd9b952c5f62c  initrd-kali-1.0.3-3.7-trunk-686-pae.img
a6aaec29dad544d9d3c86d3bf63d7486  initrd-kali-1.0.4-3.7-trunk-686-pae.img
a5bd239b9017943e0e4598ece7e7e85f  initrd-kali-1.0.4-3.7-trunk-amd64.img
e9cae6b8b1c8bbf9ceae4ea7cf575589  beini-1.2.5-es.iso

8d72e2db7e72e13813731eab37a14d26  ubuntu-13.04-desktop-amd64.iso
73d595b804149fca9547ed94db8ff44f  ubuntu-13.04-server-i386.iso
c187e39bdb6e09283a8976caadd756b6  linux-headers-3.8.0-19_3.8.0-19.30_all.deb
037f96bdbfef9c587289c58532e40f47  linux-headers-3.8.0-19-wt-non-pae_3.8.0-19.30_i386.deb
a7ef8da234153e7c8daba0f82f282df8  linux-image-3.8.0-19-wt-non-pae_3.8.0-19.30_i386.deb
0f707986757bd93a4f0efb9b521aca38  initrd-3.8.0-19-wt-non-pae_3.8.0-19.29_i386.lz
d3374a10f71468978428a383c3267aae  vmlinuz-3.8.0-19-wt-non-pae_3.8.0-19.29_i386

4a5fa01c81cc300f4729136e28ebe600  CentOS-6.4-x86_64-minimal.iso
f87e89a502fb2d1f30ca0f9a927c9a91  archlinux-2013.09.01-dual.iso
e6b72dee252d9b3c32d9b7d56ed93b51  archlinux-2014.02.01-dual.iso
03c490a202ffa7accf2638b62a357849  clonezilla-live-20131216-trusty-i386.iso

b6658ab75cd5d48f358f0ee31b06b934  lupu-525.iso
ea177aa9af0b4806cc82742f7ba946df  slacko-5.6-4G-NON-PAE.iso
EOF

cat << EOF > ${FN_SHA1TMP}
bb074cad7b6d8e09f936ee7c922a30362d8d7940  kali-linux-1.0-amd64-mini.iso
f1c1dbce42d88bae4ed5683655701e5847e23246  kali-linux-1.0-i386-mini.iso
95a0eab94407d7ebf0ec6fbd189d883aa772d21d  kali-linux-1.0.3-amd64.iso
54af51b9f4bf3d77ecd45e548de308837c546b12  kali-linux-1.0.3-i386.iso
fed4ae5157237c57d7815e475f7a9ddc38a13208  kali-linux-1.0.4-amd64-mini.iso
bb14f4e1fc0656a14615e40d727f6c49e8202d38  kali-linux-1.0.4-amd64.iso
01324e8486f16d7d754e1602b9afe135f5e98c8a  kali-linux-1.0.4-i386-mini.iso
68b91a8894709cc132ab7cd9eca57513e1ce478b  kali-linux-1.0.4-i386.iso
6232efa014d9c6798396b63152c4c9a08b279f5e  CentOS-6.4-x86_64-minimal.iso
27bbe172d66d4ce634d10fd655e840f72fe56130  ubuntu-13.04-server-i386.iso
3b087acd273656c55244baa7b7f1a147be7da990  archlinux-2013.09.01-dual.iso
eb4c971c71b505b5c1be25f1710e6579987fda3b  archlinux-2014.02.01-dual.iso
eeb8088f5fbf555093086c30e90f0e0d82cf7825  clonezilla-live-20131216-trusty-i386.iso

18fecad3e94be2026e1bb12b8c14eb76324a56a1  lupu-525.iso
497f6b61f4265e7dadc961039167b7c2f97c97ee  slacko-5.6-4G-NON-PAE.iso
EOF

echo "[DBG] file list: ${FN_TMP_LIST}" >> "/dev/stderr"
if [ -f "${FN_TMP_LIST}" ]; then
    process_file_list "" < "${FN_TMP_LIST}"
fi

#rm -f "${FN_TMP_LIST}"
echo "Done!" >> "/dev/stderr"
echo "Don't forget to add these lines to your DHCP server config file:"
echo "    next-server ${DIST_NFSIP};"
echo '    filename "/netboot/pxelinux.0"';
echo "and restart your DHCP server!"


cat "${FN_TMP_LASTMSG}" >> "/dev/stderr"
if [ "${FLG_NON_PAE}" = "1" ]; then
    if [ "${FLG_NON_PAE_PROCESSED}" = "0" ]; then
        echo "[ERR] Not porcess non-PAE option!"
    fi
fi

test_down_some_iso () {
    down_url "http://ftp.halifax.rwth-aachen.de/backtrack/BT5R3-KDE-32.iso"
    #down_url "http://ftp.halifax.rwth-aachen.de/backtrack/BT5R3-KDE-64.iso"
    #down_url "http://ftp.halifax.rwth-aachen.de/backtrack/BT5R3-GNOME-32.iso"
    #down_url "http://ftp.halifax.rwth-aachen.de/backtrack/BT5R3-GNOME-64.iso"

    #down_url "http://mirrors.kernel.org/archlinux/iso/2014.02.01/archlinux-2014.02.01-dual.iso"
    #down_url "http://www.gtlib.gatech.edu/pub/archlinux/iso/2014.02.01/archlinux-2014.02.01-dual.iso"

    #down_url  "http://archive.ubuntu.com/ubuntu/dists/quantal/main/installer-amd64/current/images/netboot/mini.iso" "ubuntu-mini-amd64-quantal.iso"
    #down_url "http://mirror.anl.gov/pub/ubuntu/dists/quantal/main/installer-amd64/current/images/netboot/mini.iso" "ubuntu-mini-amd64-quantal.iso"

    #tftp_setup_pxe_iso "ftp://189.115.48.10/linux/bt4-final.iso"
    #tftp_setup_pxe_iso "http://ftp.halifax.rwth-aachen.de/backtrack/BT5R3-KDE-32.iso"
    #tftp_setup_pxe_iso "http://archive-5.kali.org/kali-images/kali-linux-1.0.4-i386.iso"
    #tftp_setup_pxe_iso "http://archive-5.kali.org/kali-images/kali-linux-1.0.4-amd64.iso"
    #tftp_setup_pxe_iso "http://cdimage.kali.org/kali-latest/amd64/kali-linux-1.0.6-amd64.iso"

    #tftp_setup_pxe_iso "http://ftp.ticklers.org/releases.ubuntu.org/releases/saucy/ubuntu-13.10-desktop-amd64.iso"
    #tftp_setup_pxe_iso "http://us.releases.ubuntu.com/saucy/ubuntu-13.10-desktop-amd64.iso"
    # http://www.archive.ubuntu.com/ubuntu/dists/precise/main/installer-i386/current/images/netboot/non-pae/mini.iso
    #http://us.releases.ubuntu.com/raring/ubuntu-13.04-server-i386.iso

    #http://mirror.anl.gov/pub/centos/6.4/isos/x86_64/CentOS-6.4-x86_64-LiveCD.iso
    #http://mirror.anl.gov/pub/centos/6.4/isos/x86_64/CentOS-6.4-x86_64-minimal.iso
    #http://mirror.anl.gov/pub/centos/6.4/isos/x86_64/CentOS-6.4-x86_64-netinstall.iso
    #http://sourceforge.net/projects/clonezilla/files/clonezilla_live_alternative_testing/20131216-trusty/clonezilla-live-20131216-trusty-i386.iso
    #http://mirror.anl.gov/pub/centos/6.5/isos/x86_64/CentOS-6.5-x86_64-minimal.iso
}
