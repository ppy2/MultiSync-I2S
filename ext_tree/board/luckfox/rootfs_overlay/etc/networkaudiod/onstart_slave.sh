#!/bin/sh
# Slave onstart: precise time sync + TX reset before playback
# Master BCLK delayed by 500ms in driver

TX_RESET="/sys/devices/platform/ffae0000.i2s/tx_reset"

if [ ! -f "$TX_RESET" ]; then
    exit 0
fi

echo "1" > "$TX_RESET"
sleep 0.4

# Time sync: burst for fresh NTP samples, waitsync with short timeout
# waitsync 3 = max 3 retries (~3s). || true = proceed if chrony not ready yet
# Normal case (chrony synced): returns instantly
# After reboot (no samples): waits max ~3s then proceeds anyway
chronyc burst 4/4 > /dev/null 2>&1
chronyc waitsync 3 0.001 > /dev/null 2>&1 || true
chronyc makestep > /dev/null 2>&1

exit 0
