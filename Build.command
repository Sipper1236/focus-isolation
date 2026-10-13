#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
if ! xcrun --find swiftc >/dev/null 2>&1; then
  echo 'Install Apple command-line developer tools, then run this file again.'
  xcode-select --install
  exit 1
fi
bash macos/build.sh
open 'macos/build/Focus Isolation Probe.app'
