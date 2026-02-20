#!/bin/sh
#
# I2S output pins drive strength control for RV1106
#
# Controls drive strength of BCK, LRCLK, and SDO0-SDO3 pins.
# MCLK (input) and SDI0 (input) are not affected.
#
# Higher drive strength = stronger output signal but more noise
# coupling to MCLK input. Lower = cleaner MCLK but weaker output.
#
# Usage: drv_strength.sh [0-7|show]

# RV1106 IOC base + GPIO2 drive strength offset
# Register layout: 2 pins per 32-bit reg, 8 bits per pin
# Upper 16 bits = write mask, lower 16 bits = value
REG_A0_A1=0xff5480C0   # GPIO2_A0 (BCK) [7:0]  + GPIO2_A1 (LRCLK) [15:8]
REG_A2_A3=0xff5480C4   # GPIO2_A2 (MCLK) [7:0] + GPIO2_A3 (SDO3)  [15:8]
REG_A4_A5=0xff5480C8   # GPIO2_A4 (SDO0) [7:0] + GPIO2_A5 (SDI0)  [15:8]
REG_A6_A7=0xff5480CC   # GPIO2_A6 (SDO2) [7:0] + GPIO2_A7 (SDO1)  [15:8]

# Thermometer code: level N -> (1 << (N+1)) - 1
drv_val() {
    case $1 in
        0) echo "0x01" ;;
        1) echo "0x03" ;;
        2) echo "0x07" ;;
        3) echo "0x0F" ;;
        4) echo "0x1F" ;;
        5) echo "0x3F" ;;
        6) echo "0x7F" ;;
        7) echo "0xFF" ;;
    esac
}

# Decode thermometer code back to level
decode_drv() {
    case $1 in
        0|00) echo "0*" ;;
        1|01) echo "0" ;;
        3|03) echo "1" ;;
        7|07) echo "2" ;;
        15|0f|0F) echo "3" ;;
        31|1f|1F) echo "4" ;;
        63|3f|3F) echo "5" ;;
        127|7f|7F) echo "6" ;;
        255|ff|FF) echo "7" ;;
        *) echo "?($1)" ;;
    esac
}

show_current() {
    echo "I2S output drive strength (RV1106)"
    echo "==================================="

    val=$(io -4 $REG_A0_A1 2>/dev/null | awk -F': ' '{print $2}')
    a0=$(printf "%d" "0x$(echo $val | cut -c7-8)")
    a1=$(printf "%d" "0x$(echo $val | cut -c5-6)")
    echo "BCK   (GPIO2_A0) : level $(decode_drv $a0)"
    echo "LRCLK (GPIO2_A1) : level $(decode_drv $a1)"

    val=$(io -4 $REG_A2_A3 2>/dev/null | awk -F': ' '{print $2}')
    a2=$(printf "%d" "0x$(echo $val | cut -c7-8)")
    a3=$(printf "%d" "0x$(echo $val | cut -c5-6)")
    echo "MCLK  (GPIO2_A2) : level $(decode_drv $a2)  [input, not changed]"
    echo "SDO3  (GPIO2_A3) : level $(decode_drv $a3)"

    val=$(io -4 $REG_A4_A5 2>/dev/null | awk -F': ' '{print $2}')
    a4=$(printf "%d" "0x$(echo $val | cut -c7-8)")
    a5=$(printf "%d" "0x$(echo $val | cut -c5-6)")
    echo "SDO0  (GPIO2_A4) : level $(decode_drv $a4)"
    echo "SDI0  (GPIO2_A5) : level $(decode_drv $a5)  [input, not changed]"

    val=$(io -4 $REG_A6_A7 2>/dev/null | awk -F': ' '{print $2}')
    a6=$(printf "%d" "0x$(echo $val | cut -c7-8)")
    a7=$(printf "%d" "0x$(echo $val | cut -c5-6)")
    echo "SDO2  (GPIO2_A6) : level $(decode_drv $a6)"
    echo "SDO1  (GPIO2_A7) : level $(decode_drv $a7)"
}

set_level() {
    level=$1
    val=$(drv_val $level)
    raw=$(printf "0x%02X" $(($(printf "%d" $val))))

    echo "Setting I2S output drive strength to level $level ($val)"

    # A0 (BCK) + A1 (LRCLK) - both outputs
    v=$(printf "0x%08X" $(( (0xFFFF << 16) | ($raw << 8) | $raw )))
    io -4 $REG_A0_A1 $v

    # A3 (SDO3) only - skip A2 (MCLK input)
    v=$(printf "0x%08X" $(( (0xFF << 24) | ($raw << 8) )))
    io -4 $REG_A2_A3 $v

    # A4 (SDO0) only - skip A5 (SDI0 input)
    v=$(printf "0x%08X" $(( (0xFF << 16) | $raw )))
    io -4 $REG_A4_A5 $v

    # A6 (SDO2) + A7 (SDO1) - both outputs
    v=$(printf "0x%08X" $(( (0xFFFF << 16) | ($raw << 8) | $raw )))
    io -4 $REG_A6_A7 $v

    echo ""
    show_current
}

# Main
case "$1" in
    show|"")
        show_current
        ;;
    [0-7])
        set_level $1
        ;;
    *)
        echo "Usage: $0 [0-7|show]"
        echo ""
        echo "  0-7   Set drive strength level (0=min, 7=max)"
        echo "  show  Display current drive strength (default)"
        echo ""
        echo "Pins controlled: BCK, LRCLK, SDO0-SDO3"
        echo "Pins unchanged:  MCLK (input), SDI0 (input)"
        echo ""
        echo "Lower drive strength reduces MCLK jitter but weakens output signal."
        exit 1
        ;;
esac
