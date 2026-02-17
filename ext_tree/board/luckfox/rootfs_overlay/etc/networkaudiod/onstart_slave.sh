#!/bin/sh
# Slave onstart: precise time sync + TX reset before playback
# Master BCLK delayed by 200ms in driver - slave always catches clean first edge

TX_RESET="/sys/devices/platform/ffae0000.i2s/tx_reset"

if [ ! -f "$TX_RESET" ]; then
    exit 0
fi

#    Reset I2S TX with precise timing
echo "1" > "$TX_RESET"

#    Force precise time sync with master BEFORE playback starts
#    burst 4/4: get 4 fresh NTP measurements from master
#    waitsync: wait up to 10 tries until offset < 1ms
#    makestep: snap clock to master's exact time
chronyc burst 4/4
chronyc waitsync 10 0.001
chronyc makestep

exit 0
