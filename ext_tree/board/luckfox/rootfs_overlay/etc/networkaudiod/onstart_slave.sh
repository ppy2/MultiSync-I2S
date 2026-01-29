#!/bin/sh
# Slave clock synchronizer reset - GUARANTEED to start AFTER master

TX_RESET="/sys/devices/platform/ffae0000.i2s/tx_reset"

if [ ! -f "$TX_RESET" ]; then
    exit 0
fi

# Reset clock synchronizer
echo "1" > "$TX_RESET"
sleep 0.1

#chronyc burst 2/2 && chronyc waitsync 1 0.1 && chronyc makestep

exit 0
