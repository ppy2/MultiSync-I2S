#!/bin/sh

set -ve

MAINDIR=`pwd`

export LINUX_DIR=`ls -d output/build/linux-main`

# Copy kernel and DTB to binaries
cp $LINUX_DIR/arch/arm/boot/zImage $BINARIES_DIR/
cp $LINUX_DIR/arch/arm/boot/dts/rv1106_pll.dtb $BINARIES_DIR/
cp $LINUX_DIR/arch/arm/boot/dts/rv1106_512_ext.dtb $BINARIES_DIR/
cp $LINUX_DIR/arch/arm/boot/dts/rv1106_512_ext_full.dtb $BINARIES_DIR/

# Copy DTBs to target
cp $LINUX_DIR/arch/arm/boot/dts/rv1106_ext.dtb $TARGET_DIR/data/boot/1024_ext.dtb
cp $LINUX_DIR/arch/arm/boot/dts/rv1106_pll.dtb $TARGET_DIR/data/boot/1024_pll.dtb
cp $LINUX_DIR/arch/arm/boot/dts/rv1106_512_ext.dtb $TARGET_DIR/data/boot/512_ext.dtb
cp $LINUX_DIR/arch/arm/boot/dts/rv1106_ext_full.dtb $TARGET_DIR/data/boot/1024_ext_full.dtb
cp $LINUX_DIR/arch/arm/boot/dts/rv1106_512_ext_full.dtb $TARGET_DIR/data/boot/512_ext_full.dtb

cd $BINARIES_DIR
# Create boot.img with zImage and DTB
dd if=/dev/zero of=boot.img bs=1 count=0 seek=4194304
dd if=zImage of=boot.img conv=notrunc
dd if=rv1106_512_ext.dtb of=boot.img bs=1 seek=3932160 conv=notrunc
rm zImage
cd $MAINDIR

rm -f $TARGET_DIR/etc/init.d/*shairport-sync
rm -f $TARGET_DIR/etc/init.d/*upmpdcli
rm -f $TARGET_DIR/etc/init.d/*urandom
rm -f $TARGET_DIR/etc/init.d/*mpd
rm -f $TARGET_DIR/etc/init.d/S49chronyd
#rm -f $TARGET_DIR/etc/init.d/*mdev
rm -f -r $TARGET_DIR/etc/alsa
#rm -f -r $(TARGET_DIR/var/db
sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin yes/g" $TARGET_DIR/etc/ssh/sshd_config
#wget https://curl.se/ca/cacert.pem -O $TARGET_DIR/etc/ssl/certs/ca-certificates.crt

# Remove GDB Python helper files (they prevent buildroot's strip from working)
find $TARGET_DIR -name "*-gdb.py" -delete

# Strip external toolchain libraries (buildroot's target-finalize runs BEFORE post-build)
# When packages are reinstalled, libraries are copied unstripped, so we strip them here
STRIP_BIN="$HOST_DIR/opt/ext-toolchain/bin/arm-none-linux-gnueabihf-strip"
if [ -f "$TARGET_DIR/lib/libstdc++.so.6.0.33" ] && file "$TARGET_DIR/lib/libstdc++.so.6.0.33" | grep -q "not stripped"; then
    echo "Stripping external toolchain libraries..."
    find $TARGET_DIR/lib -name "*.so*" -type f -exec $STRIP_BIN {} \; 2>/dev/null || true
fi






