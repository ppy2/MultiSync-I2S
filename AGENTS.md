# PureFox MAX - Agent Development Guide

## Build Commands

# Rebuild specific package
cd buildroot
make <package-name>-rebuild

# Clean output
cd buildroot
rm -rf output/target ; find output/ -name ".stamp_target_installed" -delete ; rm -f output/build/host-gcc-final-*/.stamp_host_installed
```

## Project Structure

This is a Buildroot-based embedded Linux project for Luckfox Pico MAX devices.

- `buildroot/` - Buildroot framework (upstream)
- `ext_tree/` - External Buildroot tree with custom packages and board configs
  - `package/` - Custom packages (aplayer, librespot, status-monitor, etc.)
  - `board/luckfox/` - Board-specific configs, overlays, and scripts
  - `configs/` - Board defconfig files
  - `external.mk` - Includes all custom package .mk files

## Code Style Guidelines

### Buildroot Package Makefiles (.mk files)

Naming conventions:
- Package name: UPPERCASE with underscores (e.g., `LIBRESPOT`, `STATUS_MONITOR`)
- Variables: `PACKAGENAME_<VARIABLE>` (e.g., `LIBRESPOT_VERSION`, `LIBRESPOT_DEPENDENCIES`)

Required variables:
```makefile
PACKAGE_VERSION = <version>
PACKAGE_SITE = <url or "local">
PACKAGE_SITE_METHOD = <git, local, or default>
PACKAGE_LICENSE = <license>
PACKAGE_DEPENDENCIES = <space-separated list>
```

Common macros:
- `$(eval $(generic-package))` - Generic package (autotools/cmake)
- `$(eval $(cargo-package))` - Rust/Cargo packages
- `$(eval $(host-generic-package))` - Host packages

Build/install commands:
```makefile
define PACKAGE_BUILD_CMDS
    cd $(@D) && $(MAKE) ...
endef

define PACKAGE_INSTALL_TARGET_CMDS
    $(INSTALL) -D -m 0755 $(@D)/binary $(TARGET_DIR)/usr/bin/
endef
```

Use `$(TARGET_CC)`, `$(TARGET_CFLAGS)`, `$(TARGET_LDFLAGS)` for cross-compilation.

### C Source Code

Imports:
- System headers first, then local headers
- Group related includes together
- Example:
```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <alsa/asoundlib.h>
#include <dbus/dbus.h>
```

Formatting:
- 4-space indentation (no tabs)
- K&R brace style: opening brace on same line
- Line length: ~100 characters max
- Use `//` for single-line comments

Naming conventions:
- Functions: snake_case (e.g., `get_volume_status_alsa`)
- Variables: snake_case (e.g., `current_status`, `running`)
- Types: snake_case with `_t` suffix (e.g., `system_status_t`)
- Macros: UPPERCASE with underscores (e.g., `STATUS_FILE`, `MAX_BUFFER`)
- Constants: UPPERCASE (e.g., `DBUS_SERVICE_NAME`)

Error handling:
- Check return values of all system calls
- Use `errno` and `strerror()` for error messages
- Return negative values or NULL on failure
- Print errors to stderr with `fprintf(stderr, ...)`

Type usage:
- Use standard types (int, char, bool)
- Use `bool` from `<stdbool.h>` for boolean values
- Use `size_t` for sizes/lengths
- Use explicit types for structure members (e.g., `time_t`)

Memory management:
- Always free allocated memory
- Check allocations with `if (!ptr)`
- Use `strncpy()` with explicit null-terminator for string copying

### Shell Scripts

Shebang:
```bash
#!/bin/sh      # POSIX shell
#!/bin/bash     # Bash with features
```

Error handling:
```bash
set -e          # Exit on error
set -u          # Error on undefined variables
set -o pipefail # Fail on pipe errors
```

Variables:
- Use UPPERCASE for constants/exports (e.g., `TARGET_DIR`, `SCRIPT_DIR`)
- Use lowercase for local variables (e.g., `old_md5`, `file`)

Conditionals:
```bash
if [ "$VAR" = "value" ]; then
    # ...
elif [ "$VAR2" = "value2" ]; then
    # ...
else
    # ...
fi
```

Use `$(...)` for command substitution (not backticks).

### Config.in Files

Format:
```
config BR2_PACKAGE_<PACKAGE_NAME>
    bool "<package-name>"
    depends on <dependencies>
    select BR2_PACKAGE_<DEP>
    help
      Multi-line description.
      Explain what the package does.
```

Keep descriptions concise but informative.

## Device Tree and Kernel

Device tree source files (.dts) in `ext_tree/board/luckfox/dts_max/`:
- Named like `rv1106_<mode>.dts` (e.g., `rv1106_pll.dtb`, `rv1106_ext.dtb`)
- Compiled as part of kernel build
- Copied to `TARGET_DIR/data/boot/` in post-build.sh

Kernel builds in `output/build/linux-main`.

## Board Overlay Structure

`ext_tree/board/luckfox/rootfs_overlay/` structure:
- `etc/` - System configs (init.d, asound.conf, i2s.conf)
- `opt/` - User scripts (I2S mode switching, update, export)
- `usr/` - Binaries, libraries
- `var/www/` - Web interface files

## Architecture Specifics

Target: ARMv7-A with NEON-VFPv4 (ARM hard-float)
- Target triplet: `arm-buildroot-linux-gnueabihf`
- Use `-march=armv7-a -mfpu=neon-vfpv4 -mfloat-abi=hard` flags

Cross-compiler tools in `buildroot/output/host/arm-buildroot-linux-gnueabihf/bin/`.

## Common Patterns

Package installation:
```makefile
$(INSTALL) -D -m 0755 $(@D)/binary $(TARGET_DIR)/usr/bin/
$(INSTALL) -D -m 0644 $(@D)/config $(TARGET_DIR)/etc/
```

C compilation flags:
```makefile
-Wall -O2 -s -march=armv7-a -mfpu=neon-vfpv4 -mfloat-abi=hard
```

D-Bus naming:
- Service: `org.purefox.<component>` (e.g., `org.purefox.statusmonitor`)
- Object path: `/org/purefox/<component>`
- Interface: `org.purefox.<Component>` (e.g., `org.purefox.StatusMonitor`)

## No Unit Tests

This is an embedded Linux distribution project. Packages are tested on hardware or via QEMU. No automated unit testing framework is configured.
