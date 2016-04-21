#!/bin/sh

set -e

: ${WORKDIR:=`pwd`}
CC=gcc

ANDROID_BUILD_TOP="${WORKDIR}"/src
OUT_DIR="${WORKDIR}"/out

if [ $# != 2 ]; then
  echo >&2 "Usage: $0 ndk-path ndk-version"
  exit 1
else
  NDK_PATH="$1"
  NDK_VERSION="$2"
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

for arch in arch-arm64 arch-mips64 arch-x86_64; do
  test -h prebuilts/ndk/current/platforms/android-19/"${arch}" ||
  test -d prebuilts/ndk/current/platforms/android-19/"${arch}" ||
  ln -s ../android-21/"${arch}" prebuilts/ndk/current/platforms/android-19/"${arch}"
done

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

ANDROID_BUILD_TOP="${WORKDIR}"/llvmsrc
export ANDROID_BUILD_TOP

test -d "${ANDROID_BUILD_TOP}" || mkdir -p "${ANDROID_BUILD_TOP}"

cd "${ANDROID_BUILD_TOP}"

CLANG=`type -P clang | head -1`
if [ -n "${CLANG}" ]; then
  echo "Using system clang ${CLANG}"
  CLANGDIR=`dirname "${CLANG}"`
else
  echo >&2 Unable to find a system clang
  exit 1
fi

if [ -f manifest_llvm.xml ]; then
  echo LLVM manifest already created
else
  echo Creating LLVM manifest
  cat > manifest_llvm.xml.tmp <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <remote  name="aosp"
           fetch=".."
           review="https://android-review.googlesource.com/" />
  <default revision="master"
           remote="aosp"
           sync-j="4" />
EOF
  cat "${NDK_PATH}"/toolchains/llvm/prebuilt/linux-x86_64/repo.prop | grep -v '^platform/prebuilts' | sed >> manifest_llvm.xml.tmp -ne 's/^\(platform\/\)\?\([^ ]*\) \([^ ]*\)$/  <project path="\2" name="\1\2" revision="\3">\
  <\/project>/p'
  cat >> manifest_llvm.xml.tmp <<'EOF'
</manifest>
EOF
  sed -i -e '/<project path="build"/a\
    <copyfile src="core/root.mk" dest="Makefile" />' manifest_llvm.xml.tmp
  sed -i -e '/<project path="build\/soong"/a\
    <linkfile src="root.bp" dest="Android.bp" />\
    <linkfile src="bootstrap.bash" dest="bootstrap.bash" />' manifest_llvm.xml.tmp
  mv manifest_llvm.xml.tmp manifest_llvm.xml
fi

if [ -d .repo ]; then
  echo Repo already initialized
else
  echo Initializing repo
  repo init -u https://android.googlesource.com/platform/manifest --depth=1
  cp manifest_llvm.xml .repo/manifests/
  repo init -m manifest_llvm.xml --depth=1
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
  cd build
  patch -p1 < "${p}"/build2.patch
  cd ../external/clang
  patch -p1 < "${p}"/clang.patch
  cd ../..
  touch stmp-patch
fi

test -d prebuilts || mkdir prebuilts
test -h prebuilts/ndk || ln -s "${WORKDIR}"/src/prebuilts/ndk prebuilts/

for fn in "${OUT_DIR}"/dist/gcc-*; do
  pkg=`basename "${fn}"`
  host_tag=`echo "${pkg}" | sed -e 's/^.*-\(linux-[^.]*\)[.].*$/\1/'`
  arch=`echo "${pkg}" | sed -e 's/^gcc-\(.*\)-linux-.*$/\1/'`
  case "${arch}" in
    x86*) arch=x86;;
    mips*) arch=mips;;
    arm64) arch=aarch64;;
  esac
  toolchain=`tar tjf "${fn}" | head -1 | sed -e 's:/.*$::g'`
  toolchain_orig="$toolchain"
  case "${toolchain}" in
    *-linux*) ;;
    *) toolchain=`echo "${toolchain}" | sed -e 's/-/-linux-android-/'`;;
  esac
  if [ -d prebuilts/gcc/"${host_tag}"/"${arch}"/"${toolchain}" ]; then
    echo Already installed "${pkg}" in prebuilts
  else
    echo Installing "${pkg}" in prebuilts
    mkdir -p prebuilts/gcc/"${host_tag}"/"${arch}"
    tar -C prebuilts/gcc/"${host_tag}"/"${arch}" -x -j -f "${fn}"
    if [ x"${toolchain}" != x"${toolchain_orig}" ]; then
	mv prebuilts/gcc/"${host_tag}"/"${arch}"/"${toolchain_orig}" prebuilts/gcc/"${host_tag}"/"${arch}"/"${toolchain}"
    fi
  fi
done

USE_NINJA=false
SKIP_JAVA_CHECK=true
export USE_NINJA SKIP_JAVA_CHECK

if [ -f stmp-clang-stage0 ]; then
  echo Clang stage0 already built
else
  echo Building clang stage0
  PYTHONPATH="${WORKDIR}"/src/ndk/build/lib python "${HOME}"/build_clang_stage0.py --installed-ndk-clang="${NDK_PATH}"/toolchains/llvm/prebuilt/linux-x86_64 --prebuilt-clang-path="${CLANGDIR}"
  touch stmp-clang-stage0
fi

if [ -f stmp-clang-stage2 ]; then
  echo Clang stage2 already built
else
  LLVM_PREBUILTS_BASE="${OUT_DIR}"/host
  LLVM_PREBUILTS_VERSION=.
  export LLVM_PREBUILTS_BASE LLVM_PREBUILTS_VERSION

  python external/clang/build.py

  touch stmp-clang-stage2
fi

echo "You can now find packages in ${OUT_DIR}/dist and ${OUT_DIR}/stage2"
exit 0
