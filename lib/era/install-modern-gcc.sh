#!/usr/bin/env bash
set -Eeuo pipefail

(( _IN_EPOCSTRAP ))

_gcce_build_target () {
  local dir name prefix
  dir=${1:?missing dir}
  name=${2:-$dir}
  prefix=${3:-$GCCE1210_PREFIX}
  shift 3

  >&2 echo "  ==> Building ${name}"
  &>/dev/null pushd "${dir}"/
    shopt -s nullglob
    >&2 echo "   ==> Patching ${name}"
    for patch in "${_AUX_DIR}"/patch/"${dir}"/*.patch ; do
      >&2 echo "    ==> Applying ${patch}"
      >/dev/null POSIXLY_CORRECT=1 patch -p1 -Nr- <"${patch}" &>/dev/null ||:
    done
    shopt -u nullglob

    rm -rf _builddir/
    mkdir -p _builddir/
    &>/dev/null pushd _builddir/
      >&2 echo "   ==> Configuring ${name}"
      >&2 make distclean ||:
      shopt -s globstar nullglob
      >&2 rm -f ./**/config.cache ||:
      shopt -u globstar nullglob
      >&2 PATH="${_AUX_DIR}"/stubs:"${PATH}" ../configure \
        --prefix="$(realpath -- "${prefix}")" \
        "$@" \
        CXXFLAGS="-O2" \
        CFLAGS="-O2" \
        ASFLAGS="-O2" \
        LDFLAGS="-O2"
      >&2 make clean
      >&2 echo "   ==> Making ${name}"
      # NOTABUG: Modern GCC throws errors on builds
      >&2 PATH="${_AUX_DIR}"/stubs:"${PATH}" make -k ${MAKEFLAGS} ||:
      >&2 echo "   ==> Installing ${name}"
      >&2 PATH="${_AUX_DIR}"/stubs:"${PATH}" make -k install-strip ||:
    &>/dev/null popd
  &>/dev/null popd
}

rm -rf "${GCCE1210_PREFIX}"

>&2 echo ' ==> Downloading GNU GCC'
&>/dev/null rm -rf gccm/
&>/dev/null mkdir -p gccm/
&>/dev/null pushd gccm/
  &>/dev/null mkdir -p binutils/
  &>/dev/null pushd binutils/
    [[ ! -f "../binutils.tbz2" ]] \
      && wget -O ../binutils.tbz2 "${GCCM_BINUTILS_URL:-https://ftp.gnu.org/gnu/binutils/binutils-2.35.tar.bz2}"
    tar -xjf ../binutils.tbz2 --strip-components=1
  &>/dev/null popd
  &>/dev/null mkdir -p isl/
  &>/dev/null pushd isl/
    [[ ! -f "../isl.tbz2" ]] \
      && wget -O ../isl.tbz2 "${GCCM_ISL_URL:-https://libisl.sourceforge.io/isl-0.15.tar.bz2}"
    tar -xjf ../isl.tbz2 --strip-components=1
  &>/dev/null popd
  &>/dev/null mkdir -p gcc/
  &>/dev/null pushd gcc/
    [[ ! -f "../gcc.tbz2" ]] \
      && wget -O ../gcc.txz "${GCCM_GCC_URL:-https://gcc.gnu.org/pub/gcc/releases/gcc-12.1.0/gcc-12.1.0.tar.xz}"
    tar -xJf ../gcc.txz --strip-components=1
    ln -sf ../isl .
  &>/dev/null popd
&>/dev/null popd

>&2 echo ' ==> Building GNU GCC'
&>/dev/null pushd gccm/
  _GCCM_BUILD_ROOT="$(pwd)"

  _gcce_build_target binutils '' '' \
    --target=arm-none-symbianelf \
    --enable-ld \
    --enable-vtable-verify \
    --enable-werror=no \
    --without-headers \
    --disable-nls \
    --disable-shared \
    --disable-libstdcxx \
    --disable-libquadmath \
    --enable-plugins \
    --enable-multilib \
    --enable-lto \
    --enable-deterministic-archives

  _gcce_build_target gcc GCC '' \
    --target=arm-none-symbianelf \
    --without-headers \
    --enable-languages="c,c++,lto" \
    --enable-lto \
    --enable-interwork \
    --enable-long-long \
    --enable-tls \
    --enable-multilib \
    --enable-wchar_t \
    --enable-c99 \
    --with-newlib \
    --with-dwarf2 \
    --with-static-standard-libraries \
    --disable-hosted-libstdcxx \
    --disable-libstdcxx-pch \
    --disable-shared \
    --disable-option-checking \
    --disable-threads \
    --disable-nls \
    --disable-win32-registry \
    --disable-libssp \
    --disable-libquadmath
&>/dev/null popd

"${GCCE1210_PREFIX}/bin/arm-none-symbianelf-g++" -x "c++" -nostdlib -o /dev/null - <<<"int main(){}"
