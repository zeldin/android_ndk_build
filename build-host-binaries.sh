#!/bin/sh

set -e

: ${WORKDIR:=`pwd`}
CC=gcc

ANDROID_BUILD_TOP="${WORKDIR}"/src
OUT_DIR="${WORKDIR}"/out

if [ $# != 1 ]; then
  echo >&2 "Usage: $0 ndk-version"
  exit 1
else
  NDK_VERSION="$1"
fi

HOME=`pwd`

export CC ANDROID_BUILD_TOP OUT_DIR HOME

if [ -x bin/repo ]; then
  echo Repo already downloaded
else
  echo Downloading repo
  test -d bin || mkdir bin
  curl https://storage.googleapis.com/git-repo-downloads/repo > bin/repo
  chmod a+x bin/repo
fi

if [ -x bin/python ]; then
  echo Python already selected
else
  PYTHON=`type -P python2.7 python2 python | head -1`
  if [ -n "${PYTHON}" ]; then
    echo "Using ${PYTHON} for PYTHON"
    ln -s "${PYTHON}" bin/python
  else
    echo >&2 Unable to find a python
    exit 1
  fi
fi

PATH=`pwd`/bin:"${PATH}"
export PATH

p=`pwd`/patches

test -d "${ANDROID_BUILD_TOP}" || mkdir -p "${ANDROID_BUILD_TOP}"
test -d "${OUT_DIR}" || mkdir -p "${OUT_DIR}"

cd "${ANDROID_BUILD_TOP}"

if [ -d .repo ]; then
  echo Repo already initialized
else
  echo Initializing repo
  repo init -u https://android.googlesource.com/platform/manifest -b ndk-"${NDK_VERSION}" --depth=1
  sed -e '/name="platform\/prebuilts\/[^"]*-x86/d' < .repo/manifests/default.xml > .repo/manifests/manifest_ndk.xml
  repo init -m manifest_ndk.xml --depth=1
fi

if [ -f stmp-sync ]; then
  echo Repo already synced
else
  echo Syncing repo
  repo sync --optimized-fetch
  touch stmp-sync
fi

if [ -f stmp-patch ]; then
  echo Sources already patched
else
  echo Patching sources
  cd ndk
  patch -p1 < "${p}"/ndk.patch
  cd ../toolchain/python
  patch -p1 < "${p}"/python.patch
  cd ../binutils
  patch -p1 < "${p}"/binutils.patch
  cd ../build
  patch -p1 < "${p}"/build.patch
  cd ../..
  touch stmp-patch
fi

if [ -f stmp-host-tools ]; then
  echo Host tools already built
else
  echo Building host tools
  cd ndk
  python checkbuild.py --module host-tools 
  cd ..
  touch stmp-host-tools
fi

if [ -f stmp-gcc ]; then
  echo GCC already built
else
  echo Building GCC for all targets
  cd toolchain/gcc
  python build.py
  cd ../..
  touch stmp-gcc
fi

echo "You can now find packages in ${OUT_DIR}/dist"
exit 0
