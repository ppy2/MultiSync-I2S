#!/bin/sh

# Switch to EXT_FULL mode (Full Slave) - 1024fs MCLK
# External MCLK (45.158MHz/49.152MHz), LRCLK, and BCK

sed -i 's/007c003c/007c001c/' /etc/init.d/S94ioi2s
sed -i 's/MCLK=512/MCLK=1024/' /etc/i2s.conf
sed -i 's/MODE=pll/MODE=ext_full/' /etc/i2s.conf
sed -i 's/MODE=ext/MODE=ext_full/' /etc/i2s.conf

flash_erase /dev/mtd3 0x003C0000 0x2
sleep 1
nandwrite -p /dev/mtd3 -s 0x003C0000 /data/boot/1024_ext_full.dtb

sync
#reboot -f
