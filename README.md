# I2S Audio Cluster

**Bit-synchronized multichannel I2S audio cluster for active speaker systems**

A scalable multichannel audio platform built on [Luckfox Pico MAX](https://wiki.luckfox.com/Luckfox-Pico/Luckfox-Pico-Max-Mini) (Rockchip RV1106) single-board computers. Multiple nodes share I2S clocks via physical wiring, guaranteeing **bit-perfect synchronization** across all channels — critical for multi-way active crossover systems.

## Key Features

- **Bit-synchronized output** — all nodes share BCK/LRCLK/MCLK via hardwire, ensuring zero sample drift between channels
- **Scalable** — up to 16 slave nodes (128 channels), limited only by HQPlayer's channel count
- **8 channels per node** — 4x stereo I2S data lines (SDO0–SDO3)
- **PCM up to 32bit/192kHz** guaranteed (8ch per node)
- **PCM up to 32bit/384kHz** in 4ch mode (per node, not fully tested)
- **DSD up to DSD256** native playback with automatic PCM/DSD switching
- **Dual clock domain** — 44.1kHz and 48kHz families with automatic GPIO-based oscillator switching
- **Bit-perfect** — no resampling, no mixing, direct DMA-to-I2S path
- **Network Audio** — [HQPlayer NAA](https://www.signalyst.com/naa.html) protocol over Ethernet

## Why This Matters for Active Speakers

In a multi-way active speaker system, each frequency band (tweeter, midrange, woofer, subwoofer) is driven by a separate DAC channel. Any timing offset between channels causes:

- Phase errors at crossover frequencies
- Comb filtering artifacts
- Degraded stereo imaging

This cluster guarantees **zero inter-channel timing error** because all nodes share the same physical I2S clock signals. The DACs on every node see identical BCK/LRCLK edges simultaneously.

## Architecture

```
┌──────────────────────────────────────────────────┐
│  HQPlayer (PC/Mac)                               │
│  Multichannel output: 2/4/6/8ch per NAA endpoint │
└────────┬───────────────────────┬─────────────────┘
         │ TCP/IP                │ TCP/IP
         ▼                       ▼
┌──────────────────┐     ┌──────────────────┐
│  Node 0 (MASTER) │     │  Node 1 (SLAVE)  │    ...up to 16 nodes
│  Luckfox Pico    │     │  Luckfox Pico    │
│  MAX             │     │  MAX             │
│                  │     │                  │
│  NAA ─► ALSA     │     │  NAA ─► ALSA     │
│         │        │     │         │        │
│     I2S DMA      │     │     I2S DMA      │
│   ┌──────────┐   │     │   ┌──────────┐   │
│   │SDO0..SDO3│   │     │   │SDO0..SDO3│   │
│   │BCK LRCLK │───┼─────┼──►│BCK LRCLK │   │
│   │MCLK      │───┼─────┼──►│MCLK      │   │
│   └──────────┘   │     │   └──────────┘   │
└──────────────────┘     └──────────────────┘
        │                        │
   8ch to DAC(s)            8ch to DAC(s)
```

## Hardware Wiring

### I2S Signal Pinout (Luckfox Pico MAX)

| Signal | GPIO | Pin | Direction (Master) | Direction (Slave) |
|--------|------|-----|--------------------|-------------------|
| BCK (Bit Clock) | GPIO2_A0 | 36 | Output | **Input** |
| LRCLK (Frame Clock) | GPIO2_A1 | 35 | Output | **Input** |
| MCLK (Master Clock) | GPIO2_A2 | 34 | Output | **Input** |
| SDO0 (Data ch0-1) | GPIO2_A4 | 32 | Output | Output |
| SDO1 (Data ch2-3) | GPIO2_A7 | 29 | Output | Output |
| SDO2 (Data ch4-5) | GPIO2_A6 | 30 | Output | Output |
| SDO3 (Data ch6-7) | GPIO2_A3 | 33 | Output | Output |

### Control Signal Pinout

| Signal | GPIO | Function |
|--------|------|----------|
| MUTE | GPIO1_D3 | Mute output (active high) |
| MUTE_INV | GPIO3_C6 | Inverted mute for LED indicator |
| DSD_ON | GPIO1_D0 | DSD mode enable |
| MCLK_SEL | GPIO1_D1 | Clock domain select (44.1/48kHz) |
| FREQ_INV | GPIO1_C5 | Inverted clock domain indicator |

### Inter-Node Wiring

Connect **master → all slaves** with short wires (< 15cm recommended):

```
Master                    Slave(s)
──────                    ────────
BCK   (GPIO2_A0) ──────► BCK   (GPIO2_A0)
LRCLK (GPIO2_A1) ──────► LRCLK (GPIO2_A1)
MCLK  (GPIO2_A2) ──────► MCLK  (GPIO2_A2)
GND   ───────────────────GND
```

**Important:**
- All three clock lines (BCK, LRCLK, MCLK) must be connected
- Common GND is mandatory
- Keep wires short and equal length to minimize skew
- Data lines (SDO0–SDO3) go to each node's own DAC — they are NOT shared between nodes
- MCLK_SEL and DSD_ON may optionally be shared if all nodes use the same DAC configuration

### External Clock Source (EXT mode)

In EXT mode, the master node receives MCLK from an external oscillator or DAC clock output. Two oscillators are used:

| Oscillator | Frequency (512fs) | Frequency (1024fs) | Clock Domain |
|------------|-------------------|---------------------|--------------|
| OSC_49M | 24.576 MHz | 49.152 MHz | 48kHz family |
| OSC_45M | 22.5792 MHz | 45.1584 MHz | 44.1kHz family |

GPIO1_D1 (MCLK_SEL) selects between them via a `gpio-mux-clock`. The driver switches automatically based on the sample rate.

## Software Setup

### Prerequisites

- [HQPlayer Desktop or Embedded](https://www.signalyst.com/consumer.html) (multichannel license)
- Ethernet network connecting all nodes and HQPlayer host
- Luckfox Pico MAX boards flashed with this firmware

### Building

```bash
build.sh
```

The firmware image is produced in `buildroot/output/images/`.

### Node Configuration

Each node must be configured as either **master** or **slave** using the configuration script:

```bash
/opt/configure.sh <clock_source> <mclk_multiplier> <role>
```

#### Parameters

| Parameter | Values | Description |
|-----------|--------|-------------|
| clock_source | `ext` / `pll` | `ext` = external oscillator, `pll` = internal PLL |
| mclk_multiplier | `512` / `1024` | MCLK-to-sample-rate ratio |
| role | `master` / `slave` | Clock master or slave |

#### Examples

**2-node stereo bi-amping (external 512fs clock):**
```bash
# Node 0 — master (tweeters + midrange)
/opt/configure.sh ext 512 master

# Node 1 — slave (woofers + subwoofers)
/opt/configure.sh ext 512 slave
```

**4-node system with 1024fs clock:**
```bash
# Node 0 — master
/opt/configure.sh ext 1024 master

# Nodes 1, 2, 3 — slaves
/opt/configure.sh ext 1024 slave
```

**Single node with internal PLL (no external clock needed):**
```bash
/opt/configure.sh pll 1024 master
```

The script:
1. Writes clock mode and MCLK multiplier to `/etc/i2s.conf`
2. Sets the hostname (`master` or `slave`)
3. Links the appropriate networkaudiod startup script
4. Configures Chrony time synchronization (master serves NTP, slave syncs from master)
5. Flashes the correct Device Tree Blob to NAND
6. Reboots the node

### HQPlayer Configuration

Each node appears as a separate NAA endpoint on the network. Configure HQPlayer's multichannel output:

1. **Backend:** NAA
2. **Device:** Select each node's NAA endpoint
3. **Channel layout:** Combo
4. **Channels per endpoint:** 2, 4, 6, or 8 (depending on your speaker configuration)
5. **Buffer time:** 100 ms
6. **Clock mode:** Time

| HQPlayer Setting | Value | Notes |
|-----------------|-------|-------|
| Backend | NAA | Network Audio Adapter |
| Mode | Combo | Combines multiple endpoints |
| Channels | 2 / 4 / 6 / 8 | Per endpoint |
| Buffer | 100 ms | Recommended for stability |
| Clock | Time | Network time-based clocking |

**Combo mode** maps consecutive channel pairs across NAA endpoints. For example, with 3 nodes at 8ch each:

| Channels | Node 0 | Node 1 | Node 2 |
|----------|--------|--------|--------|
| 1–8 | SDO0–SDO3 | — | — |
| 9–16 | — | SDO0–SDO3 | — |
| 17–24 | — | — | SDO0–SDO3 |

### Verified Configurations

| Mode | Channels/Node | Sample Rate | Status |
|------|--------------|-------------|--------|
| PCM 8ch | 8 | up to 192 kHz | **Tested, stable** |
| PCM 4ch | 4 | up to 384 kHz | Not fully tested |
| DSD 4ch | 4 | DSD64–DSD256 | Not tested (driver supports it) |

### Runtime sysfs Controls

All controls are accessible at `/sys/devices/platform/ffae0000.i2s/`:

| Attribute | Access | Description |
|-----------|--------|-------------|
| `mute` | R/W | Hardware mute (0/1) |
| `mclk_multiplier` | R/W | 512 or 1024 |
| `pcm_channel_swap` | R/W | Swap L/R channels in PCM mode |
| `dsd_physical_swap` | R/W | Swap DSD data pins |
| `dsd_sample_swap` | R/W | DSD sample swap (noise fix) |
| `freq_domain_invert` | R/W | Invert frequency domain GPIO |
| `pinctrl_state` | R/W | Switch pins: `default` / `idle` |
| `tx_reset` | W | Trigger I2S TX reset |
| `postmute_delay_ms` | R/W | Mute hold time after start (ms) |
| `frame_counter` | R | Monotonic frame counter |
| `drift_ppb` | R/W | Clock drift correction (ppb) |
| `pointer_offset` | R/W | DMA pointer offset (frames) |

### Time Synchronization

Nodes use [chrony](https://chrony-project.org/) for precise time synchronization:

- **Master** syncs to internet NTP servers with very slow, jitter-free slewing (`maxslewrate 10 ppm`, polling every 4–68 minutes)
- **Slave** tracks master over local network with tight polling (every 4–32 seconds)
- Before each playback session, the slave forces a precise time step (`chronyc makestep`) to snap to master's clock
- During playback, only smooth frequency adjustments — no time jumps

## Project Structure

```
ext_tree/
├── board/luckfox/
│   ├── dts_max/                    # Device Tree sources
│   │   ├── rv1106.dtsi             # Base SoC definition
│   │   ├── rv1106-pinctrl.dtsi     # Pin multiplexing
│   │   ├── rockchip-pinconf.dtsi   # Pin electrical config
│   │   ├── rv1106_512_ext-ipc.dtsi # 512fs master config
│   │   ├── rv1106_512_ext_full-ipc.dtsi  # 512fs slave config
│   │   ├── rv1106_ext-ipc.dtsi     # 1024fs master config
│   │   ├── rv1106_ext_full-ipc.dtsi# 1024fs slave config
│   │   ├── rv1106_pll-ipc.dtsi     # PLL mode config
│   │   └── *.dts                   # Top-level device trees
│   ├── rootfs_overlay/
│   │   └── etc/
│   │       ├── init.d/             # Boot scripts
│   │       ├── networkaudiod/      # NAA start/stop hooks
│   │       ├── chrony.conf.master  # NTP server config
│   │       └── chrony.conf.slave   # NTP client config
│   └── scripts/
│       └── post-build.sh           # DTB packaging
├── configs/
│   └── luckfox_pico_max_defconfig  # Buildroot config
├── package/
│   └── sync-node/                  # Frame sync daemon
└── patches/
    └── linux_rv1106.patch          # Kernel driver modifications
```

## How It Works

1. **HQPlayer** sends multichannel audio over TCP/IP to NAA daemons on each node
2. **networkaudiod** (NAA) receives audio and writes to the ALSA device via `snd_pcm_writei()`
3. **ALSA/DMA** transfers audio data to the I2S peripheral's TX FIFO
4. **I2S hardware** serializes the data to SDO0–SDO3, clocked by shared BCK/LRCLK
5. Since all nodes share the same physical clock signals, their data outputs are **bit-synchronized**

The I2S driver automatically handles:
- Muting during format changes (PCM ↔ DSD)
- Clock domain switching (44.1kHz ↔ 48kHz)
- DSD mode GPIO signaling
- Master start delay for slave synchronization
- Pin isolation in idle state

## License

This project is licensed under the **GNU General Public License v2.0** — see the [LICENSE](LICENSE) file for details.

The kernel driver modifications are derived from the Rockchip I2S/TDM driver and are distributed under GPL-2.0 as required by the Linux kernel licensing terms.
