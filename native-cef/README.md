# Native CEF feasibility experiment

This replaces the VM viewer as the default prototype following the user's
request for a browser experience without visible guest setup. CEF/Chromium is a
native local macOS runtime. The minimal AppKit UI exists to test real browsing
and engine focus semantics, not to claim a finished product.

The pinned dependency is in `cef.lock.json`. Its SHA-256 was computed from the
official CEF distribution archive, after checking the build index's SHA-1.
CEF source correspondence: commit `14c5a08` and Chromium 154.0.8037.98.
Keep dependency updates deliberate and rerun focus/visibility tests after them.

## Mechanism to test

- Set `windowless_rendering_enabled`; present BGRA frames through AppKit.
- Give CEF engine focus when real input targets the browser surface.
- Record host resign/become-active notifications without forwarding them as
  `SetFocus(false)` or `WasHidden(true)`.
- Allow actual user choices of native browser chrome (address bar) to change
  in-app page focus normally. These choices are outside a host-switch-only run.
- Never override page getters/listeners, inject third-party scripts or produce
  autonomous input. The diagnostic observes only its own document.

This is a plausible supported CEF strategy. It does not establish that every
CEF lifecycle/native-window path preserves page focus or visibility. Cross-site
frames, navigation, popups, minimization/occlusion, App Nap, sleep and crashes
must be measured. Test A–D on the physical M4 remain mandatory before full
product work. UI status always says unverified.

## Sandbox and packaging

`helper.cc` initializes `CefScopedSandboxContext` before loading CEF. The
framework contains the M138+ `libcef_sandbox.dylib`. CMake generates all five
helper roles from the pinned SDK's `CEF_HELPER_APP_SUFFIXES` and uses its
framework-copy macro. The app is dynamically loaded, not directly linked
against the Chromium framework. Development signing proceeds inside out.
No `--no-sandbox` flag or security-disabling fallback is included. Runtime
sandbox validation remains required; configuring it is not proof of enforcement.

The dedicated native profile is separate from everyday browsers. It is not a
VM boundary. Browser-process compromise may reach host user privileges; the
threat model must be reassessed for this architecture before commercial release.
File URL navigation is limited to the bundled diagnostic directory. File
uploads/clipboard are ordinary explicit browser/user operations, not automatic
host filesystem sharing. Test those boundaries before accepting them.

## Verification

`--smoke` only loads the bundled diagnostic, waits for a paint callback and
closes the browser. It writes `native-build-smoke.json` in the app data folder.
It performs no clicks, typing or host-switch simulation, and is not acceptance
evidence for focus, ordinary input or security. GitHub CI runs that limited
check after compilation; genuine input and 20 host cycles are manual.

Sources:

- [CEF OSR engine](https://github.com/chromiumembedded/cef/blob/14c5a08/libcef/browser/osr/render_widget_host_view_osr.cc)
- [CEF macOS entry point](https://github.com/chromiumembedded/cef/blob/14c5a08/tests/cefsimple/cefsimple_mac.mm)
- [Helper sandbox initialization](https://github.com/chromiumembedded/cef/blob/14c5a08/tests/cefsimple/process_helper_mac.cc)
- [CEF packaging template](https://github.com/chromiumembedded/cef/blob/14c5a08/tests/cefsimple/CMakeLists.txt.in)
- [CEF sandbox requirements](https://github.com/chromiumembedded/cef/blob/14c5a08/docs/sandbox_setup.md)
- [CEF native OSR input sample](https://github.com/chromiumembedded/cef/blob/14c5a08/tests/cefclient/browser/browser_window_osr_mac.mm)
