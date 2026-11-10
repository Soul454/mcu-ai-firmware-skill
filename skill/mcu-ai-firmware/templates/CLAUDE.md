# CLAUDE.md

Guidance for AI agents working in this repository. Replace every `<...>`
placeholder before using.

## Repository Layout

```text
firmware/        <active target tree>  (e.g. STM32L4 bring-up / production)
<legacy>/        frozen baseline — read-only, do not modify
tools/           host-side scripts, tests, dashboards
docs/            protocol, hardware and product documents
hardware/        PCB / schematic sources (not built by Make)
```

**Active target: `<path>`** — all firmware changes go here. The `<legacy>`
tree is frozen: never edit it for convenience, never duplicate fixes into it
unless explicitly asked.

## Build Commands

```bash
make doctor    # toolchain + required source presence
make test      # host unit tests
make fw        # target firmware (ELF + BIN + size)
make ci        # doctor + architecture + host tests + firmware + layout/size
make clean
```

Outputs go to `build/host/` and `build/stm32/`. Run inside the documented shell
(e.g. MSYS2 UCRT64 on Windows). Extra macros go through `DEFS`, e.g.
`make fw DEFS=-D<FLAG>=1`.

## Architecture: Layered Firmware

```text
app/       entry + main-loop orchestration
service/   business logic; never calls HAL directly
bsp/       pure hardware abstraction interfaces (.h only)
driver/    external device drivers (via bsp)
common/    zero-dependency algorithms
config/    macro constants only
mcu/       MCU/HAL implementation — the only layer allowed to call HAL
```

| Layer | May depend on | Must not depend on |
|-------|---------------|--------------------|
| `common/` | nothing | all other layers |
| `config/` | nothing | all other layers |
| `bsp/` | nothing | HAL, other layers |
| `mcu/` | HAL, CMSIS, bsp | service, app, driver |
| `driver/` | bsp, common | HAL directly |
| `service/` | bsp, common, config, driver, peers | HAL, `stm32*`/CMSIS headers |
| `app/` | service, bsp, driver, common, mcu (main.c only) | — |

Hardware access pattern: all peripherals behind functions declared in
`bsp/hw_platform.h` and implemented in exactly one `mcu/*.c` file. Pin identity
is a logical enum in `bsp/board_config.h`; physical mapping lives in the
implementation's pin table.

## Critical Invariants

- `<List pin ownership rules: e.g. PA12 is USB D+, never GPIO>`
- `<List init-order constraints, e.g. settings/config compaction before watchdog>`
- `<List persistence rules: which settings live in backup RAM / flash page>`
- `<State which tree is authoritative for protocol semantics>`

## Service Initialization Order

`service/service_init.c` calls modules in dependency order:
`<protocol → time → schedule → settings → ... → command (last)>`.
Document why each non-obvious position matters.

## Main Loop

```text
while (1):
    <one line per step, in order>
```

Keep it non-blocking; long driver operations use start/poll state machines.
Document any hooks that run during blocking waits and what they must not call.

## Protocol

- Wire format and commands: `docs/<protocol>.md`.
- Data channel vs control channel, pacing, ACK semantics and persistence rules
  are defined there; update the doc in the same change as the code.
- Golden byte tests live in `<test file>`.

## Build Checks

`make ci` runs: doctor, architecture check, host tests, full target build
(`-Werror -Wvla`), layout check (vector table, `.data` load address, section
alignment) and size check (Flash/RAM budgets, heap symbols).

## Working Rules

- Read the protocol doc and the latest change-log entries before changing code.
- Every behavior change: host test + build + HIL evidence + dated change-log
  bullet (files, why, test counts, measurements).
- No new UI text, features or refactors unless requested.
- No dynamic allocation outside `mcu/` unless documented.
- Never commit build outputs, credentials or generated hardware exports.
- Do not modify `<legacy>` or unrelated projects on this machine.

## Current Baseline Status

<Short dated summary of what is implemented, what is stubbed, and known gaps.>
