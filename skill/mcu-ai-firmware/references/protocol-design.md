# Protocol Design

Design the wire format **before** the implementation, write it down, and test
the exact bytes. Most "device is broken" reports are protocol mismatches.

## Choose the right channel

- **Binary + fixed layout** for high-rate telemetry: small, cheap to parse,
  no allocation.
- **JSON/text** for commands, ACKs, configuration and diagnostics: readable,
  easy to extend, tolerant of optional fields.

Mixing both on one transport is fine if the receiver can split messages
unambiguously (see "framing" below).

## Framing

For a stream transport (UART/TCP/MQTT payload), the receiver must know where a
message starts and ends:

- Length-prefixed frames, or a distinct start byte + length + CRC.
- If a start byte can appear in the payload, define an escape rule or verify CRC
  before accepting.
- Never assume one transport read == one message. Handle concatenation and
  partial frames.
- If a modem/gateway adds prefixes (channel numbers, timestamps), document the
  exact prefix grammar and strip it by position, not by string search.

## Byte order and types

- Pick one endianness for the whole protocol (little-endian is common on ARM)
  and write it in the doc. Encode/decode byte-by-byte; never `memcpy` a struct
  onto the wire.
- Define signedness and widths explicitly (`u16`, `i32`, `float32`).
- Avoid `float` where reproducibility matters; if used, define rounding
  (e.g. three decimals) and test the exact IEEE-754 bit pattern on both ends.
- Timestamps: state the epoch and timezone unambiguously. A naive local time
  plus a platform-specific epoch constant is a classic off-by-8-hours bug —
  verify against a known message from an existing device.

## CRC and validation

- CRC-16/Modbus or CRC-32 over a defined range (document whether the CRC field
  itself is covered).
- Receiver drops invalid frames silently or counts them; never acts on them.
- Bound every length field before allocating or copying; reject `count` values
  that cannot fit in the payload.
- Reject non-finite floats, out-of-range timestamps and unknown channel IDs.

## Configuration records in flash

- Layout: `magic | version | payload | CRC` in a fixed-size record.
- **Bump the version whenever the layout changes**; invalidate older records and
  restore defaults on first boot. Otherwise a stale binary layout silently
  corrupts settings.
- Append records as a log across slots in a reserved page; on full, compact
  (erase + rewrite latest) at boot. Add runtime compaction if writes can fill
  the page without a reboot.
- Only program halfwords/words at runtime; full-page erase only when the
  watchdog is not running (or the erase is provably short).
- Persist only what must survive power loss; modes that are "session only"
  should stay in RAM and be documented as such.

## Commands and ACKs

- Every command carries an `id`; every ACK echoes it. ACKs are also sent on
  failure with `ok:0` and an error code (`range`, `busy`, `unsupported`).
- Validate before applying; reject partial/invalid updates atomically.
- Separate read-only polls from write commands: writes may extend keep-awake
  windows or trigger reconfiguration; reads must not.
- Document which commands persist and which are runtime-only.

## Topic/address design

- Give uplink, downlink and response distinct addresses if the transport echoes
  (MQTT self-echo, shared buses). Drop self-originated messages by shape
  (e.g. payloads without `cmd`, or carrying `ack`).
- Validate identifier tokens (no `/`, spaces, control chars); length-bound them.
- When identity changes at runtime, re-derive topics and re-subscribe before
  declaring success; keep the old link until the new one is proven.

## Pacing and reliability

- Modems often pace serial traffic (idle-time packing) and servers rate-limit.
  Keep a minimum gap between messages and a larger gap **between channels**
  (data vs ACK vs status) to avoid coalescing.
- Prefer "publish completed → dequeue" over fire-and-forget; retry the same
  payload on failure with a bounded backoff.
- Queue size is a design decision: drop oldest, drop by class, or keep only the
  latest sample. Document the choice; never let the queue grow unbounded.
- For high-rate sampling with slow uplink, decimate deliberately (e.g. one
  message per second) and state where the dropped points went.

## Protocol test checklist

- Golden byte vectors for every message type (fixed expected bytes).
- Boundary values: min/max/overflow, zero count, truncated payload.
- Concatenated messages, prefixed messages, noise before/after a frame.
- Round-trip: encode → decode → equal (within defined rounding).
- Cross-check against a real captured frame from the field when available.
