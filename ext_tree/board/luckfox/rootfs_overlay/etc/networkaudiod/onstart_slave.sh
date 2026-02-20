#!/bin/sh
# Slave onstart: TX reset + quick time correction before playback

TX_RESET="/sys/devices/platform/ffae0000.i2s/tx_reset"

if [ ! -f "$TX_RESET" ]; then
    exit 0
fi

echo "1" > "$TX_RESET"

# Non-blocking time correction: step clock to master if needed
# Chrony is already tracking master continuously (minpoll 4s)
# No waitsync — it blocks too long after reboot when chrony has no samples yet
chronyc makestep > /dev/null 2>&1

exit 0
