pxe-linux-iso
=============

PXE Boot Linux Distribution Easy


This project helps the user to boot/install the Linux distributions more easy from ISO files.

Supported Linux distribution CD/DVDs
------------------------------------
  * CentOS/Fedora
  * Debian/Ubuntu
  * Arch Linux
  * Gentoo
  * openSUSE
  * Mageia
  * Manjaro
  * Elementary OS
  * BlackArch
  * Kali/BackTrack
  * Mint Linux
  * clonezilla
  * tinycore
  * puppy
  * doudoulinux

Supported Linux platforms
-------------------------

This software can run on following systems:

  * CentOS/Fedora
  * Debian/Ubuntu
  * Arch Linux

Features
--------
  * One single command line to setup a PXE entry to boot from CD/DVD
  * Can be run on multiple Linux systems
  * Support CD/DVDs of Fedora/CentOS/Debian/Ubuntu/Arch/Kali/Mint/...

Prerequisites
-------------

  * Installed NFS server. This script will append lines to file /etc/exports;
  * Installed TFTP server. This script will append lines to file
     /var/lib/tftpboot/netboot/pxelinux.cfg/default;
  * To mount ISO files as loop device, a line will also be appended to /etc/fstab;
  * Installed syslinux;
  * To support HTTP installation, you may need to get the HTTP server installed and
    link the directory tftpboot as sub-dir of the URL. For example, the tftpboot can
    be accessed by http://localhost/tfptboot/

Installation
------------
  Download the source files from GIT repo

    git clone https://code.google.com/p/pxe-linux-iso/

Initialize directories
----------------------

  This script use following tree structure to manage the ISO files:

    /var/lib/tftpboot/
      |-- downloads          # the downloaded CD/DVD ISO files and patches
      |-- images-desktop     # mount points for Linux desktop distributions
      |-- images-server      # mount points for Linux server distributions
      |-- images-net         # mount points for netinstall
      |-- netboot            # (tftp default directory)
          |-- downloads      # symbol link
          |-- images-desktop # symbol link
          |-- images-server  # symbol link
          |-- images-net     # symbol link

  The following files also be initialized with default headers:

      /var/lib/tftpboot/netboot/pxelinux.cfg/default
      /var/lib/tftpboot/netboot/pxelinux.cfg/boot.txt

Examples
--------
  * Help!

    ./pxelinuxiso.sh --help

  * Initialize directories

    sudo ./pxelinuxiso.sh --init

  * Add entries to the PXE server

    -- Add Ubuntu mini

      sudo ./pxelinuxiso.sh --nfsip 192.168.1.1 'http://mirror.anl.gov/pub/ubuntu/dists/quantal/main/installer-amd64/current/images/netboot/mini.iso'

    -- Add Kali

      sudo ./pxelinuxiso.sh --nfsip 192.168.1.1 --title 'Kali' 'http://archive-5.kali.org/kali-images/kali-linux-1.0.4-amd64.iso'
