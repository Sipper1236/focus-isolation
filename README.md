# Focus Browser — native Chromium experiment

A native macOS browser prototype using Chromium Embedded Framework (CEF)
off-screen rendering. It opens a browser window with an address bar and
Back, Forward, Reload and Home controls. Webpages execute locally in Chromium.
The current default app does not require a Linux ISO or guest desktop.

**Focus isolation is unverified.** The experiment keeps engine focus independent
of host application activation. A real Mac must pass the focus/visibility tests
before this can become the commercial product. Licensing, Developer ID signing,
notarization and production security/reliability work are still pending.

[Native preview release and downloads](https://github.com/Sipper1236/focus-isolation/releases/tag/v0.3.0-native-preview).
The release includes source and a compiled development app. The compiled app
is ad hoc signed, so Gatekeeper may block a downloaded copy; building locally
with the steps below avoids relying on a release signing identity. Do not
disable system protections. Developer ID signing/notarization is not complete.

## Install and build on an Apple silicon Mac

1. Download this repository using **Code → Download ZIP** and extract it, or clone it:

   ```sh
   git clone https://github.com/Sipper1236/focus-isolation.git
   cd focus-isolation
   ```

   If you downloaded a ZIP, open Terminal in its extracted project folder.
   The old `v0.2.0-experimental` release contains the VM viewer; use the current
   repository for this native browser prototype.

2. Install Apple's command-line developer tools if needed:

   ```sh
   xcode-select --install
   ```

   Finish the installation before continuing. `Build.command` also requests
   these tools if they are missing.

3. Install CMake 3.21 or newer. If you already use Homebrew:

   ```sh
   brew install cmake
   ```

   Alternatively use the installer from [CMake's official download page](https://cmake.org/download/)
   and enable its command-line tools. `cmake --version` must work in Terminal.

4. Build and open the browser:

   ```sh
   bash Build.command
   ```

   The first build downloads the pinned ARM64 CEF runtime, about 132 MB
   compressed, verifies its SHA-256, builds the app and Chromium helpers, and
   signs them locally for development. It does not download an operating system.
   Build errors must be reported rather than treated as successful validation.

5. The result is `native-cef/build/bin/FocusBrowser.app`. Open it directly on
   subsequent runs, or move the complete `.app` bundle to Applications.
   Keep its embedded Frameworks folder intact. No CEF files need to be installed
   separately after the app is built.

The app is development-signed with an ad hoc identity. It is not Developer ID
signed or notarized. Normal release distribution remains future work.

## Browse

The app initially opens its own diagnostic page. Enter an HTTP/HTTPS address
in the address bar to browse. Click **Home** to return to the diagnostic. Cmd+L
focuses the address bar. Genuine input is forwarded through CEF's supported
keyboard, mouse and composition APIs; there is no background interaction loop
or JavaScript override of focus/visibility APIs.

The app uses a separate Chromium profile at:

```text
~/Library/Application Support/FocusBrowser/ChromiumProfile
```

Only one native session can own that profile at a time. Cookies and ordinary
browser storage persist there. **Show Host Reports** in the app menu opens
its parent folder. It records host activation timestamps, not browsing URLs,
keystrokes or page content. Chromium's own debug logging is disabled in this
prototype. Default Chromium sandboxing is requested and helper sandbox
initialization is included; actual process restrictions still require validation.

## Run the focus test

1. On the Home diagnostic, click the text field. Confirm `Focused: true` and
   `Visibility: visible`.
2. Click **Start Test B in 5 seconds**, then put the caret back in the text
   field before the countdown ends. Leave that page selected.
3. Switch to **another macOS application**, such as Notes, with Cmd+Tab.
   Remain there at least three seconds, return for at least one second,
   and repeat for at least **20 complete cycles**.
4. On the final return, type real text. Click **Stop measurement**, then
   **Export observations**. Save the JSON using the normal save dialog.
5. Use **Show Host Reports** to locate the matching `host-UUID.jsonl` from
   this app launch. Host and native-page timestamps use the same Mac clock.
6. Evaluate the supplied observations from the source project:

   ```sh
   python3 diagnostic/report.py /path/to/focus-RUN.json /path/to/host-RUN.jsonl
   ```

A pass requires focused/visible samples throughout all 20 cycles, no focus,
blur or visibility events during the measurement, sufficient sampling coverage,
and genuine text input after returning. Sampling gaps and incomplete runs fail
coverage. The evaluator's result only covers the supplied observations;
manual validation of actual app switching is also required.

Test real clicks, scrolling, text input, form submission, ordinary links and
navigation separately. Open https://clickclickclick.click/ manually and check
it with real host switches. Do not generate fake activity or inject scripts
into that site. A site may still infer inactivity from other signals.

## Current limitations

- ARM64 Mac compilation, development signature verification, launch, diagnostic
  loading and painting passed [the Mac CI check](https://github.com/Sipper1236/focus-isolation/actions/runs/38660492521).
  A separate [Mac focus study](docs/evidence/native-mac-38662037693/README.md)
  passed 20 confirmed Finder/browser switches: all 432 observations stayed
  focused/visible, with no focus/blur/visibility events. A real engine-focus-loss
  negative control detected blur. This is preliminary hosted-runner evidence;
  genuine input, full A–D, physical M4 compatibility and sandbox enforcement
  remain unverified.
- International input is a first-pass Cocoa/CEF composition implementation;
  surrounding-text reconversion is missing and needs IME testing.
- Popup links are redirected into the current browser; popup-dependent login
  flows may fail. Downloads and file dialogs are not yet fully integrated.
- Clipboard commands operate on genuine user actions using the normal Mac
  clipboard. There is no automatic clipboard capture or licensing transmission.
- CPU bitmap presentation is used initially. Retina, rendering, accessibility,
  shortcuts and latency require validation. No background throttling guarantees
  are established yet.
- Certificate errors are not bypassed. There is no remote rendering service,
  JavaScript API spoof, fabricated input or offline licensing mode.

The old VM experiment remains under `macos/` as architecture reference. Its
ISO setup instructions apply only to that alternative and are not the native
app installation path above.

## Engineering evidence

- [Native architecture and test plan](native-cef/README.md)
- [Architecture comparison](docs/feasibility.md)
- [Detailed acceptance cases](docs/acceptance.md) — original VM procedure; use
  the native procedure above for A–D and keep the same failure/lifecycle criteria.
- [Threat model and licensing design](docs/security.md)
- [Validation status](docs/validation.md)
- [Release gate](docs/release.md)

The report evaluator has 12 synthetic unit tests. Run them with
`python3 -m unittest discover -s tests -v`; they are not Mac acceptance evidence.
