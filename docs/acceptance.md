# Repeatable Mac procedure

Every test below is **NOT RUN**. Do not check it off from unit tests, source
inspection, VM appearance or a Linux observation. Record failures as well as
passes. Local reports are user-controlled evidence, not tamper-proof attestation.

## M4 Mac quick start

The M4 MacBook is the right physical Apple silicon host for this prototype.
Get its exact macOS version from **Apple menu → About This Mac** and retain it
with the test results. Apple's Virtualization framework supports GUI Linux
guests presented in a `VZVirtualMachineView`; Apple says the guest ISO must be
ARM64/aarch64 on Apple silicon.
[Apple GUI Linux VM instructions](https://developer.apple.com/documentation/virtualization/running-gui-linux-in-a-virtual-machine-on-a-mac)

Extract the source kit on the Mac. In Terminal, enter the project root and run:

```sh
bash Build.command
```

The script requests Apple developer tools if absent; finish installing them
and rerun it. The resulting app has an installer picker, managed guest disk,
and read-only observer media. See `macos/MAC-TEST.md` for that GUI path.
For an explicit CLI configuration instead, obtain an ARM64 Linux installer
and create a fresh dedicated directory and blank guest disk:

```sh
mkdir -m 700 "$HOME/FocusProbe"
mkfile -n 24g "$HOME/FocusProbe/linux.raw"
chmod 600 "$HOME/FocusProbe/linux.raw"
macos/build/VMProbe "$HOME/FocusProbe" "$HOME/FocusProbe/linux.raw" /absolute/path/to/linux-arm64.iso
```

Install Linux in the VM window. At first reboot, quit the viewer and reopen it
without the ISO argument. Install a desktop environment and distro-supported
Chromium inside Linux. Follow “Prepare the guest once” below, then run the
diagnostic there. A VM configuration/compile failure is a useful report too:
capture exact macOS version and the redacted error. Do not send Apple IDs,
passwords, downloaded recovery tokens, or the guest disk. The viewer uses a
development ad hoc signature only. It does not install a polished browser app.

## Prepare the guest once

Use macOS 13+ on a physical Apple Silicon Mac with current Xcode command-line
tools. Record machine, RAM, macOS build, SDK/compiler, source revision, guest
image URL/checksum, guest kernel/compositor and exact Chromium version.
Verify downloaded image signatures/checksums against the OS publisher. Use an
ARM64 Linux installer that supports EFI, virtio block/network and virtio GPU;
the prototype does not supply or verify an installer. A Debian ARM64 guest
with Xorg/Openbox is a candidate, not a tested guest image.

```sh
bash macos/build.sh
mkdir -m 700 "$HOME/FocusProbe"
mkfile -n 24g "$HOME/FocusProbe/disk.raw"
chmod 600 "$HOME/FocusProbe/disk.raw"
macos/build/VMProbe "$HOME/FocusProbe" "$HOME/FocusProbe/disk.raw" /absolute/path/to/arm64-installer.iso
```

Install Linux using the displayed guest installer. Shut down cleanly. Relaunch
without the ISO argument. Inside the guest, install a graphical desktop and
the distro-supported Chromium package. Run Chromium as an unprivileged user
with its supported sandbox enabled; verify the installed package's sandbox
status rather than adding `--no-sandbox`. Disable guest screen blanking,
screen locking, compositor idle suspension and desktop focus-follow-mouse for
the controlled experiment. Record the exact settings; do not confuse an
unconfigured guest idle timeout with host-induced focus changes.

Transfer this project's **diagnostic directory only** into the guest using
an explicit download or manually prepared installer media. There is no host
directory sharing. Run `python3 diagnostic/serve.py` inside the guest, then:

```sh
chromium --user-data-dir="$HOME/.local/share/focus-probe-profile" http://127.0.0.1:8765
```

Keep this dedicated profile and guest disk private. Use only one instance and
the same state directory: the prototype's lock prevents two processes owning
that directory, not globally independent VMs or one disk passed with different
state paths. The commercial single-session constraint is not implemented yet.
The host viewer has no native browser address bar: use Chromium's guest chrome.

Do not attach DevTools/remote debugging during measurement, alter page focus
APIs, hide observer events, or use keyboard/mouse automation. Leave Chromium
the selected window and diagnostic the active tab within the guest desktop.
No guest auto-focus loop is supplied.

## A — baseline

Click the genuine text field. Confirm the page reports `Focused: true` and
`Visibility: visible`. Take a local screenshot of this diagnostic only. Start
the five-second countdown, then put the caret in the field again. Initial
`start` row must show both states. A false baseline is a failed test, not a
reason to edit the APIs.

## B — twenty host cycles

1. Synchronize host/guest wall clocks before the test and record measured
   guest-minus-host offset/uncertainty. They are independent clocks. Do not
   infer alignment from matching-looking formatted times. For example display
   `python3 -c 'import time; print(time.time_ns() // 1000000)'` on both systems
   before entering the browser; record timing uncertainty. If it exceeds
   250 ms, use a better clock measurement or mark correlation inconclusive.
2. Start measurement and restore the real caret during the countdown.
3. Press host Cmd-Tab to Notes/Terminal and remain there at least three seconds.
   Return with host Cmd-Tab; remain for at least one second. Do this 20 times.
   Do not switch guest windows/tabs. The viewer deliberately leaves
   `capturesSystemKeys` false; verify Cmd-Tab actually switches host apps.
4. On final return type real text. Stop measurement, then export the JSON.
   No typed text is in the export. Do not export while measuring.
5. Copy the exported JSON from guest to host using a deliberate manual channel
   (for example a temporary authenticated transfer); do not expose the profile
   or enable unrestricted filesystem sharing just to copy a report. Retain the
   host JSONL path printed by the probe for this run.

```sh
python3 diagnostic/report.py /path/to/focus-RUN.json /path/to/host-RUN.jsonl --offset-ms 0
```

Replace `0` with the measured guest-minus-host offset. Passing output is
`TEST_B_OBSERVATIONS_PASS`, scoped to this interval only. Samples must stay
focused/visible, have no focus/blur/visibility events, cover all 20 away
intervals without gaps over 1500 ms, and record trusted text input after final
return. Inspect traces manually and attest that these were genuine host
switches. A sample cannot prove continuous state between samples; event traces
complement sampling. Unobserved suspension is explicitly rejected.

## C — real browsing

In a separate run type in text fields, click the target, scroll with real
trackpad/mouse, submit the form, follow the navigation link, and use browser
back/forward/reload/address entry. Check text and caret behavior after return,
including selection and composition with the user's input method. Perform an
authorized ordinary login and verify profile persistence after clean restart.
Test both same-origin and cross-origin navigation. Do not accept observer
click counters as proof that every normal browser function works.

## D — ClickClickClick

Open https://clickclickclick.click/ manually, operate it normally, and perform
real host switches. Record compatibility behavior and any site report of
leaving/returning. Do not inject the observer into this site or create fake
interaction. The diagnostic's Test B independently measures browser APIs;
ClickClickClick is a manual third-party compatibility check, not exhaustive
proof of site internals. If it reports focus loss despite a diagnostic pass,
investigate rather than dismiss it. Its own lack-of-activity requirements are
outside the promise. Tests A–D need signed-off manual evidence before any full
product implementation.

## E — background lifecycle

Run the diagnostic away for five minutes. Inspect sampling gaps and host
sleep/VM events. Compare visible/away real-world page behavior, CPU/RSS and
display response on return. Do not turn on synthetic animation or fake inputs
to keep the browser awake. Browser timer behavior and guest scheduling are
separate measurements. Do not infer CPU efficiency from missing samples.

## F — failures (separate runs)

| Trigger | Evidence to collect | Required engineering decision |
|---|---|---|
| Kill browser/renderer | Profile reopening, error state, missing observations | Never show verified status after restart without revalidation |
| Guest kernel/VM failure | Host `vm-failed`/`vm-stopped`, disk recovery | Stop display, invalidate privacy status; preserve disk for recovery |
| Kill host/relaunch | Lock release, guest filesystem recovery | Never count an incomplete run as a pass |
| Sleep/wake | Host sleep/wake rows and sampling gaps | Suspended intervals cannot claim continuous lifecycle |
| Network loss | Local observer vs normal browsing error | Local guest remains separate; product license expiry must stop use |
| Authorization denial/unavailable | **Deferred: product service not implemented** | Fail closed for launch/new session; enforce finite active lease |

The observer stores samples in page memory: browser crash loses unexported
page observations. Mark such evidence incomplete; a subsequent milestone needs
bounded crash-safe local recording. Host JSONL flushes after every row but does
not make page logging crash-safe. Prototype error messages and shutdown paths
also need actual SDK/runtime validation. If the guest rejects ACPI shutdown,
the probe cancels quit; shut down inside the guest. Force termination may
damage guest/profile data. No claim of commercial crash recovery is made.

## Record template

For each run save: hardware/versions, source revision, setup, clock alignment,
observer and host files, A–F statuses (`PASS`, `FAIL`, `NOT RUN`, `INCONCLUSIVE`),
manual steps/attestation, failure explanation, measured CPU/memory/latency and
decision. Keep these in private local storage; do not upload browsing data.
Never edit failed measurements into passing results.
