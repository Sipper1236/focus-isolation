#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
if ! xcrun --find swiftc >/dev/null 2>&1; then
  echo 'Install Apple command-line developer tools, then run this file again.'
  xcode-select --install
  exit 1
fi
bash native-cef/build.sh
open 'native-cef/build/bin/FocusBrowser.app'
