# Architecture decision record — investigation, 2026-10-09

Status: **candidate only; acceptance blocked on real macOS/Apple Silicon**.
The available workstation is Linux, with neither Swift/macOS SDK nor Apple
Silicon hardware. No A–F results, hardware measurements, signing or notarization
are available. Missing hardware is an environment blocker, not evidence that
the product is impossible. Full product development remains gated.

## A: Native Chromium

Chromium's windowed macOS view has a native activation-to-engine-focus path.
`OnWindowIsKeyChanged` passes key-window state to `SetActive`; deactivation
calls `LostFocus`. `WasOccluded` also leads to `WasHidden`. These independent
paths make ordinary embedding an unsuitable default assumption.
[Chromium macOS view source](https://raw.githubusercontent.com/chromium/chromium/main/content/browser/renderer_host/render_widget_host_view_mac.mm)

Blink computes document focus from its page focus controller, which also
dispatches focus/blur events. Document visibility changes have their own event
delivery. A JavaScript getter substitution does not fix engine state or event
delivery. A controlled Chromium fork would need a narrowly defined product
focus domain across activation, first-responder, occlusion, WebContents
visibility, navigation, render-widget recreation, popups, cross-process frames,
and lifecycle scheduling. Preserving ordinary in-page element focus remains
necessary; suppressing all focus events would break the browser.
[Document implementation](https://raw.githubusercontent.com/chromium/chromium/main/third_party/blink/renderer/core/dom/document.cc),
[Focus controller](https://raw.githubusercontent.com/chromium/chromium/main/third_party/blink/renderer/core/page/focus_controller.cc)

CEF off-screen rendering (OSR) is a stronger native candidate than stock
windowed embedding. The embedder supplies display and genuine input and controls
focus and hidden state through supported browser APIs. The OSR implementation
has distinct focus handling. Keeping CEF focus set while the host app loses
foreground is a testable engine-level hypothesis, not an API spoof.
[CEF API](https://raw.githubusercontent.com/chromiumembedded/cef/master/include/cef_browser.h),
[OSR source](https://raw.githubusercontent.com/chromiumembedded/cef/master/libcef/browser/osr/render_widget_host_view_osr.cc)

OSR requires a native presenter, IME composition, popup surfaces, accessibility,
keyboard mapping, file dialogs and browser controls. App Nap, renderer
visibility/lifecycle, background scheduler behavior, navigation and crash
recovery need separate validation. Do not use `--no-sandbox` to simplify the
experiment. Helpers need current CEF sandbox initialization and packaging.
[CEF sandbox setup](https://github.com/chromiumembedded/cef/blob/master/docs/sandbox_setup.md)
An upstream CEF build must be pinned and security-update ownership established
before distribution. Native OSR resource/latency advantages remain unmeasured.

## B: Local virtual machine

An ARM64 Linux guest gives the browser its own desktop focus domain and a
stronger host-filesystem boundary. Apple's framework supports guest devices
and local VM execution. `VZVirtualMachineView` presents guest display and
forwards keyboard/mouse input. This is a native host window displaying a guest
Linux Chromium process, **not native macOS Chromium**.
[Apple Virtualization](https://developer.apple.com/documentation/virtualization),
[VM view](https://developer.apple.com/documentation/virtualization/vzvirtualmachineview)

The working hypothesis is that AppKit deactivation need not deactivate the
guest Chromium window. Apple's public API description is not a guarantee of
this property. The included experiment retains the VM and one fixed display,
and deliberately does not pause or detach it on host deactivation. The viewer
may still perform input cleanup or expose focus changes; acceptance must catch
that. A process activity assertion requests active scheduling, but is not a
proof against throttling or sleep.

Initial prototype allocation: 4 virtual CPUs, 4 GiB guest RAM, one 1280×800
display, NAT, raw disk, EFI boot, keyboard and absolute pointing device. Those
are configuration choices, not measured consumption. No host shares, clipboard
bridge, camera/microphone, downloads bridge or remotely rendered browser.
Browser storage lives on the guest disk. Browsing uses guest networking and
ordinary sandboxed Chromium; packaging must verify the guest's Chromium
sandbox and patch cadence separately.

Guest overhead, GPU acceleration and display latency are unknown. Clipboard,
host file pickers, downloads export, Command-key mapping, IME, accessibility,
audio, WebAuthn/security keys and DRM are unresolved integrations. Snapshot
storage, guest patching and redistribution licenses also need engineering.
NAT is not an outbound security boundary; local network access still needs a
product policy. Stopping/suspending a VM can change lifecycle and cannot be
advertised as continuous isolation.

## Darling and a macOS VM

Darling reimplements Darwin/macOS interfaces on Linux. Its README describes
GUI support as in development and says Xcode itself does not run. It supplies
no basis for accepting Apple's Virtualization behavior, AppKit focus handling,
or Apple Silicon performance. We do not install or use it to certify this
product. A macOS VM can potentially help compile, but nested virtualization,
architecture and real host window switching remain separate constraints.
[Darling README](https://github.com/darlinghq/darling)

## Conditional decision

| Candidate | Expected boundary | Engineering cost | Evidence now |
|---|---|---|---|
| Windowed native Chromium/CEF | Renderer sandbox, host focus coupled | Engine/platform changes | Source shows focus-loss path |
| CEF OSR | Renderer sandbox; host-controlled engine state | Presenter/input/IME and packaging | Credible source-based hypothesis; no test |
| Local Linux VM | Guest OS plus browser sandbox | Guest image, integration, RAM/startup | Minimal viewer source; compile/test pending |

Prototype the VM first for its explicit desktop boundary; compare against OSR
if it fails or if its cost warrants the second experiment. No final architecture
selection has been made. Before a selection, A–D must pass on a physical
Apple Silicon Mac. Compare maintenance cost, browser compatibility, sandbox
verification, guest footprint and measured responsiveness. If neither passes,
publish the failure traces and stop product integration. Script injection,
synthetic activity and remote browser rendering are not fallbacks.

Reference machine for later measurement: base M1 MacBook Air, 8 GiB RAM,
current supported macOS, AC power, logged version and display configuration.
Provisional targets: p95 input-to-display <100 ms, warm session start <10 s,
application startup <2 s excluding networking. These are goals, not results.
Measure cold/warm start (30 runs), CPU/RSS while idle and scrolling, at least
100 real input-to-display trials with a high-frame-rate external recording,
and guest/browser recovery; report median/p95 and test setup. An 8 GiB host
may have significant pressure with the initial 4 GiB guest allocation.

## Next gate

Complete Mac compile and genuine acceptance observations. No production UI,
license service, owner tool or release package is implemented at this milestone.
The security/release documents specify subsequent work without claiming it is
complete. This preserves the user's requirement to validate the central claim
before investing in the full product.
