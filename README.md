# Orbit

A native macOS menu bar home for small, independently enabled utilities. Find My Mouse spotlights a rapidly jiggled pointer and dims every display. Right-Click Menu adds instant action tiles and native color tags in supported Finder views and text controls.

## Run

Requires macOS 14 or later and Xcode with its command-line tools selected. No third-party packages or network services are needed.

```sh
./script/build_and_run.sh
```

The same command is wired to the Codex **Run** action. It builds, packages, and validates a fresh `dist/Orbit.app`, then replaces `/Applications/Orbit.app` and opens the installed copy's utilities window. The running app is stopped only after the new bundle is ready. The script requires permission to write to Applications; it does not invoke `sudo`.

Run captures the installed app's actual login-item state before replacement. If launch at login was enabled, the new installed app restores registration if needed and the script checks it afterward. An off setting stays off; pending system approval is never bypassed. The first update from a build without the status command leaves its system registration unchanged. Your enabled registration was verified across that migration.

Opening the installed app normally shows the window on first launch and runs from the menu bar on subsequent launches. Closing its window keeps utilities running; use **Quit Orbit** in the menu bar to exit.

Open **Find My Mouse** in the sidebar and enable it. Choose Low, Medium, or High shake sensitivity; adjust spotlight radius and backdrop dimming; or use **Preview Spotlight** while the utility is off. Clicking any mouse button or holding the pointer still for one second dismisses the spotlight. Input passes through to the underlying app. Apple's cursor enlargement preference is left unchanged.

## macOS design

Orbit uses a native split-view sidebar and unified window toolbar. On macOS 26 and later it adopts Liquid Glass actions, soft scroll-edge effects, and concentric content surfaces, picking up macOS 27's system refinements. Earlier systems use standard bordered controls and rounded content surfaces. The app still targets macOS 14.

Find My Mouse includes an illustrative appearance preview that responds to the radius and dimming controls; the toolbar's **Preview Spotlight** action (⌘P) shows the actual desktop effect. The preview is drawn locally and does not capture your screen. Settings has native **General** and **About** tabs, including an app-only **System / Light / Dark** appearance choice. System is the default.

Content uses semantic colors, with stronger borders for increased contrast or Show Borders. Reduce Transparency replaces the custom preview glass label with a solid system surface; native glass controls follow the system accessibility preferences. The preview has a descriptive accessibility label and no continuous animation or polling.

For optional launch at login, use Run to install Orbit and enable **Launch Orbit at login** in Settings. Orbit reports the actual Service Management status, including approval requirements or failures. Run keeps using the same installed location and bundle identifier for future updates. Avoid manually launching the development bundle alongside the installed copy.

## Development

```sh
swift test
./script/build_and_run.sh --build-only
./script/build_and_run.sh --verify
./script/build_and_run.sh --logs
./script/build_and_run.sh --telemetry
./script/build_and_run.sh --debug
```

`--build-only` produces the development bundle without replacing or restarting installed Orbit. Other modes install and use `/Applications/Orbit.app`. `--verify` checks the installed process path and preserves/checks previously enabled login registration; it does not prove an actual future login session, shake detection, or visual behavior. The local bundle is built for the current Mac's architecture. Local builds use an available Developer ID signing identity to preserve Accessibility approval across updates; set `ORBIT_CODE_SIGN_IDENTITY` to choose an identity explicitly (or `-` for ad-hoc signing). Without an identity, builds fall back to ad-hoc signing and may need renewed Accessibility approval. Notarization, universal packaging, public distribution, and automatic updates are not configured.

### Testing direct menu actions

DEBUG builds support `./script/build_and_run.sh run --context-test-root /private/tmp/orbit-instant-regression.NAME` for an existing disposable test root. The developer window opens the actual production menu and handlers for explicitly selected files/folders, making them accessible to computer-use automation without synthesizing Finder input. Only appropriately named roots directly under /tmp are accepted, and escaping targets are rejected. Relaunch with normal Run afterward. This mode is absent in release builds and is never shown on a normal launch.

### Adding a utility

1. Implement `UtilityModule` with stable metadata, persisted enable state, and idempotent `start()` / `stop()` methods. Stopping releases resources without erasing the enable preference.
2. Register the instance in `OrbitModel`. The sidebar and overview list registered utilities automatically.
3. Add the module's configuration view to the detail routing in `UtilitiesView`, plus any menu bar shortcuts. Put platform services behind small injectable interfaces.
4. Test activation, cleanup, persistence, and relevant platform failures. Find My Mouse does not need changes when another utility is added.

`OrbitCore` contains the utility contracts and registry, namespaced preferences, pure shake detector, and spotlight timing model. The executable contains SwiftUI views and narrowly scoped AppKit services. Preferences use the `orbit.*` namespace in the app's local defaults domain (`com.jerryvoelker.Orbit`).

### Mouse behavior and resource use

Find My Mouse uses mouse-only local and global `NSEvent` monitors. The independent Right-Click Menu utility uses a mouse-only active event filter; Orbit installs no keyboard hook and requests no screen-recording access. Intercepted button presses are also delivered internally to Find My Mouse so the spotlight still dismisses immediately. While enabled but inactive, it does not poll the pointer or redraw overlays. Disabled utilities remove their monitors. Preview temporarily installs monitors, then removes them on dismissal if the utility remains disabled. A short-lived idle timer exists only while a spotlight is visible.

Detection uses a 750 ms rolling history, at least three direction reversals with eight-point hysteresis, a movement-area diagonal of at most 520 points, and a travel-to-area ratio of at least 2.5. Only the most recent contiguous compact movement is considered, so moving across the desktop immediately before shaking does not block activation. The original 220-point limit rejected natural accelerated pointer shakes seen in physical diagnostics; the limit was widened with regression coverage for 300–500-point oscillations and oversized sweeps. Minimum travel is 450 / 300 / 180 points for Low / Medium / High. A 600 ms cooldown follows dismissal. Broader hardware calibration remains outstanding.

The overlay uses one nonactivating, click-through panel per screen, with a shared desktop-space spotlight position. It joins Spaces and full-screen spaces using AppKit collection behavior. Sleep, inactive sessions, and display changes clear transient state. Reduce Motion removes fades.

Mouse samples preserve each event's recorded position, timestamp, and drag type. Orbit's own windows explicitly accept mouse-move events while monitoring is installed; the original window flags are restored on stop. This covers the application-local delivery path that global monitors intentionally exclude.

For troubleshooting only, `./script/build_and_run.sh run --mouse-diagnostics` enables aggregate movement diagnostics in the local unified log. It records local/global event counts, travel distance, movement-area size, and reversal count, without pointer coordinates or app names. A normal Run omits these diagnostics.

## App icon

`Resources/Orbit.icon` is the editable Icon Composer document. Its separate orbital ring and tool-module SVG layers represent independent utilities in one app. The build compiles it with Apple's asset compiler into a layered `Assets.car` and an `Orbit.icns` compatibility icon. The app bundle declares both icon keys and uses the icon in Overview and About.

The menu bar uses an 18-point vector template of the same ring and three tool modules. macOS supplies its monochrome appearance so it stays readable across menu bar backgrounds and selection states.

Default and dark macOS 27 renders, source artwork, and design notes are in `Resources/IconArtwork`. See its [design notes](Resources/IconArtwork/README.md) for the concept and image-generation prompts. The final production mark is clean vector artwork, with glass, lighting, and appearance changes supplied by Apple's native icon rendering.

## Verification

See [VALIDATION.md](VALIDATION.md) for completed checks and physical checks still needed.

## Reference

Behavior is inspired by Microsoft's [PowerToys Mouse Utilities](https://learn.microsoft.com/en-us/windows/powertoys/mouse-utilities#find-my-mouse) and its [Find My Mouse implementation](https://github.com/microsoft/PowerToys/tree/main/src/modules/MouseUtils/FindMyMouse). Orbit is a native Swift implementation, without copied PowerToys source or assets.


## Right-Click Menu

The independently enabled utility opens Orbit’s menu directly in supported Finder file views and focused text controls. Large Cut, Copy, Paste, Rename, Share, and Delete tiles always occupy the top row above native macOS color tags. Paste availability follows the current context and clipboard. Unsupported actions are disabled.

Open Orbit → Right-Click Menu to review the permission-free preview. For live menus, use **Allow Accessibility Access…**, enable `/Applications/Orbit.app` in System Settings → Privacy & Security → Accessibility, click **Check Access**, and enable the utility. Existing approval remains valid when rebuilding with the same signing identity.

A mouse-only session event filter intercepts right-click and Control-click before the app receives them. Its dedicated run-loop thread does no Accessibility queries or filesystem work. After the button is released, Orbit resolves the file or focused text control and opens its own AppKit menu. It never opens the native context menu to construct this list. Unsupported/ambiguous contexts receive their original click, and right-drag gestures are passed through. Disabled or failed interception restores native input.

**Show macOS Menu** explicitly passes the original click through once. App-specific commands, third-party extensions, and advanced Finder commands are available there instead of being automatically mirrored. Orbit supplies Open, Open With, and Reveal in Finder for supported file targets. A file must be unambiguous; Finder sidebars and unknown custom controls retain native behavior. Read-only text may expose Copy while other editing actions remain disabled; secure fields are excluded.

Finder actions operate on captured file URLs, not a later Finder selection. Copy writes standard file URLs to the clipboard. Cut records the clipboard generation, exact URLs, and file identities; files stay put until Paste moves them. Changing the clipboard, disabling the utility, or restarting Orbit clears Cut intent. Copy/move preflights the full batch, refuses replacement conflicts and recursive folder pastes, and runs file work off the UI thread. A multi-item operation may partially complete if an external filesystem error occurs during execution; check the destination before retrying. The macOS fallback provides replacement dialogs and advanced native behavior.

Rename uses an Orbit dialog. Share opens the system sharing chooser. Delete uses FileManager’s recoverable Trash API. Every mutation rechecks captured file identity; changed targets are rejected. Color buttons use NSURL’s native tag setter, respect the system’s standard color-label names, and preserve custom tags. The clear button removes standard color tags only. Supported text controls invoke their app’s existing Cut/Copy/Paste commands through Accessibility without opening a context menu.

Disabling the utility removes the input filter, dismisses its UI, and clears transient state. No pointer polling, keyboard monitoring, screen capture, or native-menu snapshot persistence is used. No native context menu is opened during ordinary direct file actions.

Tests cover balanced click suppression, drag pass-through, permissions/lifecycle, spotlight dismissal when a click is intercepted, file copy/move/rename, identity checks, conflict/recursion refusal, native tagging with custom-tag preservation, clipboard generation and file-set matching, and menu action availability. See VALIDATION.md for current live verification and limitations. The older capture-and-replace validation history there applies to the prior architecture.
