#!/bin/bash
                                   #########
#################################### iSSH2 #####################################
#                                  #########                                   #
# Copyright (c) 2013 Tommaso Madonia. All rights reserved.                     #
#                                                                              #
# Permission is hereby granted, free of charge, to any person obtaining a copy #
# of this software and associated documentation files (the "Software"), to deal#
# in the Software without restriction, including without limitation the rights #
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell    #
# copies of the Software, and to permit persons to whom the Software is        #
# furnished to do so, subject to the following conditions:                     #
#                                                                              #
# The above copyright notice and this permission notice shall be included in   #
# all copies or substantial portions of the Software.                          #
#                                                                              #
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR   #
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,     #
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE  #
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER       #
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,#
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN    #
# THE SOFTWARE.                                                                #
################################################################################

source "$BASEPATH/iSSH2-commons"

set -e

mkdir -p "$LIBPCAPDIR"

LIBPCAP_TAR="libpcap-$LIBPCAP_VERSION.tar.gz"

downloadFile "https://www.tcpdump.org/release/$LIBPCAP_TAR" "$LIBPCAPDIR/$LIBPCAP_TAR"

LIBPCAPSRC="$LIBPCAPDIR/src/"
mkdir -p "$LIBPCAPSRC"

set +e
echo "Extracting $LIBPCAP_TAR"
tar -zxkf "$LIBPCAPDIR/$LIBPCAP_TAR" -C "$LIBPCAPDIR/src" --strip-components 1 2>&-
set -e

echo "Building Libpcap $LIBPCAP_VERSION:"

for ARCH in $ARCHS
do
  PLATFORM="$(platformName "$SDK_PLATFORM" "$ARCH")"
  PLATFORM_SRC="$LIBPCAPDIR/${PLATFORM}_$SDK_VERSION-$ARCH/src"
  PLATFORM_OUT="$LIBPCAPDIR/${PLATFORM}_$SDK_VERSION-$ARCH/install"
  LIPO_PCAP="$LIPO_PCAP $PLATFORM_OUT/lib/libpcap.a"

  if [[ -f "$PLATFORM_OUT/lib/libpcap.a" ]]; then
    echo "libpcap.a for $ARCH already exists."
  else
    rm -rf "$PLATFORM_SRC"
    rm -rf "$PLATFORM_OUT"
    mkdir -p "$PLATFORM_OUT"
    cp -R "$LIBPCAPSRC" "$PLATFORM_SRC"
    cd "$PLATFORM_SRC"

    mkdir -p "$PLATFORM_OUT"/include/net
    cp "$DEVELOPER/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/include/net/bpf.h" "$PLATFORM_OUT"/include/net/bpf.h
    cp "$DEVELOPER/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/include/net/if_media.h" "$PLATFORM_OUT"/include/net/if_media.h

    LOG="$PLATFORM_OUT/build-libpcap.log"
    touch $LOG

    if [[ "$ARCH" == arm64* ]]; then
      HOST="aarch64-apple-darwin"
    else
      HOST="$ARCH-apple-darwin"
    fi

    export DEVROOT="$DEVELOPER/Platforms/$PLATFORM.platform/Developer"
    export SDKROOT="$DEVROOT/SDKs/$PLATFORM$SDK_VERSION.sdk"
    export CC="$CLANG"
    export CPP="$CLANG -E"
    export CFLAGS="-arch $ARCH -pipe -no-cpp-precomp -isysroot $SDKROOT -m$SDK_PLATFORM-version-min=$MIN_VERSION $EMBED_BITCODE -I${PLATFORM_OUT}/include"
    export CPPFLAGS="-arch $ARCH -pipe -no-cpp-precomp -isysroot $SDKROOT -m$SDK_PLATFORM-version-min=$MIN_VERSION"
    export FULL_CFLAGS=

    ./configure --host=$HOST --prefix="$PLATFORM_OUT" --with-pcap=bpf --enable-shared=no --enable-universal=no >> "$LOG" 2>&1

    make >> "$LOG" 2>&1
    make -j "$BUILD_THREADS" install >> "$LOG" 2>&1

    echo "- $PLATFORM $ARCH done!"
  fi
done

lipoFatLibrary "$LIPO_PCAP" "$BASEPATH/libpcap_$SDK_PLATFORM/lib/libpcap.a"

importHeaders "$LIBPCAPSRC/pcap/" "$BASEPATH/libpcap_$SDK_PLATFORM/include/pcap"
cp -RL "$LIBPCAPSRC/pcap.h" "$BASEPATH/libpcap_$SDK_PLATFORM/include/"
cp -RL "$LIBPCAPSRC/pcap-bpf.h" "$BASEPATH/libpcap_$SDK_PLATFORM/include/"
cp -RL "$LIBPCAPSRC/pcap-namedb.h" "$BASEPATH/libpcap_$SDK_PLATFORM/include/"

echo "Building done."
