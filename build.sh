#!/bin/sh

set -eu

apt-get install -y git rsync build-essential cmake device-tree-compiler bc binutils libncurses-dev clang
git config --global http.version HTTP/1.1
git config --global http.postBuffer 157286400
cd buildroot
rm -rf output/target ; find output/ -name ".stamp_target_installed" -delete ; rm -f output/build/host-gcc-final-*/.stamp_host_installed
make BR2_EXTERNAL=../ext_tree luckfox_pico_max_defconfig
export FORCE_UNSAFE_CONFIGURE=1
export LIBCLANG_PATH=/usr/lib/llvm-14/lib
export CLANG_PATH=/usr/bin/clang
export BINDGEN_EXTRA_CLANG_ARGS="--sysroot=`pwd`/output/host/arm-buildroot-linux-gnueabihf/sysroot"

# The kernel source tree is patched in place by Buildroot.  Invalidate only
# that package when the deployed I2S patch profile changes; do not reuse a
# source tree patched by an older dirty checkout.
KERNEL_PROFILE_STAMP="$(pwd)/output/.purefox-linux-patch-profile"
KERNEL_PROFILE_INPUTS="../ext_tree/configs/luckfox_pico_max_defconfig \
../ext_tree/board/luckfox/config/linux.config \
../ext_tree/patches/linux_rv1106.patch \
../ext_tree/patches/linux_rv1106_deployed_sync.patch"
KERNEL_PROFILE=$(sha256sum $KERNEL_PROFILE_INPUTS | sha256sum | cut -d' ' -f1)
KERNEL_DIR="$(pwd)/output/build/linux-main"
if [ -d "$KERNEL_DIR" ] && {
    [ ! -f "$KERNEL_PROFILE_STAMP" ] ||
    [ "$(cat "$KERNEL_PROFILE_STAMP")" != "$KERNEL_PROFILE" ];
}; then
    make linux-dirclean
fi

make

printf '%s\n' "$KERNEL_PROFILE" > "$KERNEL_PROFILE_STAMP.tmp"
mv -f "$KERNEL_PROFILE_STAMP.tmp" "$KERNEL_PROFILE_STAMP"





