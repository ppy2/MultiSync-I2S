#!/bin/sh

PINCTRL="/sys/devices/platform/ffae0000.i2s/pinctrl_state"
TX_RESET="/sys/devices/platform/ffae0000.i2s/tx_reset"

# Check if control interfaces are available
if [ ! -f "$PINCTRL" ] || [ ! -f "$TX_RESET" ]; then
    exit 0
fi

# Step 1: Disconnect MCLK/BCK/LRCLK inputs (switch to GPIO mode)
# This isolates clock synchronizer from external clocks
echo "idle" > "$PINCTRL"

#echo 1 > /sys/devices/platform/ffae0000.i2s/mute

# Step 2: Perform TX/RX reset while clocks are disconnected
# This resets clock synchronizer to initial state without MCLK influence
echo "1" > "$TX_RESET"
# Wait for clock synchronizer stabilization
sleep 0.3

# Step 3: Reconnect MCLK/BCK/LRCLK inputs (switch to I2S mode)
# Clock synchronizer starts from clean state
echo "default" > "$PINCTRL"

#echo 0 > /sys/devices/platform/ffae0000.i2s/mute

exit 0
