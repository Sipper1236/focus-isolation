# Privacy and preliminary threat model

**Design, not a completed security review.** Focus isolation has not passed
acceptance and is not a complete security boundary. A site can still infer
inactivity from missing input, timing, networking, sockets, application logic
or other signals. We promise neither invisibility nor indistinguishability.

| Threat | Proposed protection | Residual risk / verification |
|---|---|---|
| Malicious webpage | Chromium renderer sandbox, site isolation, patched guest | Browser vulnerabilities and fingerprinting remain; sandbox must be verified |
| Renderer/browser compromise | VM guest/host boundary, no shared directories | Guest compromise, hypervisor bugs, local-network access; VM is not absolute containment |
| Host file access | No VM filesystem shares, clipboard or file bridge in probe | Later file upload/download bridges require explicit scope and consent |
| Host switching leakage | Independent guest desktop or verified CEF OSR domain | Unproven; input inactivity and host sleep remain observable indirectly |
| Unauthorized use | Future online launch/session authorization and finite leases | Client tampering cannot be completely prevented on customer-controlled hardware |
| Credential theft/replay | Device keys in Keychain, one-use challenges, request/grant binding | Malware in user session and device-key compromise; revoke device server-side |
| Licensing-server compromise | Minimal records, protected signing keys, restricted owner access | Attacker may issue/revoke access or read license metadata; should have no browsing contents |

## Local handling

Guest cookies, storage, downloads and login state remain in a dedicated guest
profile on its disk, separate from everyday browsers. The prototype creates a
0700 state directory and 0600 logs; the operator must protect the external disk
with 0600 permissions and host FileVault. It does not implement independent
encrypted guest storage, secure deletion, profile reset UI or secret recovery.
Product erasure should stop the VM, delete the dedicated profile/storage and
offer full guest reset; SSD snapshots/backups complicate guaranteed erasure.

The diagnostic retains focus/visibility timestamps and event kinds in page
memory, and explicitly exports a local JSON file. It includes user agent, but
no input values, keys, passwords, clipboard data, browsing history or arbitrary
page contents. The host logger records activation/sleep/runtime event kinds
and timestamps, never other app names. No telemetry or license requests exist
in this feasibility probe. Keep diagnostic reports local and delete after
review. Production must not generalize diagnostic recording to normal sites.

## Authorization design for milestone 4 (not implemented)

Separate HTTPS licensing service from the local browser runtime. Collect only
account ID/contact, entitlement state, expiration, configured device limit,
device public keys/IDs, owner-recorded cash receipt amount/date/reference, and
minimal security audits. No card processor or online payment collection.
Authenticated owner CLI administers activation, suspension, revocation,
reassignment, device removal and cash receipt recording; owner credentials are
never shipped with the app. Use MFA/limited administrative roles and audit
changes; cash receipt entries are not proof of an electronic payment.

Every launch obtains a fresh server `launch` grant. Every new browser session
separately obtains a `session-start` grant bound to user, registered device key,
purpose, random nonce, session ID, issue time, expiry and server-side license
revision. Use TLS and asymmetric signed grants with pinned issuer public keys
and rotation; never embed a privileged signing key. Bind responses to requests,
consume nonces once, reject expired/wrong-purpose grants, transact device
registration and quota checks, and verify entitlements on every renewal.
The browser process must not start before the start grant has been verified.

Provisional active lease: 120 seconds; renew every 30 seconds using the device
key and server challenge. Retry transient failures within the current lease,
show an immediate connectivity warning, and never extend expiry locally.
On authenticated revocation stop at once. On lease expiry block further user
input and network/browser execution, preserving VM disk and volatile state
where a local pause safely permits it. Show a native unavailable/expired view
without exposing a usable unlicensed browser. Resume only with fresh server
authorization. A paused VM cannot claim uninterrupted browser lifecycle;
unsaved work cannot always be preserved. Test this behavior before release.
Use monotonic deadline enforcement, server time binding, rollback detection,
and fail-closed verification rather than trusting only customer wall time.

Proposed retention: security audit metadata 30 days; revoked device keys 90
days for abuse investigation; license/cash records only as long as necessary
for account service and applicable accounting obligations. Establish a real
owner deletion/export process and jurisdiction-appropriate retention before
publishing a privacy policy. Avoid raw IP retention unless a documented
security need justifies a short period. HTTP bodies must not enter access logs.

## Unsupported/unimplemented

No commercial authorization, update channel, verified OS sandbox, validated
guest image, native browser controls, macOS accessibility/IME integration,
host clipboard/file transfers, WebAuthn/DRM/audio support, reliable global
single-session enforcement, crash-safe page logging or secure profile-erasure
control yet. VM/source/API availability alone verifies none of these.
