# Validation status — 2026-10-09

Executed on Linux in `/home/rayyan/Projects/focus-isolation`:

- `python3 -m unittest discover -s tests -v`: **12 passed**. These are synthetic
  report-evaluator unit tests, not browser or macOS acceptance runs.
- `node --check` on extracted diagnostic inline JavaScript: passed.
- `bash -n macos/build.sh`: passed.
- XML parsing of development virtualization entitlements: passed.
- Loopback HTTP smoke check: served diagnostic with HTTP 200 and `no-store`.
  Needed local-socket sandbox permission; no external network or page input.

Not executed:

- Swift compilation/macOS SDK validation, guest installation, VM startup.
- Browser sandbox verification and real input/display forwarding.
- Acceptance A–F, including 20 macOS host switches and ClickClickClick.
- Performance, commercial licensing or security integration.
- Developer ID signing, hardened runtime, notarization or release tests.

No acceptance evidence exists yet. The hardware-dependent feasibility gate
remains open. Deliverables are a working local diagnostic, tested evaluator,
experimental VM-viewer source and investigation/runbook documents, not a
verified working macOS browser or commercially distributable application.

2026-10-13 update: the Mac build now creates a `.app` bundle with an installer
picker, managed sparse guest disk, native start/report/instructions menu,
development signing and bundled read-only diagnostic ISO. `bash -n` passed
for both build scripts and the app/entitlements property lists parsed. Swift
compilation, hdiutil media creation and macOS runtime/acceptance remain NOT RUN.
An M4 Mac is available through the user's friend for the next validation.

2026-10-14 native CEF update:

- Default `Build.command` now builds native CEF OSR, with no Linux guest setup.
- ARM64 compilation, all five helper roles, framework packaging and development
  signature verification passed on GitHub's macOS 26 ARM64 runner.
- The smoke check launched the app, loaded its bundled diagnostic, observed a
  paint callback and closed cleanly. It generated no user input or host switches.
- [Successful run 38660492521](https://github.com/Sipper1236/focus-isolation/actions/runs/38660492521)
  built native commit `718a6c3cfcd45da171d0f62f45619dfc7f8b06f3`.
- The first native attempt failed on CEF screen-rectangle and CoreGraphics
  bitmap enum types. Both compile errors were corrected; subsequent runs passed.
- The diagnostic evaluator's 12 synthetic unit tests still pass.

Still NOT RUN: physical M4 genuine input, A–D, 20 host switches, ClickClickClick,
E/F, performance and actual sandbox/file access inspection. VM-specific Swift
runtime verification also remains unperformed. There is no validated claim of
focus isolation, commercial licensing, Developer ID signing or notarization.
