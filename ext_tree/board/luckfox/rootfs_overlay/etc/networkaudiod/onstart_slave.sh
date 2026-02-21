#!/bin/sh
# Slave onstart: precise time sync + TX reset before playback
# Master BCLK delayed by 500ms in driver

TX_RESET="/sys/devices/platform/ffae0000.i2s/tx_reset"

if [ ! -f "$TX_RESET" ]; then
    exit 0
fi

# 1. Force precise time sync with master BEFORE playback starts
#    makestep first: snap clock immediately (critical after reboot when offset is large)
#    burst 4/4: get 4 fresh NTP measurements from master
#    waitsync: wait up to 3 tries until offset < 1ms (instant if already synced)
#    makestep again: apply any remaining correction
chronyc makestep
chronyc burst 4/4
chronyc waitsync 3 0.001 || true
chronyc makestep

# 2. Reset I2S TX
echo "1" > "$TX_RESET"

exit 0
