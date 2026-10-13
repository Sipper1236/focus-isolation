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
