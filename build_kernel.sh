#!/bin/bash -e
#
# Copyright (c) 2009-2011 Robert Nelson <robertcnelson@gmail.com>
#
# - Adopted for building a Linux kernel for the USRP-E100
# - Please note that this is a stripped version, for full
#   functionality, please use Robert's excellent script
#   by Andre Puschmann <andre.puschmann@tu-ilmenau.de>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

unset PATCH_KERNEL

DIR=$PWD

config="omap2plus_defconfig"
LOCAL_PATCH_DIR=${DIR}/patches-local/

ARCH=$(uname -m)
CCACHE=ccache
CC=arm-linux-gnueabi-
ZRELADDR=0x80008000


CORES=1
if test "-$ARCH-" = "-x86_64-" || test "-$ARCH-" = "-i686-"
then
 CORES=$(cat /proc/cpuinfo | grep processor | wc -l)
 let CORES=$CORES+1
fi

mkdir -p ${DIR}/deploy/


function patch_kernel {
 
  if [ -d "${LOCAL_PATCH_DIR}" ]; then
    echo "applying kernel patches .."
    for i in ${LOCAL_PATCH_DIR}/*.patch ; do patch -p1 < $i ; done
  fi

  cd ${DIR}/
}

function copy_defconfig {
  cd ${DIR}/
  make ARCH=arm CROSS_COMPILE=${CC} distclean
  make ARCH=arm CROSS_COMPILE=${CC} ${config}
  cp -v .config ${DIR}/patches-local/ref_${config}
  cp -v ${DIR}/patches-local/defconfig .config
  cd ${DIR}/
}

function make_menuconfig {
  cd ${DIR}/
  make ARCH=arm CROSS_COMPILE=${CC} menuconfig
  cp -v .config ${DIR}/patches-local/defconfig
  cd ${DIR}/
}

function make_uImage {
  cd ${DIR}/
  echo "make -j${CORES} ARCH=arm LOCALVERSION=-${BUILD} CROSS_COMPILE=\"${CCACHE} ${CC}\" CONFIG_DEBUG_SECTION_MISMATCH=y uImage"
  time make -j${CORES} ARCH=arm LOCALVERSION=-${BUILD} CROSS_COMPILE="${CCACHE} ${CC}" CONFIG_DEBUG_SECTION_MISMATCH=y uImage
  KERNEL_UTS=$(cat ${DIR}/include/generated/utsrelease.h | awk '{print $3}' | sed 's/\"//g' )
  cp arch/arm/boot/zImage ${DIR}/deploy/${KERNEL_UTS}.uImage
  cd ${DIR}/
}

function make_zImage {
  cd ${DIR}/
  echo "make -j${CORES} ARCH=arm LOCALVERSION=-${BUILD} CROSS_COMPILE=\"${CCACHE} ${CC}\" CONFIG_DEBUG_SECTION_MISMATCH=y zImage"
  time make -j${CORES} ARCH=arm LOCALVERSION=-${BUILD} CROSS_COMPILE="${CCACHE} ${CC}" CONFIG_DEBUG_SECTION_MISMATCH=y zImage
  KERNEL_UTS=$(cat ${DIR}/include/generated/utsrelease.h | awk '{print $3}' | sed 's/\"//g' )
  cp arch/arm/boot/zImage ${DIR}/deploy/${KERNEL_UTS}.zImage
  cd ${DIR}/
}

function make_modules {
  cd ${DIR}/
  time make -j${CORES} ARCH=arm LOCALVERSION=-${BUILD} CROSS_COMPILE="${CCACHE} ${CC}" CONFIG_DEBUG_SECTION_MISMATCH=y modules

  echo ""
  echo "Building Module Archive"
  echo ""

  rm -rf ${DIR}/deploy/mod &> /dev/null || true
  mkdir -p ${DIR}/deploy/mod
  make ARCH=arm CROSS_COMPILE=${CC} modules_install INSTALL_MOD_PATH=${DIR}/deploy/mod
  echo "Building ${KERNEL_UTS}-modules.tar.gz"
  cd ${DIR}/deploy/mod
  tar czf ../${KERNEL_UTS}-modules.tar.gz *
  cd ${DIR}/
}

function make_headers {
  cd ${DIR}/

  echo ""
  echo "Building Header Archive"
  echo ""

  rm -rf ${DIR}/deploy/headers &> /dev/null || true
  mkdir -p ${DIR}/deploy/headers/usr
  make ARCH=arm CROSS_COMPILE=${CC} headers_install INSTALL_HDR_PATH=${DIR}/deploy/headers/usr
  cd ${DIR}/deploy/headers
  echo "Building ${KERNEL_UTS}-headers.tar.gz"
  tar czf ../${KERNEL_UTS}-headers.tar.gz *
  cd ${DIR}/
}

function usage {
    echo "usage: sudo $(basename $0)"
cat <<EOF

Additional Options:
-h --help
    this help

--patch
    Apply patches in patches-local before building kernel

EOF
exit
}

# parse commandline options
while [ ! -z "$1" ]; do
    case $1 in
        -h|--help)
            usage
            MMC=1
            ;;
        --patch)
            PATCH_KERNEL=1
            ;;
    esac
    shift
done

  #git_kernel
if [ "$PATCH_KERNEL" ];then
 patch_kernel
fi  
  #copy_defconfig
  #make_menuconfig
  make_uImage
  #make_zImage
  #make_modules
  #make_headers
 
echo "done!"
