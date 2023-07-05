#!/bin/sh

showHelp() {
cat << EOF  
Usage: ./build.sh <android|ios> 
Cross compile libdogecoin for Android or iOS.
EOF
}

# string formatters
if [[ -t 1 ]]
then
  tty_escape() { printf "\033[%sm" "$1"; }
else
  tty_escape() { :; }
fi
tty_mkbold() { tty_escape "1;$1"; }
tty_underline="$(tty_escape "4;39")"
tty_blue="$(tty_mkbold 34)"
tty_red="$(tty_mkbold 31)"
tty_bold="$(tty_mkbold 39)"
tty_reset="$(tty_escape 0)"

shell_join() {
  local arg
  printf "%s" "$1"
  shift
  for arg in "$@"
  do
    printf " "
    printf "%s" "${arg// /\ }"
  done
}

info() {
  printf "${tty_blue}==>${tty_bold} %s${tty_reset}\n" "$(shell_join "$@")"
}

warn() {
  printf "${tty_red}Warning${tty_reset}: %s\n" "$(shell_join "$@")"
}

build() {

    info "Starting build..."
    if [ -d "libdogecoin-${BUILD}" ]; then
        warn "libdogecoin-${BUILD} already exists."
        cd libdogecoin-${BUILD}
    else
        mkdir libdogecoin-${BUILD}
        cd libdogecoin-${BUILD}
    fi

    BASE=$(pwd)

    info "Cloning libdogecoin"
    if [ -d "libdogecoin" ]; then
        warn "libdogecoin already exists."
    else
        git clone -b main https://github.com/dogecoinfoundation/libdogecoin
    fi

    if [ "$BUILD" == "android" ]
    then

      info "Building for android..."
      info "Installing android-ndk"
      ANDROID_NDK_VERSION=r22
      if [ -d "android-ndk-${ANDROID_NDK_VERSION}" ]; then
          warn "Android NDK already exists."
      else
          wget https://dl.google.com/android/repository/android-ndk-${ANDROID_NDK_VERSION}-linux-x86_64.zip 
          unzip android-ndk-${ANDROID_NDK_VERSION}-linux-x86_64.zip
          rm android-ndk-${ANDROID_NDK_VERSION}-linux-x86_64.zip
      fi

      LIBUNISTRING_VER=libunistring-1.1
      info "Building ${LIBUNISTRING_VER} for android"
      if [ -d "${LIBUNISTRING_VER}" ]; then
          warn "${LIBUNISTRING_VER} already exists."
      else
          wget https://ftp.gnu.org/gnu/libunistring/${LIBUNISTRING_VER}.tar.gz
          tar -xvf ${LIBUNISTRING_VER}.tar.gz
          rm -r ${LIBUNISTRING_VER}.tar.gz
          cd ${LIBUNISTRING_VER}
          mkdir build
          ./configure \
            CXX=${BASE}/android-ndk-/${ANDROID_NDK_VERSION}/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android21-clang++ \
            CC=${BASE}/android-ndk-${ANDROID_NDK_VERSION}/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android21-clang \
            --host aarch64-linux-android21 --prefix=${BASE}/${LIBUNISTRING_VER}/build
          make clean && make -j$(nproc) && make install
          cd ..
      fi

      LIBEVENT_VER=libevent-2.1.12-stable
      LIBEVENT_URL=https://github.com/libevent/libevent/releases/download/release-2.1.12-stable/libevent-2.1.12-stable.tar.gz
      info "Building ${LIBEVENT_VER} for android"
      if [ -d "${LIBEVENT_VER}" ]; then
          warn "${LIBEVENT_VER} already exists."
      else
          wget ${LIBEVENT_URL}
          tar -xvf ${LIBEVENT_VER}.tar.gz
          rm -r ${LIBEVENT_VER}.tar.gz
          cd ${LIBEVENT_VER}
          mkdir build
          ./configure \
            CXX=${BASE}/android-ndk-/${ANDROID_NDK_VERSION}/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android21-clang++ \
            CC=${BASE}/android-ndk-${ANDROID_NDK_VERSION}/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android21-clang \
            --host aarch64-linux-android21 --prefix=${BASE}/${LIBEVENT_VER}/build --disable-openssl
          make clean && make -j$(nproc) && make install
          cd ..
      fi

      info "Configuring libdogecoin"
      cd libdogecoin
      ./autogen.sh
      ./configure \
          CXX=${BASE}/android-ndk-/${ANDROID_NDK_VERSION}/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android21-clang++ \
          CC=${BASE}/android-ndk-${ANDROID_NDK_VERSION}/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android21-clang \
          CPPFLAGS="-I${BASE}/${LIBUNISTRING_VER}/build/include -I${BASE}/${LIBEVENT_VER}/build/include" \
          LDFLAGS="-L${BASE}/${LIBUNISTRING_VER}/build/lib -L${BASE}/${LIBEVENT_VER}/build/lib" \
          --host aarch64-linux-android21 --disable-dependency-tracking

      info "Building libdogecoin"
      make clean && make -j$(nproc)

      info "Copying libs"
      cd ..
      if [ -d "build" ]; then
          warn "build already exists."
          cd build
      else
          mkdir build
          cd build
      fi
      mkdir -p ./arm64-v8a
      cp -r ${BASE}/libdogecoin/.libs/libdogecoin.so ./arm64-v8a
      cp -r ${BASE}/${LIBUNISTRING_VER}/build/lib/libunistring.so ./arm64-v8a
      cp -r ${BASE}/${LIBEVENT_VER}/build/lib/libevent-2.1.so ./arm64-v8a
      cp -r ${BASE}/${LIBEVENT_VER}/build/lib/libevent_core-2.1.so ./arm64-v8a

      info "Done! View results in ${BASE}/build"
      info "For use in Flutter, copy build/arm64-v8a to <flutter project>/android/app/src/main/jniLibs/arm64-v8a"

    elif [ "$BUILD" == "ios" ] 
    then

      info "Building for iOS..."
      info "Installing iOS toolchain"
      if [ -d "ios-toolchain" ]; then
        warn "iOS toolchain already exists."
      else
        mkdir ios-toolchain
        wget https://github.com/sbingner/llvm-project/releases/latest/download/linux-ios-arm64e-clang-toolchain.tar.lzma
        tar -xvf linux-ios-arm64e-clang-toolchain.tar.lzma -C ios-toolchain
        rm -r linux-ios-arm64e-clang-toolchain.tar.lzma
      fi

      info "Installing iOS SDKs"
      if [ -d "ios-sdks" ]; then
        warn "iOS SDKs already exist."
      else
        git clone https://github.com/theos/sdks ios-sdks
      fi

      IOS_SDK=iPhoneOS13.7.sdk

      LIBUNISTRING_VER=libunistring-1.1
      info "Building ${LIBUNISTRING_VER} for iOS"
      if [ -d "${LIBUNISTRING_VER}" ]; then
          warn "${LIBUNISTRING_VER} already exists."
      else
          wget https://ftp.gnu.org/gnu/libunistring/${LIBUNISTRING_VER}.tar.gz
          tar -xvf ${LIBUNISTRING_VER}.tar.gz
          rm -r ${LIBUNISTRING_VER}.tar.gz
          cd ${LIBUNISTRING_VER}
          mkdir build
          ./configure \
            CXX=${BASE}/ios-toolchain/ios-arm64e-clang-toolchain/bin/clang++ \
            CC=${BASE}/ios-toolchain/ios-arm64e-clang-toolchain/bin/clang \
            CFLAGS="--target=arm64-apple-darwin -isysroot ${BASE}/ios-sdks/${IOS_SDK}" \
            CXXFLAGS="--target=arm64-apple-darwin" \
            AR=${BASE}/ios-toolchain/ios-arm64e-clang-toolchain/bin/ar \
            RANLIB=${BASE}/ios-toolchain/ios-arm64e-clang-toolchain/bin/ranlib \
            --host arm64-apple-darwin --prefix=${BASE}/${LIBUNISTRING_VER}/build

          # Patching libtool
          sed -i -e 's/CC="[^"]*/& --target=arm64-apple-darwin/' libtool

          make clean && make -j$(nproc) && make install
          cd ..
      fi

      LIBEVENT_VER=libevent-2.1.12-stable
      LIBEVENT_URL=https://github.com/libevent/libevent/releases/download/release-2.1.12-stable/libevent-2.1.12-stable.tar.gz
      info "Building ${LIBEVENT_VER} for iOS"
      if [ -d "${LIBEVENT_VER}" ]; then
          warn "${LIBEVENT_VER} already exists."
      else
          wget ${LIBEVENT_URL}
          tar -xvf ${LIBEVENT_VER}.tar.gz
          rm -r ${LIBEVENT_VER}.tar.gz
          cd ${LIBEVENT_VER}
          mkdir build
          ./configure \
            CXX=${BASE}/ios-toolchain/ios-arm64e-clang-toolchain/bin/clang++ \
            CC=${BASE}/ios-toolchain/ios-arm64e-clang-toolchain/bin/clang \
            CFLAGS="--target=arm64-apple-darwin -isysroot ${BASE}/ios-sdks/${IOS_SDK}" \
            CXXFLAGS="--target=arm64-apple-darwin" \
            AR=${BASE}/ios-toolchain/ios-arm64e-clang-toolchain/bin/ar \
            RANLIB=${BASE}/ios-toolchain/ios-arm64e-clang-toolchain/bin/ranlib \
            --host arm-apple-darwin --prefix=${BASE}/${LIBEVENT_VER}/build --disable-openssl

          # Patching libtool
          sed -i -e 's/CC="[^"]*/& --target=arm64-apple-darwin/' libtool

          make clean && make -j$(nproc) && make install
          cd ..
      fi

      info "Configuring libdogecoin"
      cd libdogecoin
      ./autogen.sh
      ./configure \
        CXX=${BASE}/ios-toolchain/ios-arm64e-clang-toolchain/bin/clang++ \
        CC=${BASE}/ios-toolchain/ios-arm64e-clang-toolchain/bin/clang \
        AR=${BASE}/ios-toolchain/ios-arm64e-clang-toolchain/bin/ar \
        RANLIB=${BASE}/ios-toolchain/ios-arm64e-clang-toolchain/bin/ranlib \
        CFLAGS="--target=arm64-apple-darwin -isysroot ${BASE}/ios-sdks/${IOS_SDK}" \
        CXXFLAGS="--target=arm64-apple-darwin" \
        CPPFLAGS="-I${BASE}/${LIBUNISTRING_VER}/build/include -I${BASE}/${LIBEVENT_VER}/build/include" \
        LDFLAGS="-L${BASE}/${LIBUNISTRING_VER}/build/lib -L${BASE}/${LIBEVENT_VER}/build/lib" \
        -host arm64-apple-darwin --disable-dependency-tracking

      info "Patching libtool"
      sed -i -e 's/CC="[^"]*/& --target=arm64-apple-darwin/' libtool

      info "Building libdogecoin"
      make clean && make -j$(nproc)

      info "Copying libs"
      cd ..
      if [ -d "build" ]; then
          warn "build already exists."
          cd build
      else
          mkdir build
          cd build
      fi
      cp -r ${BASE}/libdogecoin/.libs/libdogecoin.1.dylib ./libdogecoin.dylib
      cp -r ${BASE}/${LIBUNISTRING_VER}/build/lib/libunistring.5.dylib ./libunistring.dylib
      cp -r ${BASE}/${LIBEVENT_VER}/build/lib/libevent-2.1.7.dylib ./libevent-2.1.dylib
      cp -r ${BASE}/${LIBEVENT_VER}/build/lib/libevent_core-2.1.7.dylib ./libevent_core-2.1.dylib

      info "Creating libdogecoin-lipo"
      ${BASE}/ios-toolchain/ios-arm64e-clang-toolchain/bin/lipo -create libdogecoin.dylib -output libdogecoin-lipo

      info "Creating libunistring-lipo"
      ${BASE}/ios-toolchain/ios-arm64e-clang-toolchain/bin/lipo -create libunistring.dylib -output libunistring-lipo

      info "Creating libevent-2.1-lipo"
      ${BASE}/ios-toolchain/ios-arm64e-clang-toolchain/bin/lipo -create libevent-2.1.dylib -output libevent-2.1-lipo

      info "Creating libevent_core-2.1-lipo"
      ${BASE}/ios-toolchain/ios-arm64e-clang-toolchain/bin/lipo -create libevent_core-2.1.dylib -output libevent_core-2.1-lipo

      info "Creating libdogecoin framework for Xcode"
      mkdir -p ./libdogecoin.framework
      cd libdogecoin.framework
      cp ../libdogecoin-lipo ./libdogecoin
      touch Info.plist

cat << EOF > Info.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
    <dict>
        <key>CFBundleDevelopmentRegion</key>
        <string>en</string>
        <key>CFBundleExecutable</key>
        <string>libdogecoin</string>
        <key>CFBundleIdentifier</key>
        <string>com.dogecoinfdn.libdogecoin</string>
        <key>CFBundleInfoDictionaryVersion</key>
        <string>6.0</string>
        <key>CFBundleName</key>
        <string>libdogecoin</string>
        <key>CFBundlePackageType</key>
        <string>FMWK</string>
        <key>CFBundleShortVersionString</key>
        <string>1.0</string>
        <key>CFBundleVersion</key>
        <string>0.1.2</string>
        <key>NSPrincipalClass</key>
        <string></string>
    </dict>
</plist>
EOF

      cd ..

      info "Creating libunistring framework for Xcode"
      mkdir -p ./libunistring.framework
      cd libunistring.framework
      cp ../libunistring-lipo ./libunistring
      touch Info.plist

cat << EOF > Info.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
    <dict>
        <key>CFBundleDevelopmentRegion</key>
        <string>en</string>
        <key>CFBundleExecutable</key>
        <string>libunistring</string>
        <key>CFBundleIdentifier</key>
        <string>com.dogecoinfdn.libunistring</string>
        <key>CFBundleInfoDictionaryVersion</key>
        <string>6.0</string>
        <key>CFBundleName</key>
        <string>libunistring</string>
        <key>CFBundlePackageType</key>
        <string>FMWK</string>
        <key>CFBundleShortVersionString</key>
        <string>1.0</string>
        <key>CFBundleVersion</key>
        <string>0.1.2</string>
        <key>NSPrincipalClass</key>
        <string></string>
    </dict>
</plist>
EOF

      cd ..

      info "Creating libevent-2.1 framework for Xcode"
      mkdir -p ./libevent-2.1.framework
      cd libevent-2.1.framework
      cp ../libevent-2.1-lipo ./libevent-2.1
      touch Info.plist

cat << EOF > Info.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
    <dict>
        <key>CFBundleDevelopmentRegion</key>
        <string>en</string>
        <key>CFBundleExecutable</key>
        <string>libevent-2.1</string>
        <key>CFBundleIdentifier</key>
        <string>com.dogecoinfdn.libevent-2.1</string>
        <key>CFBundleInfoDictionaryVersion</key>
        <string>6.0</string>
        <key>CFBundleName</key>
        <string>libevent-2.1</string>
        <key>CFBundlePackageType</key>
        <string>FMWK</string>
        <key>CFBundleShortVersionString</key>
        <string>1.0</string>
        <key>CFBundleVersion</key>
        <string>0.1.2</string>
        <key>NSPrincipalClass</key>
        <string></string>
    </dict>
</plist>
EOF

      cd ..

      info "Creating libevent_core-2.1 framework for Xcode"
      mkdir -p ./libevent_core-2.1.framework
      cd libevent_core-2.1.framework
      cp ../libevent_core-2.1-lipo ./libevent_core-2.1
      touch Info.plist

cat << EOF > Info.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
    <dict>
        <key>CFBundleDevelopmentRegion</key>
        <string>en</string>
        <key>CFBundleExecutable</key>
        <string>libevent_core-2.1</string>
        <key>CFBundleIdentifier</key>
        <string>com.dogecoinfdn.libevent_core-2.1</string>
        <key>CFBundleInfoDictionaryVersion</key>
        <string>6.0</string>
        <key>CFBundleName</key>
        <string>libevent_core-2.1</string>
        <key>CFBundlePackageType</key>
        <string>FMWK</string>
        <key>CFBundleShortVersionString</key>
        <string>1.0</string>
        <key>CFBundleVersion</key>
        <string>0.1.2</string>
        <key>NSPrincipalClass</key>
        <string></string>
    </dict>
</plist>
EOF

      cd ..

      info "Patching frameworks"
      ${BASE}/ios-toolchain/ios-arm64e-clang-toolchain/bin/install_name_tool -id @rpath/libdogecoin.framework/libdogecoin libdogecoin.framework/libdogecoin
      ${BASE}/ios-toolchain/ios-arm64e-clang-toolchain/bin/install_name_tool -id @rpath/libunistring.framework/libunistring libunistring.framework/libunistring
      ${BASE}/ios-toolchain/ios-arm64e-clang-toolchain/bin/install_name_tool -id @rpath/libevent-2.1.framework/libevent-2.1 libevent-2.1.framework/libevent-2.1
      ${BASE}/ios-toolchain/ios-arm64e-clang-toolchain/bin/install_name_tool -id @rpath/libevent_core-2.1.framework/libevent_core-2.1 libevent_core-2.1.framework/libevent_core-2.1

      info "Patching framework imports"
      ${BASE}/ios-toolchain/ios-arm64e-clang-toolchain/bin/install_name_tool -change ${BASE}/${LIBUNISTRING_VER}/build/lib/libunistring.5.dylib @rpath/libunistring.framework/libunistring libdogecoin.framework/libdogecoin
      ${BASE}/ios-toolchain/ios-arm64e-clang-toolchain/bin/install_name_tool -change ${BASE}/${LIBEVENT_VER}/build/lib/libevent-2.1.7.dylib @rpath/libevent-2.1.framework/libevent-2.1 libdogecoin.framework/libdogecoin
      ${BASE}/ios-toolchain/ios-arm64e-clang-toolchain/bin/install_name_tool -change ${BASE}/${LIBEVENT_VER}/build/lib/libevent_core-2.1.7.dylib @rpath/libevent_core-2.1.framework/libevent_core-2.1 libdogecoin.framework/libdogecoin

      info "Done! View results in ${BASE}/build"
      info "Created libdogecoin.dylib, libdogecoin-lipo, and unsigned libdogecoin.framework"
      info "Created unsigned libunistring.dylib + lipo + framework and unsigned libevent.dylib + lipo + framework"
      info "For use in Flutter, add all frameworks (libdogecoin, libunistring, libevent*) to your Xcode project."

    fi
}

if [[ ! $1 =~ ^(ios|android)$ ]]
then 
    showHelp
else
  if [ $1 == "ios" ]
  then
    BUILD=ios
  fi

  if [ $1 == "android" ]
  then
    BUILD=android
  fi

  while true; do
      read -p "Do you wish to build libdogecoin for ${BUILD} in $(pwd)/libdogecoin-${BUILD}? (y/n) " yn
      case $yn in
          [Yy]* ) build; exit;;
          [Nn]* ) exit;;
          * ) echo "Please answer yes or no.";;
      esac
  done    
fi
