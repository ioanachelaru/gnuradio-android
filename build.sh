set -xe

#############################################################
### CONFIG
#############################################################
export TOOLCHAIN_ROOT=$ANDROID_NDK

#############################################################
### DERIVED CONFIG
#############################################################
export SYS_ROOT=$SYSROOT
export BUILD_ROOT=$(dirname $(readlink -f "$0"))
export PATH=${TOOLCHAIN_BIN}:${PATH}
export PREFIX=${BUILD_ROOT}/toolchain/armeabi-v7a
export NCORES=$(getconf _NPROCESSORS_ONLN)

mkdir -p ${PREFIX}

echo $SYS_ROOT $BUILD_ROOT $PATH $PREFIX
#############################################################
### BOOST
#############################################################

build_boost() {

## ADI COMMENT PULL LATEST

cd ${BUILD_ROOT}/Boost-for-Android
git clean -xdf

#./build-android.sh --boost=1.69.0 --toolchain=llvm --prefix=$(dirname ${PREFIX}) --arch=armeabi-v7a --target-version=28 ${TOOLCHAIN_ROOT}

./build-android.sh --boost=1.69.0 --layout=system --toolchain=llvm --prefix=$(dirname ${PREFIX}) --arch=armeabi-v7a --target-version=28 ${TOOLCHAIN_ROOT}
}

#############################################################
### ZEROMQ
#############################################################

build_libzmq() {
cd ${BUILD_ROOT}/libzmq
git clean -xdf

./autogen.sh
./configure --enable-static --disable-shared --host=arm-linux-androideabi --prefix=${PREFIX} LDFLAGS="-L${PREFIX}/lib" CPPFLAGS="-fPIC -I${PREFIX}/include" LIBS="-lgcc"

make -j ${NCORES}
make install

# CXX Header-Only Bindings
wget -O $PREFIX/include/zmq.hpp https://raw.githubusercontent.com/zeromq/cppzmq/master/zmq.hpp
}

#############################################################
### FFTW
#############################################################
build_fftw() {
## ADI COMMENT: USE downloaded version instead (OCAML fail?)
cd ${BUILD_ROOT}/
#wget http://www.fftw.org/fftw-3.3.9.tar.gz
rm -rf fftw-3.3.9
tar xvf fftw-3.3.9.tar.gz
cd fftw-3.3.9
#git clean -xdf

./configure --enable-single --enable-static --enable-threads \
  --enable-float  --enable-neon --disable-doc \
  --host=arm-linux-androideabi \
  --prefix=$PREFIX

make -j ${NCORES}
make install
}

#############################################################
### OPENSSL
#############################################################
build_openssl() {
cd ${BUILD_ROOT}/openssl
git clean -xdf

export ANDROID_NDK_HOME=${TOOLCHAIN_ROOT}

./Configure android-arm -D__ARM_MAX_ARCH__=7 --prefix=${PREFIX} shared no-ssl3 no-comp
make -j ${NCORES}
make install
}

#############################################################
### THRIFT
#############################################################
build_thrift() {
cd ${BUILD_ROOT}/thrift
git clean -xdf
rm -rf ${PREFIX}/include/thrift

./bootstrap.sh

CPPFLAGS="-I${PREFIX}/include" \
CFLAGS="-fPIC" \
CXXFLAGS="-fPIC" \
LDFLAGS="-L${PREIX}/lib" \
./configure --prefix=${PREFIX}   --disable-tests --disable-tutorial --with-cpp \
 --without-python --without-qt4 --without-qt5 --without-py3 --without-go --without-nodejs --without-c_glib --without-php --without-csharp --without-java \
 --without-libevent --without-zlib \
 --with-boost=${PREFIX} --host=arm-linux-androideabi --build=x86_64-linux

sed -i '/malloc rpl_malloc/d' ./lib/cpp/src/thrift/config.h
sed -i '/realloc rpl_realloc/d' ./lib/cpp/src/thrift/config.h

make -j ${NCORES}
make install

sed -i '/malloc rpl_malloc/d' ${PREFIX}/include/thrift/config.h
sed -i '/realloc rpl_realloc/d' ${PREFIX}/include/thrift/config.h
}

#############################################################
### GMP
#############################################################
build_libgmp() {
ABI_BACKUP=$ABI
ABI=""
cd ${BUILD_ROOT}/libgmp
git clean -xdf

./.bootstrap
./configure --enable-maintainer-mode --prefix=${PREFIX} \
            --host=arm-linux-androideabi \
            --enable-cxx
make -j ${NCORES}
make install
ABI=$ABI_BACKUP
}

#############################################################
### LIBUSB
#############################################################
build_libusb() {
cd ${BUILD_ROOT}/libusb/android/jni
git clean -xdf

export NDK=${TOOLCHAIN_ROOT}
${NDK}/ndk-build

cp ${BUILD_ROOT}/libusb/android/libs/armeabi-v7a/* ${PREFIX}/lib
cp ${BUILD_ROOT}/libusb/libusb/libusb.h ${PREFIX}/include
}

#############################################################
### HACK RF
#############################################################
build_hackrf() {
cd ${BUILD_ROOT}/hackrf/host/
git clean -xdf

mkdir build
cd build

cmake -DCMAKE_INSTALL_PREFIX=${PREFIX} \
  -DCMAKE_TOOLCHAIN_FILE=${TOOLCHAIN_ROOT}/build/cmake/android.toolchain.cmake \
  -DANDROID_ABI=armeabi-v7a -DANDROID_ARM_NEON=ON \
  -DANDROID_NATIVE_API_LEVEL=${API_LEVEL} \
  -DCMAKE_FIND_ROOT_PATH=${PREFIX} \
  ../

make -j ${NCORES}
make install
}

# #############################################################
# ### VOLK
#############################################################
build_volk() {
cd ${BUILD_ROOT}/volk
git clean -xdf

mkdir build
cd build
cmake -DCMAKE_INSTALL_PREFIX=${PREFIX} \
  -DCMAKE_TOOLCHAIN_FILE=${TOOLCHAIN_ROOT}/build/cmake/android.toolchain.cmake \
  -DANDROID_ABI=armeabi-v7a -DANDROID_ARM_NEON=ON \
  -DANDROID_STL=c++_shared \
  -DANDROID_NATIVE_API_LEVEL=28 \
  -DPYTHON_EXECUTABLE=/usr/bin/python3 \
  -DBOOST_ROOT=${PREFIX} \
  -DBoost_COMPILER=-clang \
  -DBoost_USE_STATIC_LIBS=ON \
  -DBoost_ARCHITECTURE=-a32 \
  -DENABLE_STATIC_LIBS=True \
  -DCMAKE_FIND_ROOT_PATH=${PREFIX} \
  ../
make -j ${NCORES}
make install
}

#############################################################
### GNU Radio
#############################################################
build_gnuradio() {
cd ${BUILD_ROOT}/gnuradio
git clean -xdf

mkdir build
cd build

echo $LDFLAGS

cmake -DCMAKE_INSTALL_PREFIX=${PREFIX} \
  -DCMAKE_TOOLCHAIN_FILE=${TOOLCHAIN_ROOT}/build/cmake/android.toolchain.cmake \
  -DANDROID_ABI=armeabi-v7a -DANDROID_ARM_NEON=ON \
  -DANDROID_STL=c++_shared \
  -DANDROID_NATIVE_API_LEVEL=28 \
  -DPYTHON_EXECUTABLE=/usr/bin/python3 \
  -DENABLE_INTERNAL_VOLK=OFF \
  -DBOOST_ROOT=${PREFIX} \
  -DBoost_COMPILER=-clang \
  -DBoost_USE_STATIC_LIBS=ON \
  -DBoost_ARCHITECTURE=-a32 \
  -DCMAKE_FIND_ROOT_PATH=${PREFIX} \
  -DENABLE_DOXYGEN=OFF \
  -DENABLE_SPHINX=OFF \
  -DENABLE_PYTHON=OFF \
  -DENABLE_TESTING=OFF \
  -DENABLE_GR_FEC=OFF \
  -DENABLE_GR_AUDIO=OFF \
  -DENABLE_GR_DTV=OFF \
  -DENABLE_GR_CHANNELS=OFF \
  -DENABLE_GR_VOCODER=OFF \
  -DENABLE_GR_TRELLIS=OFF \
  -DENABLE_GR_WAVELET=OFF \
  -DENABLE_GR_CTRLPORT=OFF \
  -DENABLE_CTRLPORT_THRIFT=OFF \
  -DCMAKE_C_FLAGS=$CFLAGS \
  -DCMAKE_CXX_FLAGS=$CPPFLAGS \
  -DCMAKE_SHARED_LINKER_FLAGS=$LDFLAGS \
  -DCMAKE_VERBOSE_MAKEFILE=ON \
   ../
make -j ${NCORES}
make install
}

#############################################################
### GR OSMOSDR
#############################################################
build_gr-osmosdr() {
cd ${BUILD_ROOT}/gr-osmosdr
git clean -xdf

mkdir build
cd build

cmake -DCMAKE_INSTALL_PREFIX=${PREFIX} \
  -DCMAKE_TOOLCHAIN_FILE=${TOOLCHAIN_ROOT}/build/cmake/android.toolchain.cmake \
  -DANDROID_ABI=armeabi-v7a -DANDROID_ARM_NEON=ON \
  -DANDROID_NATIVE_API_LEVEL=${API_LEVEL} \
  -DBOOST_ROOT=${PREFIX} \
  -DBoost_COMPILER=-clang \
  -DBoost_USE_STATIC_LIBS=ON \
  -DBoost_ARCHITECTURE=-a32 \
  -DGnuradio_DIR=${BUILD_ROOT}/toolchain/armeabi-v7a/lib/cmake/gnuradio \
  -DENABLE_REDPITAYA=OFF \
  -DENABLE_RFSPACE=OFF \
  -DCMAKE_FIND_ROOT_PATH=${PREFIX} \
  ../
make -j ${NCORES}
make install
}

#############################################################
### GR GRAND
#############################################################
build_gr-grand() {
cd ${BUILD_ROOT}/gr-grand
git clean -xdf

mkdir build
cd build

cmake -DCMAKE_INSTALL_PREFIX=${PREFIX} \
  -DCMAKE_TOOLCHAIN_FILE=${TOOLCHAIN_ROOT}/build/cmake/android.toolchain.cmake \
  -DANDROID_ABI=armeabi-v7a -DANDROID_ARM_NEON=ON \
  -DANDROID_NATIVE_API_LEVEL=${API_LEVEL} \
  -DBOOST_ROOT=${PREFIX} \
  -DBoost_COMPILER=-clang \
  -DBoost_USE_STATIC_LIBS=ON \
  -DBoost_ARCHITECTURE=-a32 \
  -DGnuradio_DIR=${BUILD_ROOT}/toolchain/armeabi-v7a/lib/cmake/gnuradio \
  -DCMAKE_FIND_ROOT_PATH=${PREFIX} \
    ../

make -j ${NCORES}
make install
}

#############################################################
### GR SCHED
#############################################################
build_gr-sched() {
cd ${BUILD_ROOT}/gr-sched
git clean -xdf

mkdir build
cd build

cmake -DCMAKE_INSTALL_PREFIX=${PREFIX} \
  -DCMAKE_TOOLCHAIN_FILE=${TOOLCHAIN_ROOT}/build/cmake/android.toolchain.cmake \
  -DANDROID_ABI=armeabi-v7a -DANDROID_ARM_NEON=ON \
  -DANDROID_NATIVE_API_LEVEL=${API_LEVEL} \
  -DBOOST_ROOT=${PREFIX} \
  -DBoost_COMPILER=-clang \
  -DBoost_USE_STATIC_LIBS=ON \
  -DBoost_ARCHITECTURE=-a32 \
  -DGnuradio_DIR=${BUILD_ROOT}/toolchain/armeabi-v7a/lib/cmake/gnuradio \
  -DCMAKE_FIND_ROOT_PATH=${PREFIX} \
  ../

make -j ${NCORES}
make install
}

build_boost
build_libzmq
build_fftw
#build_openssl
#build_thrift
build_libgmp
build_libusb
#build_hackrf
build_volk
build_gnuradio
#build_gr-osmosdr
#build_gr-grand
#build_gr-sched
