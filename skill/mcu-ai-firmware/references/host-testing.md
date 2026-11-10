# Host Testing

The goal: **every line of logic that can run on a PC must be tested there.**
Hardware code should be small enough that HIL testing is practical.

## What goes on the host

- Parsers and formatters (JSON, binary frames, AT replies).
- State machines (network link, measurement scheduling, power).
- Data packing/scaling (fixed-point, floats, endianness, rounding).
- Storage records (flash config layout, CRC, slot logs, wear compaction).
- Pure algorithms (ring buffers, filters, CRC, time conversion).

## What does not

- Register access, HAL calls, interrupt handlers, DMA setup, electrical timing.
  Keep these in `mcu/` and verify them on hardware.

## Structure

```text
test/
├── test_ring_buffer.c
├── test_protocol.c
├── test_measure.c
└── stubs/           # fake BSP / fake modem / injectable clock
```

- Each test binary returns non-zero on failure and prints `PASS n / n`.
- Use a tiny assert macro with a line number; no framework required.
- Make all inputs explicit; no sleeping, no randomness, no wall-clock.

## Fakes and injection

Replace the BSP with test doubles that can be driven deterministically:

```c
/* fake hardware */
extern uint32_t g_now_ms;          /* advanced by the test */
extern int      g_adc_mv;
extern bool     g_encoder_ready;
extern char     g_frames[16][256]; /* captured uplink payloads */
```

- Provide tick injection (`fake_tick_advance(100)`) instead of `hw_delay_ms`.
- Provide a scripted modem: feed canned reply lines, assert the exact command
  sequence and timeouts.
- Capture outbound frames into a buffer; assert bytes, not "it didn't crash".

## Test design rules

- One behavior per test; name it after the behavior, not the function.
- Cover: happy path, bounds (0, 1, max, max+1), malformed input, timeouts,
  retries, offline/failed paths, persistence across reboot.
- Make time-based logic testable: pass `now` in, or inject the tick source.
- Assert side effects (bytes sent, records enqueued, pins set) as well as state.
- Every bug fixed gets a regression test that fails before the fix.

## Determinism checklist

- No dependence on host clock, locale or timezone (convert dates yourself).
- No uninitialized memory; memset structures in tests.
- No ordering assumptions between modules unless the code guarantees them.
- Test binaries build with `-Werror`; a warning is a test failure.

## Example: protocol packing test

```c
static void test_pack_displacement(void) {
    uint8_t buf[15];
    int n = pack_displacement(124000.0f, 678, buf);
    EXPECT_EQ(n, 15);
    EXPECT_EQ(buf[0], 0x20);       /* seconds low byte */
    EXPECT_BYTES(buf + 8, "\x01\x00\x00\x00\x01\x00", 6);
    EXPECT_FLOAT(buf + 12, 124000.0f);
}
```

Add a case for each field boundary and one for "must reject" inputs.
