---
name: mcu-ai-firmware
description: AI-driven workflow for bare-metal MCU firmware (STM32 / Cortex-M) with layered architecture, host unit tests, hardware-in-the-loop (SWD/OpenOCD) debugging, protocol-first documentation and release gates. Use when developing or debugging firmware, adding a driver or service, designing a wire protocol, bringing up new hardware, or setting up an AI-friendly firmware repository.
---

# MCU AI Firmware Workflow

A repeatable loop for developing embedded firmware with an AI agent. The point is
not "generate code fast" — it is **making AI-generated firmware verifiable**.

## When to use

- Starting a new bare-metal MCU project (STM32F1/F4/L4, Cortex-M0+/M3/M4).
- Adding a driver, service or protocol handler to an existing firmware.
- Debugging behavior that only appears on hardware (sleep, watchdog, timing,
  modem/4G, sensors).
- Setting up a repository so an AI agent can work in it safely.

## The loop (follow in order, every change)

1. **Recon** — read the project's `CLAUDE.md` / `AGENTS.md`, the protocol doc and
   the change log. Identify the *active* source tree; frozen/legacy trees are
   read-only. Run the baseline checks (`make doctor`, host tests, target build)
   before touching anything.
2. **Reproduce** — get a deterministic repro. For logic bugs, write a host test
   that fails. For hardware bugs, capture real evidence (SWD memory, bus frames,
   measured timing). Never fix a bug you cannot reproduce.
3. **Design** — decide which layer owns the change. Keep hardware access behind
   `bsp/`; pure logic must be host-testable. Write the wire format down before
   implementing it.
4. **Implement + host test** — add/extend a host test binary covering the new
   behavior, including edge cases and at least one regression test for the bug.
5. **Build target** — cross-compile with the project's flags; check size/layout
   budgets. Warnings are errors.
6. **HIL verify** — flash the real board, observe the actual behavior, and keep
   the evidence (frame counts, timing, SWD reads). Re-flash variants must be
   explicit about configuration retention.
7. **Document** — update the protocol doc, README and the dated change log in the
   same change. Record test counts and HIL evidence.
8. **Commit / release** — only when the gates pass. Never commit credentials or
   build outputs. Sanitize before publishing anything outside the project.

## Hard rules

- **One source of truth per fact.** If the protocol doc, README and code disagree,
  fix all of them in the same change.
- **Host tests are mandatory for logic.** Parsers, state machines, packing,
  scaling, scheduling: all must run on the PC with no hardware.
- **Hardware access only through the BSP.** `service/` must never include HAL or
  CMSIS headers; `mcu/` is the only place that touches registers/HAL.
- **No dynamic allocation** in `app/`, `service/`, `driver/`, `common/` unless the
  project explicitly allows it. Prefer static pools.
- **Verify with the real input path.** Synthetic events and direct function calls
  can pass while the real button, serial line or radio path fails. Test with
  real mouse/keyboard input, real bus traffic, real power cycles.
- **Evidence over inference.** "The device must be asleep" is not evidence; a SWD
  read of the backup registers or an RTC alarm target is.
- **Scope discipline.** Do what was asked, at the layer that was asked. Do not add
  unrequested UI text, features, refactors or "nice to have" hints.
- **Report faithfully.** State test counts, failures, skipped steps and HIL gaps
  plainly. Never claim verification that did not run.
- **Secrets never enter the repo.** Broker passwords, tokens, private keys and
  per-device credentials stay out of code, docs and commit messages. When a
  credential is already committed, flag it and plan rotation.

## Reference map (load only what you need)

| File | Use it for |
|------|------------|
| `references/layered-architecture.md` | Layer boundaries, dependency matrix, BSP pattern, init order, main-loop shape |
| `references/build-and-ci.md` | Host + target Makefiles, flags, layout/size budgets, CI gates |
| `references/host-testing.md` | Test structure, hardware fakes, tick injection, determinism |
| `references/hil-debugging.md` | OpenOCD/SWD recipes, static-state forensics, timing, common traps |
| `references/protocol-design.md` | Binary framing, endianness, CRC, versioned config records |
| `references/power-and-reliability.md` | Watchdogs, Standby, RTC alarms, low-voltage protection |
| `references/change-log-and-docs.md` | Change-log bullet format, doc structure, AI project rules |
| `references/windows-toolchain.md` | MSYS2, Python venv, PowerShell encoding, PID traps |
| `references/git-and-release.md` | Hosting choice, credentials, packaging, pre-publish sanitization |

## Quick checklist: adding a service module

1. `service/<name>/<name>.h` + `.c`; header includes no `stm32*`/`HAL_*`.
2. Talk to hardware only through `bsp/hw_platform.h` functions.
3. Add the include path and source to the target Makefile.
4. Add the source to the host Makefile if it is host-testable.
5. Call `<name>_init()` from `service/service_init.c` in dependency order.
6. Add a host test binary; cover happy path, bounds, bad input, retry/timeout.
7. Update the project rules doc, protocol doc (if it has a wire format) and the
   dated change log.

## Quick checklist: fixing a hardware bug

1. Reproduce on hardware; capture the failing state before changing code.
2. Read the relevant static variables over SWD (`.bss` addresses in the `.map`).
3. Decide whether the fault is logic (make a host test) or timing/electrical
   (change the hardware interaction, then measure).
4. Fix the smallest thing that explains the evidence.
5. Re-run host tests, re-flash, and prove the fix with the same measurement that
   showed the bug.
6. Add the regression test and document the root cause.

## Anti-patterns

- Blind retries, `while(1)` delays, and "wait a bit longer" as a fix.
- Inferring device state from a PC/UI indicator instead of the device itself.
- Testing only through the happy-path API while the real transport/driver path
  differs.
- Growing RAM/Flash silently; always check the size report.
- Updating code without updating the docs that other agents rely on.
- Publishing a skill, demo or repo that still contains customer names, internal
  hosts, credentials or proprietary protocol details.
