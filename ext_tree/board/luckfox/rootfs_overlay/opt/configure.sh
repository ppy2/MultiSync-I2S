#!/bin/sh
# Usage: configure.sh <ext|pll> <512|1024> <master|slave>
#
# This changes only the persistent role configuration and mtd3 DTB slot.
# It intentionally never installs networkaudiod playback hooks and never reboots.

set -eu

if [ $# -ne 3 ]; then
    echo "Usage: $0 <ext|pll> <512|1024> <master|slave>"
    exit 1
fi

MODE=$1
MCLK=$2
ROLE=$3
BOOT=/dev/mtd3
DTB_OFF=3932160
DTB_SIZE=262144

case $MODE in
    ext|pll) ;;
    *) echo "Error: MODE must be ext or pll"; exit 1 ;;
esac

case $MCLK in
    512|1024) ;;
    *) echo "Error: MCLK must be 512 or 1024"; exit 1 ;;
esac

case $ROLE in
    master|slave) ;;
    *) echo "Error: ROLE must be master or slave"; exit 1 ;;
esac

if [ "$ROLE" = slave ]; then
    I2S_MODE=ext_full
    DTB_FILE="${MCLK}_ext_full.dtb"
    CHRONY_SOURCE=/etc/chrony.conf.slave
elif [ "$MODE" = ext ]; then
    I2S_MODE=ext
    DTB_FILE="${MCLK}_ext.dtb"
    CHRONY_SOURCE=/etc/chrony.conf.master
else
    [ "$MCLK" = 1024 ] || {
        echo "Error: PLL mode supports only 1024fs"
        exit 1
    }
    I2S_MODE=pll
    DTB_FILE=1024_pll.dtb
    CHRONY_SOURCE=/etc/chrony.conf.master
fi

DTB_PATH="/data/boot/$DTB_FILE"
[ -r "$DTB_PATH" ] || {
    echo "Error: missing DTB $DTB_PATH"
    exit 1
}
DTB_BYTES=$(wc -c < "$DTB_PATH")
[ "$DTB_BYTES" -gt 0 ] && [ "$DTB_BYTES" -le "$DTB_SIZE" ] || {
    echo "Error: invalid DTB size: $DTB_BYTES"
    exit 1
}
[ "$(dd if="$DTB_PATH" bs=1 count=4 2>/dev/null | od -An -tx1 | tr -d ' ')" = d00dfeed ] || {
    echo "Error: $DTB_PATH has no FDT magic"
    exit 1
}
[ -r "$CHRONY_SOURCE" ] || {
    echo "Error: missing chrony role config $CHRONY_SOURCE"
    exit 1
}

echo "Configuring role: mode=$MODE mclk=$MCLK role=$ROLE i2s=$I2S_MODE dtb=$DTB_FILE"

# Playback hooks are intentionally forbidden: HQPlayer Combo owns start/stop.
rm -f /etc/networkaudiod/onstart /etc/networkaudiod/onstop \
      /etc/networkaudiod/onstart_master.sh /etc/networkaudiod/onstart_slave.sh
rm -f /opt/onstart_master.sh /opt/onstart_slave.sh /opt/onstop

sed -i "s/MODE=.*/MODE=$I2S_MODE/" /etc/i2s.conf
sed -i "s/MCLK=.*/MCLK=$MCLK/" /etc/i2s.conf
echo "$ROLE" > /etc/hostname
cp "$CHRONY_SOURCE" /etc/chrony.conf

# Keep the outgoing DTB slot as an explicit rollback artifact.
STAMP=$(date +%s)
BACKUP="/data/boot/configure-prechange-${STAMP}.dtb"
VERIFY=/tmp/configure-dtb-readback.dtb
mtd_debug read "$BOOT" "$DTB_OFF" "$DTB_SIZE" "$BACKUP"
[ "$(dd if="$BACKUP" bs=1 count=4 2>/dev/null | od -An -tx1 | tr -d ' ')" = d00dfeed ] || {
    echo "Error: current mtd3 DTB slot invalid; refusing overwrite"
    exit 1
}

flash_erase "$BOOT" 0x003c0000 2
nandwrite -p "$BOOT" -s 0x003c0000 "$DTB_PATH"
mtd_debug read "$BOOT" "$DTB_OFF" "$DTB_BYTES" "$VERIFY"
cmp "$DTB_PATH" "$VERIFY"
rm -f "$VERIFY"

# Role change needs chrony role settings now; it does not start/stop NAA.
/etc/init.d/S41chronyd restart
sync

echo "Role configuration and DTB readback verified. Manual reboot required."
