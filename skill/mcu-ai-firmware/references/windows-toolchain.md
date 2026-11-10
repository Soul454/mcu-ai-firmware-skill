# Windows Toolchain Notes

Practical issues that repeatedly waste time on Windows + MSYS2 + Chinese paths.

## Environment

- Use **MSYS2 UCRT64** for `make`, host `gcc`, `arm-none-eabi-gcc`, `openocd`,
  `cppcheck`, `gdb`. Run build commands inside that shell (or via VS Code tasks
  that invoke it).
- Project paths with Chinese characters work, but some tools print mojibake in
  the console; don't treat that as a failure. Set `PYTHONIOENCODING=utf-8` for
  Python output when needed.
- Prefer forward slashes in Makefiles and scripts (`/c/...` in MSYS paths).

## Python

- Use a project venv (`.venv/Scripts/python.exe` on Windows; in MSYS bash it may
  be `.venv/bin/python.exe`). `python` on PATH may be the Microsoft Store stub —
  if you see "Python was not found", use the venv path explicitly.
- Don't write tokens or passwords into scripts; use env vars/credential helpers.

## PowerShell 5.1 encoding

- `.ps1` files saved as UTF-8 **without BOM** are read as the system ANSI code
  page (GBK on Chinese Windows), so Chinese paths/literals break with "file not
  found" or parse errors.
- Workarounds: save with BOM, keep the script ASCII-only, or pass paths as
  arguments from bash.
- `"$var: text"` is parsed as a drive reference; use `"${var}: text"`.

## Process IDs

- In MSYS bash, `$!` is the MSYS PID, not the Windows PID. Use `ps -W` (or
  `tasklist`) to find the real WINPID before calling PowerShell/`taskkill`.
- Don't kill processes you didn't start; ask the user when unsure.

## Console encoding

- Printing symbols like `✕` or emoji can raise `UnicodeEncodeError` under GBK.
  Avoid printing non-ASCII glyphs in automated scripts; compare text instead.

## Long-lived UI / WebView apps

- A running app locks its install directory on Windows; replace builds only
  after the app is closed.
- Embedded WebView2 user-data directories cannot be shared by two instances;
  give each instance its own `--user-data-dir` when testing.
- Verify UI behavior with **real input** (cursor moves + mouse events), because
  synthetic event injection can hide OS-level cancellation behavior.

## Flashing

- `make flash` that mass-erases also wipes configuration pages; provide a
  `flash-keep-cfg` variant that only reprograms the image.
- Option bytes (watchdog standby, readout protection) survive mass erase:
  document the one-time programming step and verify it on a fresh chip.
