# Release gate — all product items pending

The current probe is development-only and has no distributable product build.
Do not distribute it as the commercial browser. `macos/build.sh` uses an ad hoc
signature for development, not Developer ID, hardened runtime or notarization.

- [ ] Compile/run the probe on real Apple Silicon and pin validated SDK/guest/Chromium versions.
- [ ] Pass genuine A–D; publish decision and failures; measure E/F/performance.
- [ ] Implement selected runtime and minimal native UI with accurate degraded status.
- [ ] Verify Chromium sandbox/process isolation and guest/host filesystem boundary.
- [ ] Implement profile lifecycle, erase control, crash recovery and global single session.
- [ ] Build secure licensing service, owner-only tool and deployment/backup/rotation instructions.
- [ ] Verify launch/start denial, device quota races, replay rejection, expiry and revocation.
- [ ] Verify no content/input/history/clipboard reaches licensing server or logs.
- [ ] Pin toolchain, dependencies and guest image; document deterministic source/artifact provenance.
- [ ] Review all redistribution notices, Chromium/CEF/guest licenses and codecs.
- [ ] Package ARM64 app with minimal entitlements and hardened runtime.
- [ ] Sign nested executables/helpers/frameworks in dependency order using real Developer ID credentials.
- [ ] Submit final archive with `xcrun notarytool`, review success log and staple ticket.
- [ ] Verify codesign, `stapler validate`, Gatekeeper (`spctl`) and quarantined fresh download on clean Mac.
- [ ] Implement signed updates with protected update keys and anti-downgrade policy; test rejection cases.
- [ ] Publish accurate privacy policy, supported behaviors, requirements and owner support process.
- [ ] Test direct-download install, upgrade, uninstall and profile retention/erasure.

Store signing/notarization/administrator credentials in managed secrets, never
source control. Exact release commands depend on the runtime selected after
acceptance; native CEF helpers and VM guest artifacts have different signing
and packaging needs. Do not invent release success, credentials or an updater
around an architecture that has not passed feasibility.
