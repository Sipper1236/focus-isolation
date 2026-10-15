#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
if [[ $(uname -s) != Darwin || $(uname -m) != arm64 ]]; then
  echo 'Build this prototype on an Apple silicon Mac.' >&2
  exit 1
fi
if ! command -v cmake >/dev/null 2>&1; then
  echo 'Install CMake 3.21+ first (for example: brew install cmake), then rerun Build.command.' >&2
  exit 1
fi
cef_root=$(python3 fetch-cef.py)
cmake -S . -B build -G 'Unix Makefiles' -DCMAKE_BUILD_TYPE=Release -DPROJECT_ARCH=arm64 -DCEF_ROOT="$cef_root"
cmake --build build --parallel 3
probe_app="$PWD/build/bin/FocusBrowser.app"
framework="$probe_app/Contents/Frameworks/Chromium Embedded Framework.framework"
test -f "$framework/Libraries/libcef_sandbox.dylib"
# Development-only signing, inside out. Production signing/notarization is pending.
while IFS= read -r -d '' lib; do codesign --force --sign - "$lib"; done < <(find "$framework/Versions/A/Libraries" -type f -name '*.dylib' -print0)
codesign --force --sign - "$framework"
while IFS= read -r -d '' helper; do
  codesign --force --sign - --entitlements development.entitlements "$helper"
done < <(find "$probe_app/Contents/Frameworks" -maxdepth 1 -type d -name '*Helper*.app' -print0)
codesign --force --sign - --entitlements development.entitlements "$probe_app"
codesign --verify --deep --strict --verbose=2 "$probe_app"
echo "Built: $probe_app"
echo 'Experimental native Chromium browser. Focus isolation is NOT verified.'
