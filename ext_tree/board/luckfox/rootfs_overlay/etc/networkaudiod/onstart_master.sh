#!/bin/sh
# Master onstart: TX reset only
# BCLK delayed by master_start_delay_ms (500ms) in driver

TX_RESET="/sys/devices/platform/ffae0000.i2s/tx_reset"

if [ ! -f "$TX_RESET" ]; then
    exit 0
fi

echo "1" > "$TX_RESET"
sleep 0.3

exit 0
