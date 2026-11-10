# Layered Architecture

A firmware layout that keeps business logic testable on a PC and pushes all
hardware knowledge into one thin layer.

```text
app/        entry point + main loop orchestration
service/    business logic (protocols, scheduling, measurement, state machines)
driver/     external device drivers (sensors, modems, encoders) — via bsp
bsp/        hardware abstraction interfaces (.h only, zero dependencies)
common/     zero-dependency algorithms (ring buffer, CRC, math)
config/     pure macro/constant config
mcu/        MCU + HAL implementation (the only layer allowed to touch HAL)
```

## Dependency matrix

| Layer | May depend on | Must not depend on |
|-------|---------------|--------------------|
| `common/` | nothing | everything else |
| `config/` | nothing | everything else |
| `bsp/` | nothing (headers only) | HAL, other layers |
| `mcu/` | HAL, CMSIS, `bsp/` | `service/`, `app/`, `driver/` |
| `driver/` | `bsp/`, `common/` | HAL directly |
| `service/` | `bsp/`, `common/`, `config/`, `driver/`, peer services | HAL, CMSIS, `stm32*` headers |
| `app/` | all of the above (mcu only in `main.c`) | — |

Enforce this with a script (`templates/check_architecture.sh`), not with
discipline. Grep for forbidden includes and `HAL_` calls in `service/`; fail CI.

## The BSP pattern

`bsp/hw_platform.h` declares pure function interfaces:

- GPIO by *logical pin* (`hw_pin_t` enum), not by port/bit.
- RTC/BKP, UART (blocking and async), RS485 direction control, USB CDC,
  watchdog, tick/delay, standby entry, reserved flash page.
- Battery/ADC, system reset, reset-cause capture.

`mcu/hw_platform_impl.c` is the **single .c file** that implements them with HAL.
A `pin_map[]` table maps the logical enum to port/pin/active level, so adding a
GPIO peripheral means: add enum value → add table entry → call `hw_gpio_*`.

Consequences:

- Services can be compiled and unit-tested on a PC against a fake BSP.
- Pin changes never touch business logic.
- The HAL never leaks into testable code.

## Initialization order

Put all init in one place (`service/service_init.c`) and order by dependency:

```text
protocol → time → schedule → settings → uplink → encoder/measure
         → network → command (last: registers handlers that use everything)
```

Rules that bite in practice:

- Anything that may erase flash (config compaction) must run **before** the
  watchdog starts.
- Read "wake from standby" flags once, store them, then let the consumer clear
  them — avoid two modules consuming the same one-shot flag.
- Register callbacks (sample → uplink, wait hooks) immediately after the module
  that produces them is initialized.
- Start the network/peripheral power-up **before** enabling the watchdog.

## Main loop shape

Keep the loop non-blocking where possible:

```text
while (1):
    command_process()      # host/debug channel
    schedule_run()         # power state machine
    measure_tick()         # acquisition cadence
    if work produced:
        report/uplink
    if link online:
        urc_pump()         # async events
        downlink_handle()
        uplink_poll()
        network_poll()     # state machine advances one step per pass
    if sleep requested:
        enter_standby()    # does not return
```

Prefer **one state-machine step per pass** over blocking waits. When a driver
must block (modem AT commands), provide a *wait hook* so time-critical sampling
continues, and never call sleep/network functions from that hook.

## Async I/O checklist

For UART/DMA peripherals:

- Give every long operation a start/poll/busy/abort API instead of a blocking
  loop.
- Handle IDLE + transfer-complete + error interrupts; record lengths in ISRs.
- Raise/lower RS485 DE in the TX-complete path, not in application code.
- Abort DMA and disable NVIC before standby/DeInit.
- Keep a byte-gap timeout based on a cycle counter for high-baud links.

## New module checklist

1. Create `service/<name>/<name>.h` and `.c`; the header must not include
   `stm32*` or `HAL_*`.
2. Call hardware only through `bsp/hw_platform.h`.
3. Add include path + source to the target build.
4. Add the source to the host build if it is testable (keep hardware out).
5. Initialize it in dependency order; document why the position matters.
6. Add host tests; then HIL verify.
7. Update the project rules doc and the change log.
