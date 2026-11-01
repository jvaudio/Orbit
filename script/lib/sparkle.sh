#!/usr/bin/env bash
# Caller supplies app, SwiftPM products directory, identity, and timestamp mode.
orbit_embed_sparkle() {
    local app="$1" products="$2" identity="$3" timestamp="$4"
    local framework="$app/Contents/Frameworks/Sparkle.framework"
    [[ -d "$products/Sparkle.framework" ]] || { echo "Missing Sparkle.framework in $products" >&2; return 1; }
    mkdir -p "$app/Contents/Frameworks" "$app/Contents/Resources/ThirdParty"
    cp "$ORBIT_ROOT/Resources/ThirdParty/Sparkle-LICENSE.txt" "$app/Contents/Resources/ThirdParty/"
    ditto "$products/Sparkle.framework" "$framework"
    local versioned nested
    versioned="$(cd "$framework/Versions/Current" && pwd -P)"
    for nested in XPCServices/Downloader.xpc XPCServices/Installer.xpc Autoupdate Updater.app; do
        [[ ! -e "$versioned/$nested" ]] || codesign --force --options runtime "$timestamp" \
            --preserve-metadata=entitlements --sign "$identity" "$versioned/$nested"
    done
    codesign --force --options runtime "$timestamp" --sign "$identity" "$framework"
}
