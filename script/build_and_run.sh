#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
case "$MODE" in
    run|--debug|--logs|--telemetry|--verify|--build-only) ;;
    *) echo "usage: $0 [run [app arguments...]|--debug|--logs|--telemetry|--verify|--build-only]" >&2; exit 2 ;;
esac

ORBIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ORBIT_ROOT"
ORBIT_DIST_APP="$ORBIT_ROOT/dist/Orbit.app"
ORBIT_INSTALLED_APP="/Applications/Orbit.app"
ORBIT_INSTALLED_BINARY="$ORBIT_INSTALLED_APP/Contents/MacOS/Orbit"
ORBIT_INSTALL_WORK=""
ORBIT_INSTALL_COMPLETE=0
ORBIT_PACKAGE_WORK=""

cleanup() {
    if [[ -n "$ORBIT_PACKAGE_WORK" ]]; then rm -rf "$ORBIT_PACKAGE_WORK"; fi
    if [[ -n "$ORBIT_INSTALL_WORK" ]]; then
        if [[ "$ORBIT_INSTALL_COMPLETE" == 1 || ! -d "$ORBIT_INSTALL_WORK/Previous.app" ]]; then
            rm -rf "$ORBIT_INSTALL_WORK"
        else
            echo "Previous installed build retained at $ORBIT_INSTALL_WORK/Previous.app" >&2
        fi
    fi
}
trap cleanup EXIT

# Finish compiling, packaging and validating before interrupting the installed app.
swift build --product Orbit
ORBIT_BINARY="$(swift build --show-bin-path)/Orbit"
ORBIT_PACKAGE_WORK="$(mktemp -d "$ORBIT_ROOT/.build/orbit-package.XXXXXX")"
ORBIT_STAGED_APP="$ORBIT_PACKAGE_WORK/Orbit.app"
mkdir -p "$ORBIT_STAGED_APP/Contents/MacOS" "$ORBIT_STAGED_APP/Contents/Resources"
cp "$ORBIT_BINARY" "$ORBIT_STAGED_APP/Contents/MacOS/Orbit"
cp "$ORBIT_ROOT/Resources/Info.plist" "$ORBIT_STAGED_APP/Contents/Info.plist"
ORBIT_ICON_OUTPUT="$ORBIT_ROOT/.build/icon-output"
mkdir -p "$ORBIT_ICON_OUTPUT"
xcrun actool "$ORBIT_ROOT/Resources/Orbit.icon" \
    --compile "$ORBIT_ICON_OUTPUT" \
    --platform macosx --minimum-deployment-target 14.0 \
    --app-icon Orbit --target-device mac \
    --output-partial-info-plist "$ORBIT_ICON_OUTPUT/Partial.plist" \
    --output-format human-readable-text
cp "$ORBIT_ICON_OUTPUT/Assets.car" "$ORBIT_ICON_OUTPUT/Orbit.icns" "$ORBIT_STAGED_APP/Contents/Resources/"
chmod +x "$ORBIT_STAGED_APP/Contents/MacOS/Orbit"
# A stable signing identity keeps Accessibility approval attached across rebuilds.
# Explicitly set ORBIT_CODE_SIGN_IDENTITY=- to opt into ad-hoc development builds.
ORBIT_SIGNING_IDENTITY="${ORBIT_CODE_SIGN_IDENTITY:-}"
if [[ -z "$ORBIT_SIGNING_IDENTITY" ]]; then
    ORBIT_SIGNING_IDENTITY="$(/usr/bin/security find-identity -v -p codesigning | /usr/bin/awk '/"Developer ID Application:/ { print $2; exit }')"
fi
if [[ -z "$ORBIT_SIGNING_IDENTITY" ]]; then
    ORBIT_SIGNING_IDENTITY="-"
    echo "No Developer ID identity found; Accessibility approval may need renewal after builds." >&2
fi
/usr/bin/codesign --force --timestamp=none --sign "$ORBIT_SIGNING_IDENTITY" "$ORBIT_STAGED_APP"
/usr/bin/codesign --verify --strict "$ORBIT_STAGED_APP"

ORBIT_LOGIN_STATE="unknown"
if [[ "$MODE" != "--build-only" && -e "$ORBIT_INSTALLED_APP" ]]; then
    if [[ ! -d "$ORBIT_INSTALLED_APP" || -L "$ORBIT_INSTALLED_APP" ]]; then
        echo "Refusing to replace a non-bundle or symlink at $ORBIT_INSTALLED_APP" >&2
        exit 1
    fi
    ORBIT_EXISTING_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$ORBIT_INSTALLED_APP/Contents/Info.plist")"
    if [[ "$ORBIT_EXISTING_ID" != "com.jerryvoelker.Orbit" ]]; then
        echo "Refusing to replace a different application at $ORBIT_INSTALLED_APP" >&2
        exit 1
    fi
    /usr/bin/codesign --verify --strict "$ORBIT_INSTALLED_APP"
    ORBIT_SUPPORTS_STATUS="$(/usr/libexec/PlistBuddy -c 'Print :OrbitSupportsLoginItemStatusCommands' "$ORBIT_INSTALLED_APP/Contents/Info.plist" 2>/dev/null || true)"
    if [[ "$ORBIT_SUPPORTS_STATUS" == true ]]; then
        ORBIT_LOGIN_STATE="$("$ORBIT_INSTALLED_BINARY" --login-item-status)"
        case "$ORBIT_LOGIN_STATE" in
            enabled|requires-approval|disabled) ;;
            *) echo "Could not determine the installed app's login state; leaving it untouched." >&2; exit 1 ;;
        esac
    else
        echo "Existing build predates login-state capture; retaining its system registration during this first update."
    fi
fi

# Replace the development artifact with a fresh bundle, never copying over a running executable.
mkdir -p "$ORBIT_ROOT/dist"
if [[ -e "$ORBIT_DIST_APP" ]]; then mv "$ORBIT_DIST_APP" "$ORBIT_PACKAGE_WORK/Previous-dist.app"; fi
mv "$ORBIT_STAGED_APP" "$ORBIT_DIST_APP"
if [[ "$MODE" == "--build-only" ]]; then
    echo "Built $ORBIT_DIST_APP; installed Orbit and login registration were not changed."
    exit 0
fi

# Stage on the destination filesystem so installing the new app is a directory rename.
ORBIT_INSTALL_WORK="$(mktemp -d /Applications/.Orbit-update.XXXXXX)"
/usr/bin/ditto "$ORBIT_DIST_APP" "$ORBIT_INSTALL_WORK/Orbit.app"
/usr/bin/codesign --verify --strict "$ORBIT_INSTALL_WORK/Orbit.app"

# Stop only Orbit copies from this project or the installed location.
ORBIT_OLD_PIDS=()
for ORBIT_PID in $(pgrep -x Orbit || true); do
    ORBIT_PROCESS_PATH="$(ps -p "$ORBIT_PID" -o comm= || true)"
    if [[ "$ORBIT_PROCESS_PATH" == "$ORBIT_INSTALLED_BINARY" || "$ORBIT_PROCESS_PATH" == "$ORBIT_DIST_APP/Contents/MacOS/Orbit" ]]; then
        ORBIT_OLD_PIDS+=("$ORBIT_PID")
        kill -TERM "$ORBIT_PID" 2>/dev/null || true
    fi
done
for ORBIT_PID in ${ORBIT_OLD_PIDS[@]+"${ORBIT_OLD_PIDS[@]}"}; do
    for ((ORBIT_ATTEMPT=0; ORBIT_ATTEMPT<50; ORBIT_ATTEMPT++)); do
        if ! kill -0 "$ORBIT_PID" 2>/dev/null; then break; fi
        sleep 0.1
    done
    if kill -0 "$ORBIT_PID" 2>/dev/null; then
        echo "Orbit did not exit; the installed bundle has not been replaced." >&2
        exit 1
    fi
done

if [[ -e "$ORBIT_INSTALLED_APP" ]]; then mv "$ORBIT_INSTALLED_APP" "$ORBIT_INSTALL_WORK/Previous.app"; fi
if ! mv "$ORBIT_INSTALL_WORK/Orbit.app" "$ORBIT_INSTALLED_APP"; then
    if [[ -d "$ORBIT_INSTALL_WORK/Previous.app" ]]; then mv "$ORBIT_INSTALL_WORK/Previous.app" "$ORBIT_INSTALLED_APP"; fi
    exit 1
fi
/usr/bin/codesign --verify --strict "$ORBIT_INSTALLED_APP"

ORBIT_LAUNCH_ARGS=()
case "$ORBIT_LOGIN_STATE" in
    enabled|requires-approval) ORBIT_LAUNCH_ARGS+=(--restore-login-item) ;;
esac
if [[ "$MODE" == run || "$MODE" == --debug ]]; then
    ORBIT_LAUNCH_ARGS+=(--show-utilities)
fi
if [[ "$MODE" == run ]]; then ORBIT_LAUNCH_ARGS+=("${@:2}"); fi

if [[ "$MODE" == --debug ]]; then
    ORBIT_INSTALL_COMPLETE=1
    /usr/bin/lldb -- "$ORBIT_INSTALLED_BINARY" ${ORBIT_LAUNCH_ARGS[@]+"${ORBIT_LAUNCH_ARGS[@]}"}
    exit 0
fi
/usr/bin/open -n "$ORBIT_INSTALLED_APP" --args ${ORBIT_LAUNCH_ARGS[@]+"${ORBIT_LAUNCH_ARGS[@]}"}
ORBIT_LAUNCHED=0
for ((ORBIT_ATTEMPT=0; ORBIT_ATTEMPT<50; ORBIT_ATTEMPT++)); do
    for ORBIT_PID in $(pgrep -x Orbit || true); do
        if [[ "$(ps -p "$ORBIT_PID" -o comm= || true)" == "$ORBIT_INSTALLED_BINARY" ]]; then ORBIT_LAUNCHED=1; break; fi
    done
    if [[ "$ORBIT_LAUNCHED" == 1 ]]; then break; fi
    sleep 0.1
done
if [[ "$ORBIT_LAUNCHED" != 1 ]]; then echo "Installed Orbit did not launch." >&2; exit 1; fi

if [[ "$ORBIT_LOGIN_STATE" == enabled || "$ORBIT_LOGIN_STATE" == requires-approval ]]; then
    ORBIT_NEW_LOGIN_STATE="disabled"
    for ((ORBIT_ATTEMPT=0; ORBIT_ATTEMPT<20; ORBIT_ATTEMPT++)); do
        ORBIT_NEW_LOGIN_STATE="$("$ORBIT_INSTALLED_BINARY" --login-item-status)"
        if [[ "$ORBIT_NEW_LOGIN_STATE" == enabled || "$ORBIT_NEW_LOGIN_STATE" == requires-approval ]]; then break; fi
        sleep 0.1
    done
    if [[ "$ORBIT_NEW_LOGIN_STATE" != enabled ]]; then
        echo "Launch at login requires attention ($ORBIT_NEW_LOGIN_STATE). Check Orbit Settings → General." >&2
        exit 1
    fi
    echo "Launch at login remains enabled."
fi
ORBIT_INSTALL_COMPLETE=1
echo "Running $ORBIT_INSTALLED_APP"

case "$MODE" in
    --logs) /usr/bin/log stream --info --style compact --predicate 'process == "Orbit"' ;;
    --telemetry) /usr/bin/log stream --info --style compact --predicate 'subsystem == "com.jerryvoelker.Orbit"' ;;
    --verify) echo "Installed process launch verified; this does not verify a future login session." ;;
esac
