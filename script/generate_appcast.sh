#!/usr/bin/env bash
# Generate a signed feed from the final stapled archive, using only Keychain keys.
set -euo pipefail
ORBIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ORBIT_OUTPUT="${1:?Pass the release output directory}"
ORBIT_APP="$ORBIT_OUTPUT/Orbit.app"
ORBIT_INFO="$ORBIT_APP/Contents/Info.plist"
ORBIT_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ORBIT_INFO")"
ORBIT_BIN="$ORBIT_ROOT/.build/artifacts/sparkle/Sparkle/bin"
ORBIT_KEY_ACCOUNT="${ORBIT_SPARKLE_ACCOUNT:-com.jerryvoelker.Orbit}"
ORBIT_PUBLIC_KEY="$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$ORBIT_INFO")"
[[ "$ORBIT_PUBLIC_KEY" == "$("$ORBIT_BIN/generate_keys" --account "$ORBIT_KEY_ACCOUNT" -p)" ]] || { echo 'Keychain signing key does not match shipped SUPublicEDKey.' >&2; exit 1; }
ORBIT_FEED_WORK="$(mktemp -d "$ORBIT_OUTPUT/appcast.XXXXXX")"
trap 'rm -rf "$ORBIT_FEED_WORK"' EXIT
cp "$ORBIT_OUTPUT/Orbit-$ORBIT_VERSION-macOS-universal.zip" "$ORBIT_FEED_WORK/"
if [[ -f "$ORBIT_ROOT/docs/releases/$ORBIT_VERSION.md" ]]; then
    cp "$ORBIT_ROOT/docs/releases/$ORBIT_VERSION.md" "$ORBIT_FEED_WORK/Orbit-$ORBIT_VERSION-macOS-universal.md"
fi
"$ORBIT_BIN/generate_appcast" --account "$ORBIT_KEY_ACCOUNT" --maximum-deltas 0 \
    --download-url-prefix "https://github.com/jvaudio/Orbit/releases/download/v$ORBIT_VERSION/" \
    --link https://github.com/jvaudio/Orbit --embed-release-notes "$ORBIT_FEED_WORK"
swift "$ORBIT_ROOT/script/verify_appcast.swift" "$ORBIT_INFO" "$ORBIT_FEED_WORK/appcast.xml" "$ORBIT_OUTPUT/Orbit-$ORBIT_VERSION-macOS-universal.zip"
cp "$ORBIT_FEED_WORK/appcast.xml" "$ORBIT_OUTPUT/appcast.xml"
echo 'Signed appcast ready; upload it together with the ZIP to the matching GitHub release.'
