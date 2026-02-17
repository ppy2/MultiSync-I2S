# AGENTS.md - Coding Agent Guidelines

This document provides guidelines for AI coding agents working in this repository.

## Project Overview

This is a **Buildroot-based embedded Linux project** targeting the **Luckfox Pico Max** board (ARM Cortex-A7, 32-bit). The project builds a multi-channel audio streaming system with support for various audio protocols (Spotify, Tidal, Qobuz, Roon, NAA, etc.).

### Directory Structure

```
/opt/multichannel/
├── buildroot/          # Buildroot core (version 2025.02-git)
│   ├── package/        # Buildroot packages
│   ├── configs/        # Defconfigs
│   └── output/         # Build artifacts
├── ext_tree/           # BR2_EXTERNAL tree with custom packages
│   ├── package/        # Custom packages (aplayer, librespot, etc.)
│   ├── board/          # Board-specific configs and scripts
│   ├── configs/        # luckfox_pico_max_defconfig
│   └── patches/        # Kernel/package patches
└── build.sh            # Main build script
```

## Build Commands

### Full Build
```bash
# From repository root
./build.sh
```

Or manually:
```bash
cd buildroot
make BR2_EXTERNAL=../ext_tree luckfox_pico_max_defconfig
make
```

### Incremental/Partial Builds
```bash
cd buildroot

# Rebuild a single package
make <package-name>-rebuild

# Rebuild from configure step
make <package-name>-reconfigure

# Clean a package build directory
make <package-name>-dirclean

# Download source only
make <package-name>-source

# Show dependencies
make <package-name>-show-depends
```

### Configuration
```bash
cd buildroot

# Menu-based configuration
make menuconfig

# Save current config as defconfig
make savedefconfig
```

### Clean
```bash
make clean          # Remove build artifacts
make distclean      # Remove everything including .config
```

### Linting/Checking

Buildroot includes a package checker:
```bash
cd buildroot
./utils/check-package ../ext_tree/package/foo/foo.mk
./utils/check-package ../ext_tree/package/foo/Config.in
```

For Python files:
```bash
flake8 <file.py> --max-line-length=132
```

For shell scripts (shellcheck):
```bash
shellcheck <script.sh>
```

## Code Style Guidelines

### Makefile (.mk files)

Use **tabs** for indentation in `.mk` files:

```makefile
################################################################################
#
# package-name
#
################################################################################

PACKAGE_NAME_VERSION = 1.0
PACKAGE_NAME_SITE = $(TOPDIR)/../ext_tree/package/package-name
PACKAGE_NAME_SITE_METHOD = local
PACKAGE_NAME_LICENSE = GPL-2.0+

define PACKAGE_NAME_BUILD_CMDS
	$(MAKE) CC="$(TARGET_CC)" -C $(@D)
endef

define PACKAGE_NAME_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/binary $(TARGET_DIR)/usr/bin/binary
endef

$(eval $(generic-package))
```

**Key conventions:**
- Header block: 80 `#` characters, package name, closing `#` block
- Variables: `UPPERCASE_NAME_VERSION`, `UPPERCASE_NAME_SITE`, etc.
- Use `$(TARGET_CC)`, `$(TARGET_DIR)`, `$(INSTALL)` - never hardcode paths
- End with `$(eval $(generic-package))` or appropriate package type

### Config.in Files

Use **tabs** for indentation:

```kconfig
config BR2_PACKAGE_MY_PACKAGE
	bool "my-package"
	depends on BR2_TOOLCHAIN_HAS_THREADS
	select BR2_PACKAGE_ALSA_LIB
	help
	  Description of the package.

	  https://example.com/package
```

### C Code

Based on `.clang-format` and existing code:

```c
/* Use tabs for indentation, 8-char tab width */
int main(int argc, char *argv[])
{
	int ret = 0;
	char *name = NULL;

	if (argc < 2) {
		fprintf(stderr, "Usage: %s <arg>\n", argv[0]);
		return 1;
	}

	/* Opening brace on same line for functions in K&R style */
	for (int i = 0; i < argc; i++) {
		printf("arg[%d] = %s\n", i, argv[i]);
	}

	return ret;
}
```

**Conventions:**
- Indent width: 8 (tabs)
- Max line length: 132 characters
- Braces: `if () {` on same line, function definitions can have opening brace on new line
- Pointer alignment: `char *ptr` (right-aligned `*`)
- Use `-Wall -O2` compiler flags for simple packages

### Shell Scripts

Use **spaces** for indentation (4 spaces):

```bash
#!/bin/sh

set -e

main_var="/path/to/something"

if [ -f "$main_var" ]; then
    echo "File exists"
fi

for item in $list; do
    echo "$item"
done
```

### EditorConfig Settings

From `.editorconfig`:
- Default: spaces, 4-space indent, UTF-8, LF line endings
- `*.mk`, `Makefile*`, `Config*.in*`: tabs
- Trim trailing whitespace (except patches)
- Insert final newline

## Naming Conventions

### Packages
- Directory: `package-name` (lowercase, hyphens)
- Makefile: `package-name.mk` (same as directory)
- Config variable: `BR2_PACKAGE_PACKAGE_NAME` (uppercase, underscores)

### C Files
- Use `snake_case` for functions and variables
- Use `UPPER_CASE` for macros and constants
- Binary names: `program_name` (underscores)

### Init Scripts
- Named `S##service-name` where `##` is two-digit order number
- Example: `S01statusmonitor`, `S99custom`

## Error Handling

### C Code
```c
/* Check return values and use perror for system calls */
int fd = open("/dev/device", O_RDWR);
if (fd < 0) {
    perror("open");
    return -1;
}

/* Use meaningful return codes */
return 0;  /* success */
return 1;  /* usage error */
return -1; /* system error */
```

### Shell Scripts
```bash
#!/bin/sh
set -e    # Exit on error
set -u    # Error on undefined variables
set -x    # Debug trace (optional)
```

## Adding a New Package

1. Create directory: `ext_tree/package/my-package/`
2. Create `my-package.mk` with package definition
3. Create `Config.in` with Kconfig options
4. Add source tarball or use local/site method
5. Add to `ext_tree/Config.in`:
   ```
   source "../ext_tree/package/my-package/Config.in"
   ```
6. Enable in defconfig or via `make menuconfig`

## Target Architecture

- **Architecture**: ARM (32-bit, little-endian)
- **CPU**: Cortex-A7 with NEON/VFPv4
- **Toolchain**: arm-buildroot-linux-gnueabihf
- **ABI**: aapcs-linux (hard float)

When compiling manually, use:
```makefile
$(TARGET_CC) $(TARGET_CFLAGS) -march=armv7-a -mfpu=neon-vfpv4 -mfloat-abi=hard
```

## Testing

This is an embedded system project. Testing is done by:
1. Building the full system image
2. Flashing to target hardware
3. Manual functional testing

For Buildroot package testing:
```bash
cd buildroot
./utils/test-pkg <package-name>
```

## Common Pitfalls

1. **Never hardcode host paths** - use `$(TARGET_DIR)`, `$(HOST_DIR)`, etc.
2. **Never hardcode host compiler** - use `$(TARGET_CC)`, `$(TARGET_CC)`
3. **Use tabs in .mk files** - spaces will break Make
4. **Strip binaries** - use `-s` linker flag or let Buildroot strip
5. **Check dependencies** - add to `*_DEPENDENCIES =` variable
