# Focus Isolation Probe — Mac tester instructions

This is the legacy VM alternative. The default native CEF browser now builds
from `Build.command`; its current instructions are in the root README and do
not require a Linux ISO. Use the commands below only to test the VM alternative.

This is the minimal runnable feasibility app, not a completed commercial
browser. It has not been compiled or run on macOS by its author. The first
tester should report build/start errors as well as focus results. It performs
no licensing or telemetry and must not be distributed as the licensed product.

## Build locally on an M4 Mac

Extract the source ZIP. In Terminal, change to that extracted folder and run:

```sh
bash macos/build.sh
open 'macos/build/Focus Isolation Probe.app'
```

If Apple command-line developer tools are missing, run `xcode-select --install`.
Finish Apple's installer, then run the command above again. It builds
`macos/build/Focus Isolation Probe.app`, signs it locally with an ad hoc
development signature and opens it. It is not notarized. No Apple developer
account, server secrets or browser passwords are needed for this build.

## First launch

Download an ARM64/aarch64 Linux installer ISO from its official publisher and
verify its published checksum. A distro with a GUI desktop is easiest. Click
**Choose Installer** and select that ISO. The app creates a private, sparse
24 GiB disk and runs a guest with 4 GiB RAM and four virtual CPUs. VM state and
host-event reports are in `~/Library/Application Support/Focus Isolation Probe`.
Choose the **guest virtual disk** in the Linux installer, not any host disk.

Install Linux and a supported, normally sandboxed Chromium package inside it.
Shut down the guest, quit the app, reopen it and choose **Start Guest** to boot
without installer media. To reattach installer media use **Attach Installer**.
The native menu provides these actions, instructions and report-folder access.
It never reports that isolation is verified. There is no host clipboard or
arbitrary host filesystem share. Browser navigation uses Chromium's guest UI.

## Run the diagnostic

The app attaches a read-only test ISO containing `index.html`, `serve.py` and
the report evaluator. Open this removable media in the guest's file manager,
copy it to a guest folder, and run in a guest terminal:

```sh
python3 serve.py
```

Open `http://127.0.0.1:8765` in guest Chromium. If the guest doesn't automount
the test media, inspect its block-device list and mount the read-only ISO
using the guest's supported tools. No host directory bridge is required.

Confirm focused=true and visible, start the five-second countdown, and put the
caret in the text field. Switch between this app and host Notes/Terminal with
real Cmd-Tab, 20 times; stay away at least three seconds per cycle. Leave
Chromium selected inside the guest. On final return type real text, stop and
export. Test real clicks, scrolling, form submission and navigation separately;
manually use https://clickclickclick.click/ and switch host apps there too.

Follow `docs/acceptance.md` for clock alignment, report evaluation, lifecycle
and crash tests. Send the diagnostic JSON, matching host JSONL and actual test
observations. No text values, passwords or keys are recorded by the observer.
Do not send the guest disk or normal browsing profile. A failed or missing
observation is not a pass. The report cannot prove absence of other inactivity
signals or compensate for failed focus/visibility behavior.

The app requests orderly guest shutdown when quitting. If Linux rejects it,
shut down from inside Linux. Closing a VM forcefully can damage its disk.
Swift compilation, guest boot, media mounting, input forwarding and focus
isolation all remain subject to the first real Mac test.
