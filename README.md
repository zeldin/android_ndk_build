android_ndk_build
=================

Convenience script for build Android NDK host tools from source.


Background
----------

As of R11 of the Android NDK, Google no longer provides the necessary
scripts for building all the host tools from source in the NDK install.
Instead, one is required to manually check out the various sources from
git, and build from there.  This is made more complicated by the fact that
the LLVM sources are not tagged with the NDK release tag.

This repository contains two shell scripts to automate the process of
building your own host binaries for the Android NDK.  One script downloads
and compiles the sources, and one installs the resulting binaries in
your NDK tree.  Building on Linux/PPC and Linux/AArch64 is supported.


Prerequisites
-------------

In addition to an NDK Linux release downloaded from [NDK Downloads][],
you will need a number of tools installed:

 * Python 2.7
 * git
 * curl
 * native host toolchains, both gcc (g++) and clang (clang++)

Also required is about 40G of disk space.  At least 4G of RAM is recommended.


Building
--------

In order to start the process of downloading and compiling the sources,
run the `build-host-binaries.sh` script, passing as arguments the path
to where you unpacked the NDK release (the script needs to access some
files from here while bootstrapping the LLVM build), and the corresponding
git tag for the release.  Example:

  `./build-host-binaries.sh /usr/local/android-ndk-r11c r11c`

By default the sources and build products will be placed in the current
directory, but by setting the environment variable WORKDIR, you can
specify another location.  If you do this, make sure to have it set to
the same value when running the installation script later (see next
section).

The build will take anything from 7 hours (NVIDIA Jetson TX1) to
18 hours (A-EON AmigaOne X1000).


Installing
----------

After the build script has completed successfully, the script
`fix-installed-ndk.sh` can be used to install the resulting binaries.
It will also patch various scripts and makefiles to make sure the
NDK can be used on Linux/PPC and Linux/AArch64 (provided you have
built the corresponding binaries).  The script takes one argument,
which is the path of the NDK installation to modify.  Example:

  `./fix-installed-ndk.sh /usr/local/android-ndk-r11c`

If you have built host binaries for multiple architectures, the
script will install all of them (assuming the same WORKDIR was used).
Running the script multiple times to install architectures one at a
time to the same NDK tree is also possible,


[NDK Downloads]: http://developer.android.com/ndk/downloads/index.html

