#!/bin/sh

sed -i 's/007c003c/007c001c/' /etc/init.d/S94ioi2s
sed -i 's/MODE=pll/MODE=ext/' /etc/i2s.conf
sed -i 's/MCLK=1024/MCLK=512/' /etc/i2s.conf
echo master > /etc/hostname
rm -f /etc/networkaudiod/onstart
ln -s /etc/networkaudiod/onstart_master.sh /etc/networkaudiod/onstart

# Configure chrony for master mode (NTP server)
echo "Configuring chrony for master mode (NTP server)..."
cat /etc/chrony.conf.master  > /etc/chrony.conf
/etc/init.d/S60chronyd restart
echo "Chrony configured as NTP server for slave node"

flash_erase /dev/mtd3 0x003C0000 0x2
sleep 1
nandwrite -p /dev/mtd3 -s 0x003C0000 /data/boot/512_ext.dtb

sync
reboot -f



