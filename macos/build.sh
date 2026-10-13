#!/bin/bash
set -euo pipefail
if [[ $(uname -s) != Darwin || $(uname -m) != arm64 ]]; then
  echo 'This probe requires macOS on Apple Silicon, macOS 13+ and Xcode command-line tools.' >&2
  exit 1
fi
cd "$(dirname "$0")"
mkdir -p build
probe_app="build/Focus Isolation Probe.app"
mkdir -p "$probe_app/Contents/MacOS" "$probe_app/Contents/Resources"
xcrun swiftc -swift-version 5 -target arm64-apple-macos13.0 -framework AppKit -framework Virtualization VMProbe.swift -o "$probe_app/Contents/MacOS/VMProbe"
cp Info.plist "$probe_app/Contents/Info.plist"
cp MAC-TEST.md "$probe_app/Contents/Resources/MAC-TEST.md"
cp -R ../diagnostic "$probe_app/Contents/Resources/"
# Explicit observer media avoids a shared host directory. hdiutil is built into macOS.
hdiutil makehybrid -iso -joliet -ov -o "$probe_app/Contents/Resources/FocusTests.iso" "$probe_app/Contents/Resources/diagnostic"
# Development-only ad hoc signature. Never represented as Developer ID/notarized.
codesign --force --sign - --entitlements probe.entitlements "$probe_app"
codesign --verify --strict --verbose=2 "$probe_app"
# Preserve the documented CLI entry point.
ln -sfn 'Focus Isolation Probe.app/Contents/MacOS/VMProbe' build/VMProbe
echo "Built: $PWD/$probe_app"
echo 'Development ad hoc signature only; not Developer ID signed or notarized.'
