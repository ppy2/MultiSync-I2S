#!/bin/sh
# Slave onstart: TX reset + quick time correction before playback

TX_RESET="/sys/devices/platform/ffae0000.i2s/tx_reset"

if [ ! -f "$TX_RESET" ]; then
    exit 0
fi

echo "1" > "$TX_RESET"
sleep 0.4

# Non-blocking time correction: step clock to master if needed
# Chrony is already tracking master continuously (minpoll 4s)
chronyc makestep > /dev/null 2>&1

exit 0
