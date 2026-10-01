#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
platform=$(xcrun --sdk macosx --show-sdk-platform-path)
evidence=../references/onexray-tests/native
mkdir -p "$evidence"
xcrun swiftc \
  -swift-version 6 \
  -F "$platform/Developer/Library/Frameworks" \
  -I "$platform/Developer/usr/lib" \
  -L "$platform/Developer/usr/lib" \
  -Xlinker -rpath -Xlinker "$platform/Developer/Library/Frameworks" \
  -Xlinker -rpath -Xlinker "$platform/Developer/usr/lib" \
  swift/macOS/SystemExtensionManager.swift test/native/SystemExtensionActivationTests.swift \
  -o "$evidence/system-extension-activation-tests"
"$evidence/system-extension-activation-tests"
