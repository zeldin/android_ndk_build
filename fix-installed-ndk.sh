#!/bin/sh

set -e

: ${WORKDIR:=`pwd`}

OUT_DIR="${WORKDIR}"/out

if [ $# != 1 ]; then
  echo >&2 "Usage: $0 ndk-path"
  exit 1
else
  NDK_PATH="$1"
fi

p=`pwd`/patches

cd "${NDK_PATH}"

if [ -f source.properties ] && fgrep -q "Android NDK" source.properties; then
  :
else
  echo >&2 "Can not find an installed NDK in `pwd`"
  exit 1
fi

if [ -f .patched ]; then
  echo Scripts already patched
else
  echo Patching scripts
  patch -p1 < "${p}"/ndk.patch
  touch .patched
fi

for cmd in ndk-stack ndk-which ndk-gdb ndk-depends; do
echo "Fixing ${cmd}"
cat > ${cmd} <<EOF
#!/bin/sh
DIR="\$(cd "\$(dirname "\$0")" && pwd)"
. \$DIR/build/tools/ndk-common.sh > /dev/null
\$DIR/prebuilt/\${HOST_TAG}/bin/${cmd} "\$@"
EOF
chmod a+x ${cmd}
done

for fn in "${OUT_DIR}"/dist/*; do
  pkg=`basename "${fn}"`
  host_tag=`echo "${pkg}" | sed -e 's/^.*-\(linux-[^.]*\)[.].*$/\1/'`
  case "${pkg}" in
    gcc-*-linux-*.tar.bz2)
      toolchain=`tar tjf "${fn}" | head -1 | sed -e 's:/.*$::g'`
      cd toolchains
      if [ -d "${toolchain}/prebuilt/${host_tag}" ]; then
	  echo Already installed "${pkg}"
      else
	  echo Installing package "${pkg}"
	  mkdir "${toolchain}/prebuilt/${host_tag}"
	  tar -C "${toolchain}/prebuilt/${host_tag}" --strip-components=1 -x -j -f "${fn}"
	  rm -rf "${toolchain}/prebuilt/${host_tag}/include"
	  rm -rf "${toolchain}/prebuilt/${host_tag}/share"
	  rm -rf "${toolchain}/prebuilt/${host_tag}/lib/gcc"/*/*/finclude
      fi
      cd ..
      ;;
    host-tools-linux-*.zip)
      cd prebuilt
      if [ -d "${host_tag}" ]; then
	  echo Already installed "${pkg}"
      else
	  if [ -d host-tools ]; then
	      echo >&2 "Directory host-tools exists in `pwd`, can't proceed"
	      exit 1
	  fi
	  echo Installing package "${pkg}"
	  unzip -qq "${fn}"
	  mv host-tools "${host_tag}"
      fi
      cd ..
      ;;
    *)
      echo >&2 "Don't know how to install ${pkg}"
      exit 1
      ;;
  esac
done
