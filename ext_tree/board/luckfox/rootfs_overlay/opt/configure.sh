#!/bin/sh

# Usage: configure.sh <ext|pll> <512|1024> <master|slave>

if [ $# -ne 3 ]; then
    echo "Usage: $0 <ext|pll> <512|1024> <master|slave>"
    echo ""
    echo "Examples:"
    echo "  $0 ext 512 master   - EXT mode, 512fs, master"
    echo "  $0 ext 1024 slave   - EXT mode, 1024fs, slave"
    echo "  $0 pll 1024 master   - PLL mode, 1024fs, master"
    echo "  $0 pll 1024 slave   - PLL mode, 1024fs, slave"
    exit 1
fi

MODE=$1
MCLK=$2
ROLE=$3

# Validate parameters
case $MODE in
    ext) ;;
    pll) ;;
    *)
        echo "Error: MODE must be 'ext' or 'pll'"
        exit 1
        ;;
esac

case $MCLK in
    512) ;;
    1024) ;;
    *)
        echo "Error: MCLK must be 512 or 1024"
        exit 1
        ;;
esac

case $ROLE in
    master) ;;
    slave) ;;
    *)
        echo "Error: ROLE must be 'master' or 'slave'"
        exit 1
        ;;
esac

# Determine I2S mode and DTB file
# Slave has priority over MODE - always uses ext_full
if [ "$ROLE" = "slave" ]; then
    I2S_MODE="ext_full"
    DTB_FILE="${MCLK}_ext_full.dtb"
else
    # Master mode
    if [ "$MODE" = "ext" ]; then
        I2S_MODE="ext"
        DTB_FILE="${MCLK}_ext.dtb"
    else
        # PLL master mode
        I2S_MODE="pll"
        DTB_FILE="1024_pll.dtb"
    fi
fi

echo "Configuring RV1106:"
echo "  Mode: $MODE"
echo "  MCLK: $MCLK"
echo "  Role: $ROLE"
echo "  I2S Mode: $I2S_MODE"
echo "  DTB: $DTB_FILE"

# Configure i2s.conf
sed -i "s/MODE=.*/MODE=$I2S_MODE/" /etc/i2s.conf
sed -i "s/MCLK=.*/MCLK=$MCLK/" /etc/i2s.conf

# Configure hostname
echo $ROLE > /etc/hostname

# Configure onstart script
rm -f /etc/networkaudiod/onstart
if [ "$ROLE" = "master" ]; then
    ln -s /etc/networkaudiod/onstart_master.sh /etc/networkaudiod/onstart

    # Configure chrony for master mode (NTP server)
    echo "Configuring chrony for master mode (NTP server)..."
    cat /etc/chrony.conf.master > /etc/chrony.conf
    /etc/init.d/S60chronyd restart
    echo "Chrony configured as NTP server for slave node"
else
    ln -s /etc/networkaudiod/onstart_slave.sh /etc/networkaudiod/onstart

    # Configure chrony to sync from master via NTP (nanosecond precision)
    echo "Configuring chrony for slave mode (NTP from master)..."
    cat /etc/chrony.conf.slave > /etc/chrony.conf
    /etc/init.d/S60chronyd restart
    echo "Chrony configured - nanosecond precision time sync from master"
fi

# Flash DTB
echo "Flashing DTB: /data/boot/$DTB_FILE"
flash_erase /dev/mtd3 0x003C0000 0x2
sleep 1
nandwrite -p /dev/mtd3 -s 0x003C0000 /data/boot/$DTB_FILE

sync
echo "Configuration complete. Rebooting..."
reboot -f
