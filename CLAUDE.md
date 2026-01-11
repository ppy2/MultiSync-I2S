# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PureFox MAX is a Buildroot-based embedded Linux distribution for Luckfox Pico MAX devices (RV1106 ARM SoC). It provides a multi-room audio streaming platform supporting TIDAL Connect, Qobuz Connect, Roon, Spotify, AirPlay, and USB Audio Class 2 output.

## Build Commands

### Full Build
```bash
./build.sh
```
This installs dependencies and runs the full Buildroot build. The build can take 1-2 hours on first run.

### Rebuild Single Package
```bash
cd buildroot
make <package>-rebuild
```
Example: `make librespot-rebuild`

### Clean Target for Rebuild
```bash
cd buildroot
rm -rf output/target
find output/ -name ".stamp_target_installed" -delete
rm -f output/build/host-gcc-final-*/.stamp_host_installed
```

### Configuration
```bash
cd buildroot
make BR2_EXTERNAL=../ext_tree luckfox_pico_max_defconfig
```
Then use `make menuconfig` to modify configuration.

## Architecture

### Buildroot Structure
- **`buildroot/`** - Upstream Buildroot framework (do not modify directly)
- **`ext_tree/`** - External tree with all customizations

### External Tree Layout

#### `ext_tree/package/`
Custom audio streaming packages. Each package follows Buildroot conventions:
- `<package>/<package>.mk` - Build configuration
- `<package>/Config.in` - menuconfig entry
- `<package>/src/` - Local source code (if SITE_METHOD=local)

Key packages:
- **librespot** - Spotify Connect (Rust/cargo)
- **tidal-connect** - Tidal Connect
- **qobuz-connect** - Qobuz Connect
- **roonready** - Roon Bridge
- **squeezelite** - Logitech Media Server
- **aplayer/aprenderer/apscream** - AirPlay implementations
- **naa** - Network Audio Adapter (USB UAC2)
- **status-monitor** - D-Bus daemon monitoring audio services

#### `ext_tree/board/luckox/`
Board-specific files:
- **`dts_max/`** - Device tree sources for RV1106
  - `rv1106_pll.dts` - PLL I2S audio mode (internal DAC)
  - `rv1106_ext.dts` - External DAC mode
  - `rv1106_512_*.dts` - 512MB RAM variants
  - `rv1106_*-ipc.dtsi` - IPC device tree includes
- **`rootfs_overlay/`** - Files overlayed onto target rootfs
  - `etc/` - System configs, init scripts
  - `opt/` - Runtime scripts for mode switching, updates
  - `usr/` - Custom binaries/libraries
  - `var/www/` - PHP web interface
- **`scripts/`** - Build hooks
  - `post-build.sh` - Post-build processing (DTB copying, stripping, SquashFS creation)
  - `linux-post-build.sh` - Kernel post-build
  - `post-image.sh` - Image creation

#### `ext_tree/configs/`
- **`luckfox_pico_max_defconfig`** - Buildroot defconfig for MAX

### Audio Mode Switching

The system supports dynamic audio mode switching through scripts in `/opt/`:
- **2pll.sh / 2_1024_pll.sh** - Switch to PLL mode (internal DAC, 1024fs MCLK)
- **2ext.sh / 2_1024_ext.sh** - Switch to external DAC mode
- **2_512_pll.sh / 2_512_ext.sh** - 512MB RAM variants
- **2_usb.sh** - USB audio output
- **2_lr.sh, 2_8ch.sh, 2_plr.sh** - Other I2S configurations

Mode switching involves:
1. Modifying `/etc/i2s.conf` (MODE, MCLK settings)
2. Writing new DTB to NAND flash at offset 0x3C0000
3. Modifying init script `/etc/init.d/S94ioi2s`

### Multi-Platform Support

The repo supports both MAX and Ultra devices via:
- **`master`** branch - PureFox MAX
- **`ultra`** branch - PureFox Ultra
- **`sync_master_to_ultra.sh`** - Syncs changes while preserving platform-specific files

Platform-specific differences:
- Device trees (`dts_max/` vs `dts_ultra/`)
- Boot configurations (MTD vs eMMC)
- Init scripts for storage
- U-boot configurations
- Post-build scripts

### Kernel and Device Tree

- Kernel builds in `buildroot/output/build/linux-main/`
- Device trees compiled as part of kernel build
- DTBs copied to `TARGET_DIR/data/boot/` for runtime switching
- Default DTB (pll) packaged into `boot.img` at offset 0x3C0000

### Cross-Compilation

Target: ARMv7-A Cortex-A7 with NEON-VFPv4 (hard-float)
- Target triplet: `arm-buildroot-linux-gnueabihf`
- Compiler flags: `-march=armv7-a -mfpu=neon-vfpv4 -mfloat-abi=hard`
- Cross-compiler: `buildroot/output/host/arm-buildroot-linux-gnueabihf/bin/`

### D-Bus Architecture

Services use D-Bus for IPC:
- Naming: `org.purefox.<component>`
- Example: `org.purefox.statusmonitor`
- Object path: `/org/purefox/<Component>`
- Interface: `org.purefox.<Component>`

### Build Optimization

Post-build optimizations in `post-build.sh`:
- Strip external toolchain libraries
- SquashFS for Tidal libraries (saves ~50MB rootfs space)
- UPX compression available but disabled (uncomment to enable)

## Development Notes

See `AGENTS.md` for detailed code style guidelines:
- Buildroot .mk files: UPPERCASE variables
- C code: snake_case, K&R braces, 4-space indent
- Shell scripts: POSIX sh, `set -euo pipefail`
- D-Bus: org.purefox naming convention

## Runtime Update System

The `/opt/update.sh` script provides over-the-air updates:
1. Self-updates via rsync from update server
2. Downloads new rootfs via rsync with exclusions
3. Flashes new bootloader/kernel to NAND partitions:
   - `/dev/mtd0` - Environment (256KB)
   - `/dev/mtd1` - IDBlock (256KB)
   - `/dev/mtd2` - U-Boot (512KB)
   - `/dev/mtd3` - Boot image (4MB, includes kernel+DTB)

## Important Files

- **`build.sh`** - Main build entry point
- **`sync_master_to_ultra.sh`** - Platform sync script
- **`ext_tree/external.mk`** - Includes all custom packages
- **`AGENTS.md`** - Detailed development guide
