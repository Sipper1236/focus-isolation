# Native focus study — 2026-10-15 UTC

[GitHub macOS 26 ARM64 run 38662037693](https://github.com/Sipper1236/focus-isolation/actions/runs/38662037693)
built app commit `6db0da5`. This is a hosted runner, not the physical M4 acceptance machine.

The normal browser confirmed 20 foreground switches to Finder and back.
All 432 page observations reported `hasFocus() === true` and visibility
`visible`. There were no focus, blur or visibilitychange events. The maximum
sample gap was 408.4 ms. These are finite observations, not a universal guarantee.

The negative control forwards actual host activation to CEF engine focus.
Across two switches it recorded two blur and two focus events and 31 observations
with focus false. Visibility remained visible. This demonstrates sensitivity to
actual engine focus loss without getter overrides or fabricated input.

Raw host timestamps, owned diagnostic observations and evaluator output are
included unchanged. No keyboard/mouse activity was generated. The standard
acceptance evaluator correctly returns FAIL_OR_INCOMPLETE because the run stops
automatically and contains no genuine post-return input. This preliminary study
does not pass full Test B or A–D. Manual genuine input, ordinary browsing,
ClickClickClick, physical M4 behavior, lifecycle/security/performance and release
validation remain required. The app privacy status remains unverified.
