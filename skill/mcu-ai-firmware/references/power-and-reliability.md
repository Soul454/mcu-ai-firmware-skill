# Power and Reliability

Battery devices fail in the field for three reasons: they don't wake, they don't
sleep, or they reset at the wrong time. Treat power state as a first-class,
observable feature.

## Watchdogs

Choose deliberately:

- **IWDG** — independent, simple, keeps running in Standby unless the option
  byte stops it. Good default for a production device.
- **WWDG** — windowed, needs a clock that allows a sane window; at high PCLK1 the
  window can shrink below a useful period. If the window is too short, don't
  force it; use IWDG.

IWDG startup traps (STM32):

1. Enable LSI and wait for `LSIRDY` first; after reset it is off.
2. Write prescaler/reload, then `KR = 0xCCCC`, then wait for PVU/RVU to clear
   (bounded), then `KR = 0xAAAA`. PR/RLR only propagate after the enable.
3. Freeze the IWDG while the core is halted (`DBGMCU_APB1FZR1_DBG_IWDG_STOP`) so
   SWD sessions don't reset the board.
4. Stop the IWDG in Standby via the option byte (`FLASH_OPTR.IWDG_STDBY`) or the
   device will wake every watchdog period. This is a chip-level setting: mass
   erase does not reset it, but a new chip needs it reprogrammed.

Feed points must cover every blocking path: main loop tail, delay implementations
(in chunks), long bus transfers, and every modem/DMA wait handler. Do not feed
inside the wait loop of a stuck operation without a timeout.

## Standby / sleep

- Wake from Standby is a **full reset**. Persist everything needed across wake
  (wake flag, next wake target, cached link parameters) in backup registers or
  the config page.
- Use RTC Alarm A (or the wakeup timer) for the next work slot; clear stale
  alarm/exti/wakeup flags at init.
- Before sleeping: stop timers, DeInit UARTs/DMA, abort in-flight transfers,
  set peripheral pins to a safe low-power state, power down radios, then enter
  Standby. If Standby returns unexpectedly, reset — never continue.
- Keep the interval semantics explicit: is the interval from the last sample, the
  end of the previous cycle, or the start? Write it in the docs and test it.
- Schedules must handle "wake late, target already passed": skip or pick the next
  reachable slot; don't busy-loop waiting for a past RTC time.

## Low voltage

- Read battery voltage with the MCU's calibrated reference if available, and
  require several consecutive low readings before acting (radio TX causes dips).
- Ignore "unknown" readings (ADC failure / 0) instead of treating them as 0 V.
- Low-voltage sleep should override normal scheduling and be documented (fixed
  sleep duration, periodic re-check, resume when recovered).
- If the RTC has no backup clock (no LSE, LSI not battery-backed), Standby cannot
  wake on schedule: disable the sleep path rather than sleeping forever.

## Reset and boot diagnostics

- Capture `RCC->CSR` **early** in `main()` before HAL clears it; expose the reset
  cause (power-on, pin, software, independent watchdog, window watchdog).
- Keep a boot counter in backup RAM to detect reboot loops.
- A standby wake may show no RCC reset flag at all; use a backup-register magic
  as the discriminator.
- Log the first N seconds after boot in a way you can retrieve later (serial,
  queue, status command).

## Radio/modem power

- Know whether the module is powered by a load switch or stays powered. If it
  shares the MCU's switch, every MCU reset also power-cycles the modem, adding
  boot + reconnect time to every cycle.
- Power-down commands may need a settle delay; if the module doesn't answer,
  decide explicitly whether to cut power or leave it (pressing PWRKEY at shutdown
  can power the module on instead).
- Distinguish "module is booting" from "module is off" by probing, not by
  fixed delays. Probe with short waits and fall back to a hardware reset only
  after a bounded number of attempts.

## Reliability checklist

1. All blocking waits have timeouts and watchdog coverage.
2. Every failure path leaves a defined state (retry, error report, sleep, reset).
3. Power transitions are observable (backup registers, reset cause, counters).
4. Long-run test covers at least one full sleep/wake cycle and one link loss.
5. Device recovers without a manual power cycle after: link drop, watchdog reset,
   low battery, encoder/sensor unplugged.
