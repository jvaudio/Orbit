#!/usr/bin/env bash
# Build a universal, Developer ID signed and notarized ZIP without changing the installed app.
set -euo pipefail
ORBIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ORBIT_ROOT"
: "${ORBIT_NOTARY_PROFILE:?Set ORBIT_NOTARY_PROFILE to an existing notarytool Keychain profile}"
ORBIT_IDENTITY="${ORBIT_CODE_SIGN_IDENTITY:-$(security find-identity -v -p codesigning | awk '/"Developer ID Application:/ { print $2; exit }')}"
[[ -n "$ORBIT_IDENTITY" && "$ORBIT_IDENTITY" != "-" ]] || { echo 'A Developer ID Application identity is required.' >&2; exit 1; }
ORBIT_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
ORBIT_OUTPUT="$ORBIT_ROOT/dist/release/$ORBIT_VERSION"
ORBIT_APP="$ORBIT_OUTPUT/Orbit.app"
ORBIT_ZIP="$ORBIT_OUTPUT/Orbit-$ORBIT_VERSION-macOS-universal.zip"
[[ ! -e "$ORBIT_OUTPUT" ]] || { echo "Output exists: $ORBIT_OUTPUT; move it aside before rebuilding." >&2; exit 1; }
swift test
swift build -c release --product Orbit --arch arm64 --arch x86_64
ORBIT_BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/Orbit"
ORBIT_ARCHS="$(lipo -archs "$ORBIT_BIN")"
[[ " $ORBIT_ARCHS " == *" arm64 "* && " $ORBIT_ARCHS " == *" x86_64 "* ]] || { echo "Missing universal architecture: $ORBIT_ARCHS" >&2; exit 1; }
mkdir -p "$ORBIT_APP/Contents/MacOS" "$ORBIT_APP/Contents/Resources" "$ORBIT_OUTPUT/icon-output"
cp "$ORBIT_BIN" "$ORBIT_APP/Contents/MacOS/Orbit"
cp Resources/Info.plist "$ORBIT_APP/Contents/Info.plist"
xcrun actool Resources/Orbit.icon --compile "$ORBIT_OUTPUT/icon-output" \
    --platform macosx --minimum-deployment-target 14.0 --app-icon Orbit --target-device mac \
    --output-partial-info-plist "$ORBIT_OUTPUT/icon-output/Partial.plist" --output-format human-readable-text
cp "$ORBIT_OUTPUT/icon-output/Assets.car" "$ORBIT_OUTPUT/icon-output/Orbit.icns" "$ORBIT_APP/Contents/Resources/"
codesign --force --options runtime --timestamp --sign "$ORBIT_IDENTITY" "$ORBIT_APP"
codesign --verify --strict --verbose=2 "$ORBIT_APP"
ditto -c -k --keepParent "$ORBIT_APP" "$ORBIT_OUTPUT/Notarization.zip"
xcrun notarytool submit "$ORBIT_OUTPUT/Notarization.zip" --keychain-profile "$ORBIT_NOTARY_PROFILE" \
    --wait --output-format json > "$ORBIT_OUTPUT/notarization.json"
python3 - "$ORBIT_OUTPUT/notarization.json" <<'PY'
import json, sys
result = json.load(open(sys.argv[1]))
print('Notarization:', result.get('status'), 'Submission:', result.get('id'))
if result.get('status') != 'Accepted':
    raise SystemExit('Notarization was not accepted. Inspect the Apple submission log before publishing.')
PY
xcrun stapler staple "$ORBIT_APP"
xcrun stapler validate "$ORBIT_APP"
codesign --verify --deep --strict --verbose=2 "$ORBIT_APP"
spctl --assess --type execute --verbose=2 "$ORBIT_APP"
ditto -c -k --keepParent "$ORBIT_APP" "$ORBIT_ZIP"
(cd "$ORBIT_OUTPUT" && shasum -a 256 "$(basename "$ORBIT_ZIP")" > SHA256SUMS.txt)
echo "Release ready: $ORBIT_ZIP"
