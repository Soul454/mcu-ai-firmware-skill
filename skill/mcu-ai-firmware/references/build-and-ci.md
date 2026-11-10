# Build and CI

Two builds from one source tree:

- **Host build** (`gcc`, PC): unit tests for all portable code.
- **Target build** (`arm-none-eabi-gcc`): the real firmware image.

## Target build essentials

```make
CC      = arm-none-eabi-gcc
OBJCOPY = arm-none-eabi-objcopy
SIZE    = arm-none-eabi-size

MCU     ?= -mcpu=cortex-m4 -mthumb -mfpu=fpv4-sp-d16 -mfloat-abi=hard
CFLAGS  = $(MCU) -std=c11 -Wall -Wextra -Werror -Wvla -Og -g3 \
          -ffunction-sections -fdata-sections $(OPT) $(DEFS) $(INC)
LDFLAGS = $(MCU) -T$(LDSCRIPT) -Wl,--gc-sections -Wl,-Map=$(TARGET).map

all: $(TARGET).elf $(TARGET).bin
```

Rules that prevent silent breakage:

- `-Werror -Wvla`; warnings are defects, not noise.
- Keep a **flags stamp** file (`build/.cflags`). Rebuild everything when
  `OPT`/`DEFS` change, otherwise you silently link objects built with old flags.
- Ship `doctor` checks for tool presence and required source files.
- Link with a map file; keep the startup vector table and `.data` load address
  under a layout check (a wrong `.isr_vector` length or a circular `_sidata` can
  produce an image that flashes but never runs).

## Size / layout gates

- Define hard Flash and RAM budgets in a script; fail when exceeded.
- Track the linked heap symbols as well as static RAM.
- Reserve the last flash page(s) for configuration records and set the linker
  `FLASH LENGTH` below that boundary so the image can never overlap it. All size
  checks must use the same limit.
- Report size after every build; a sudden jump is a review trigger.

## Host build essentials

```make
HOSTCC ?= gcc
CFLAGS = -std=c11 -Wall -Wextra -Werror -Ibsp -Icommon -Iservice/... -Itest
```

- Host tests link the *real* service/driver sources plus a fake BSP.
- Keep host-only stubs in `test/` so production files stay hardware-agnostic.
- One binary per area (`test_settings`, `test_protocol`, `test_measure`, ...) or a
  single runner; either way each test prints a count and fails the build.

## CI gates

Order from cheap to expensive:

```text
1. doctor        — toolchain + required sources exist
2. architecture  — include boundaries, bsp header-only, no malloc outside mcu
3. host tests    — all binaries
4. target build  — -Werror, full link
5. layout        — vector table size, .data load address, section alignment
6. size          — Flash/RAM budgets, heap symbols
```

A single `make ci` should run all of them. If a gate is skipped, say so.

## Build hygiene

- Build outputs in `build/`, never committed.
- Keep toolchain paths out of source; use `?=` overrides.
- Reproducible from a clean tree: `make clean && make ci`.
- Preserve the user's existing toolchain setup; do not silently switch compilers
  or install SDKs without saying so.
