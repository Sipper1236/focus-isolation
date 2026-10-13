# Focus isolation — feasibility laboratory

**Milestone 1 is incomplete. No macOS isolation result has been demonstrated.**
This is a development-only experiment, not the commercial application, and it
has no product authorization or licensing bypass path: there is no licensed
product yet. Do not distribute this probe to customers or interpret its title as
a privacy guarantee. Milestones 2–6 are gated on genuine acceptance evidence.

[Download the experimental Mac source kit](https://github.com/Sipper1236/focus-isolation/releases/tag/v0.2.0-experimental).
Extract it on an Apple silicon Mac and run `bash Build.command` from the
extracted `focus-isolation` folder. The build creates and opens the `.app`;
first guest setup requires an ARM64 Linux installer ISO. This release contains
source, not a precompiled or notarized macOS application.

Contents:

- `macos/VMProbe.swift`: minimal AppKit/Virtualization local Linux guest viewer,
  real input via Apple's viewer, host activation JSONL observation, separate
  guest disk, no shares or clipboard bridge. **Not compiled or run on this Linux
  workspace.** macOS 13+ ARM64 candidate; SDK validation pending.
- `diagnostic/index.html`: observing page with export, real input targets and
  no third-party injection or synthetic activity.
- `diagnostic/report.py`: conservative Test B report; a passing report is not
  full acceptance or proof beyond the supplied measurements.
- [Architecture comparison](docs/feasibility.md), [Mac test procedure](docs/acceptance.md),
  [Privacy/threat model](docs/security.md), [future release gate](docs/release.md).

Run the independently usable diagnostic on Linux or **inside the Linux guest**:

```sh
python3 diagnostic/serve.py
# Open http://127.0.0.1:8765 in the browser under test, with real user interaction.
python3 -m unittest discover -s tests -v
```

On a physical Apple Silicon Mac, extract the source kit and build/open the app:

```sh
bash Build.command
```

The build produces `macos/build/Focus Isolation Probe.app`. Double-click it on
later launches. Its installer picker creates a dedicated sparse guest disk;
its native menu starts the installed guest and opens reports/instructions.
Bundled read-only test media provides the observer inside Linux. Start with
[Mac tester instructions](macos/MAC-TEST.md), then follow
[guest setup and acceptance](docs/acceptance.md). Building uses an
ad hoc development signature solely for the virtualization entitlement. No
Developer ID identity, notarization, Apple credentials or commercial readiness
is claimed. Guest OS images and Chromium are not bundled.

When hardware becomes available, compile first, record OS/SDK/guest/browser
versions, and run Tests A–F. If VZVirtualMachineView changes guest focus on host
deactivation, record failure and prototype a narrowly scoped framebuffer/input
presenter or CEF OSR before making an architecture decision. Do not override
page APIs or manufacture input.
