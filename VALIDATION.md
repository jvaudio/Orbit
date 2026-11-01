# Orbit validation

Validated locally on October 31, 2026, on Apple silicon with macOS 27.2 / Xcode 27.2. The package's deployment target is macOS 14; a physical macOS 14 installation and Intel Mac were not available.

## Instant-menu architecture update

The user approved replacing automatic native-command mirroring with an immediate Orbit-owned menu and explicit Show macOS Menu fallback. The new build intercepts mouse gestures before delivery and constructs menus without opening native context menus. File operations, tags, rename, and the system Share chooser are now independently implemented; supported text editing uses hidden main-menu actions. The earlier successful device checks below apply to the previous capture-and-replay architecture and are not proof of the new implementation.

All **65 automated tests pass** after the change. New checks cover balanced click suppression/drag pass-through, direct copy/move/rename, identity and conflict guards, recursive paste refusal, native tag toggling/clearing with custom-tag preservation, and delivery of intercepted clicks to Find My Mouse. No compiler warnings were reported in the final run. Physical Finder testing confirmed Orbit appears directly without a native-menu flash, Blue tagging writes native metadata, and the explicit Show macOS Menu fallback works. All six direct file actions were subsequently exercised through the actual production Orbit menu using CUA and explicit disposable targets; see the instant-menu action regression below. The system input-filter gesture remains separately verified by the user. macOS 14 and Intel remain unavailable for device testing.

## Previous capture-and-replace verification

With the user's physical clicks and computer-use inspection, verified in Finder: Copy, Orbit Paste, Cut followed by native move-Paste, Rename, Share chooser opening, Delete to recoverable Trash, Blue addition/removal, Show macOS Menu, and Get Info from Orbit's lower list. File contents and source/destination locations were checked; Trash identity was confirmed by inode. Share sending was not exercised.

Verified Orbit Cut/Paste in TextEdit using the disposable line `Orbit cross-app context menu test.`. User observed removal and restoration; native invocation logs succeeded and the restored text matched exactly. Saved the new test document locally as `/private/tmp/orbit-menu.AOksEk/Orbit TextEdit Test 01a1931c.rtf` and closed it. Other user documents were not edited.

Latest automated suite: **53 passing tests**. Installed `/Applications/Orbit.app` retains Accessibility approval, enabled utilities, and launch at login. The brief native-menu flash remains part of capture-and-replace behavior. Individual other colors, clear-all, multi-selection/custom-tag combinations, all third-party plugins, all apps, multi-display/Spaces/full-screen configurations, and macOS 14/Intel have not been exhaustively verified. Detailed chronological evidence follows; earlier pending statuses describe intermediate builds.

## Automated checks

- `swift test`: 65 tests pass across OrbitCoreTests and OrbitTests, including mouse delivery, natural-shake calibration, and update-time login restoration.
- Detector cases cover horizontal, vertical, diagonal, dense-sample and negative-coordinate shakes; straight movement, small jitter, slow movement, large sweeps, dragging, history expiry, invalid samples, sensitivity, and cooldown.
- Preferences cover defaults, persistence, reset, invalid stored values, and bounds. Registry tests cover independent module activation and stop without changing saved enable state.
- Feature tests use injected mouse-monitor, renderer, and clock implementations. They cover actual feature orchestration: shake activation, immediate disable cleanup, idempotent start, temporary preview monitoring, idle expiry, movement extension, click dismissal, monitor failure and retry, session/sleep ordering, and display-change cleanup.
- Offscreen AppKit bitmap tests confirm a transparent spotlight center, 60% backdrop opacity, and a spotlight crossing a screen edge.
- `./script/build_and_run.sh --verify`: bundled app builds, is locally Developer ID signed, and launches successfully. This is process proof only.
- `codesign --verify --strict --verbose=2 dist/Orbit.app`: local signature validates. Bundle metadata and shell-script syntax checks pass.

## Native UI inspected

- First launch opened the utilities Overview with Find My Mouse off.
- Sidebar navigation exposed the enable toggle, three sensitivity choices, radius and dimming sliders, preview, and reset.
- Enabling reported “Ready for a shake”; disabling returned the feature to off without requesting keyboard access.
- Dark appearance layout was visually inspected.
- The Settings toolbar action opened Orbit Settings. Launch at login was off; Service Management reported “not found” for the local development bundle, and the UI displayed Applications-folder guidance.
- Preview was invoked from the native UI. The automation's window capture excludes separate overlay windows, so that capture does not verify the composited desktop spotlight.

## Hands-on checks outstanding

These are not claimed as passed:

- Sensitivity calibration across mice and trackpads. The user confirmed that Find My Mouse worked as expected after enabling it; the specific input device and display configuration were not recorded.
- Visual spotlight tracking and click-through delivery to another app on the actual desktop.
- Multi-display dimming with mixed scale factors, negative display origins, and display hot-plugging.
- Spaces, full-screen apps, Stage Manager, and protected system surfaces.
- Apple's shake-to-enlarge cursor enabled alongside Orbit.
- Reduce Motion and Reduce Transparency with the actual system settings enabled.
- Quiet subsequent launches and menu bar reopening after the final reopen-handling change. The app process launches successfully; the UI automation cannot select its windowless state.
- Actual sleep/wake and fast user switching (notification ordering is covered with injected tests).
- Automatic launch during an actual new login session. Registration of the installed app is verified below.
- Measured idle CPU/energy. Source and lifecycle tests verify no repeating idle timer when the spotlight is hidden, no continuous redraw loop, and monitor removal when disabled; no Instruments energy profile has been captured.

## Quick acceptance walkthrough

1. Run Orbit, open Find My Mouse, enable it, and jiggle the pointer within a small area. Check that normal movement and dragging do not activate it.
2. Confirm that all displays dim, the clear spotlight follows the pointer, clicks reach the underlying app, and one second of stillness dismisses it.
3. Try sensitivity and appearance controls; disable during an active spotlight and confirm immediate removal. Preview while disabled, then verify that shakes remain inactive afterward.
4. Quit and reopen Orbit. Confirm settings persist, the window remains closed on later launches, and the menu bar can reopen it. Test login behavior only after installing the bundle in Applications.

## macOS design update

- The 20 existing regression tests pass after the visual redesign. Shake detection and the desktop overlay implementation were not changed.
- Inspected the live unified toolbar, native sidebar, overview card, Find My Mouse settings, and native General / About settings tabs.
- Inspected dark and light appearance in the running app using its app-only appearance control; restored System afterward. No system appearance preference was changed.
- Exercised radius increment/decrement in the live app: the value and illustrative preview's accessibility description updated from 100 to 105 points and back to 100.
- Verified Find My Mouse remained enabled and reported “Ready for a shake” throughout the UI checks. Launch at login remained off.
- Code uses availability guards for newer glass, concentric shapes, and scroll-edge APIs. Visual fallback on physical macOS 14/15 hardware, system glass intensity settings, increased contrast, Show Borders, and keyboard traversal still need hands-on checks.
- Codex Run now explicitly opens the utilities window with the developer launch argument `--show-utilities`, avoiding the windowless-state automation limitation during development. Normal background-launch behavior is retained.
- Design reference: Apple's [Adopting Liquid Glass](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass) and [Modernize your AppKit app (WWDC26)](https://developer.apple.com/videos/play/wwdc2026/289/).

## Mouse delivery repair and app icon

- The user reported that shaking failed over both Orbit and other apps while Preview Spotlight still worked. This distinguished the failure from the renderer.
- Fixed app-local delivery by enabling `acceptsMouseMovedEvents` on current and subsequently opened app windows while monitoring is installed, restoring their previous values on stop.
- Fixed event sampling to use the event's recorded position and timestamp instead of reading the pointer's newer location and current button state during callback handling. Dragging is derived from the actual event type.
- Added five regression tests for coordinate/time conversion, event-specific drag state, local-window opt-in/restoration, windows opened after enabling, and delayed callback timing. All 25 tests pass.
- **Physical verification:** after launching this repaired build, the user confirmed that spotlight activation works over both Orbit and another app. Local/global movement samples and spotlight activations were also observed in Orbit's own diagnostic log. Broader display/hardware coverage remains outstanding.
- The production icon has two clean vector foreground groups plus the native background in an editable `.icon` document. Default and dark previews were rendered using Apple's `ictool` with design generation 27. Apple's asset compiler successfully produces `Assets.car` and `Orbit.icns` from it.
- Inspected the running app after packaging: the new icon is visible in Overview, Find My Mouse remains enabled, and its page reports “Ready for a shake.” The final bundle passes strict local signature verification. Temporary mouse diagnostics are off in the final launch.

## Applications installation and login registration

- Installed the current bundle in `/Applications/Orbit.app`. Its executable checksum matches the development build, and strict local signature verification passes.
- Opened the installed copy and enabled Launch Orbit at login in General Settings. The switch is on and the actual Service Management status reads “Orbit will open in the menu bar when you log in.” No pending approval was shown.
- Find My Mouse remains enabled. An actual logout/login was not performed.

## Run action installs and preserves login state

- Codex Run still invokes `script/build_and_run.sh`; its default now stages and validates a fresh bundle before stopping Orbit, replaces `/Applications/Orbit.app`, and launches that installed copy. Debug/log/telemetry/verify modes use the installed copy too; build-only is intentionally separate.
- Added an app-local status command for capturing Service Management state before replacement. The updater passes a restore request only for a previously enabled or pending registration; an off setting is not overridden. Login-restoration tests cover lost registration, already enabled/pending states, registration failures, and explicit disable.
- The first migration from the previously installed build retained its enabled registration. The installed status command reported `enabled`, the GUI showed the switch on, and the process path was `/Applications/Orbit.app/Contents/MacOS/Orbit`.
- Temporarily disabled login launch, rebuilt/replaced the app (including a changed app bundle), and verified both the status command and GUI remained off. Restored the enabled setting, rebuilt/replaced again, and the script verified “Launch at login remains enabled.”
- The workflow uses normal ad-hoc signing; it does not relax the designated requirement or bypass macOS approval. A failed launch/login verification reports a failure and retains the previous installed bundle for recovery. This is registration/update proof, not a performed logout/login test.
- Verified build-only with fail-fast comparisons: the installed executable checksum, running process ID, and enabled login registration were unchanged. The installed bundle still passes strict signature verification. All 28 tests pass, including the three new login-service tests; shell syntax checks pass.

## Natural-shake calibration

- Investigated a repeated report of jiggle activation failing. The installed app was enabled, reported “Ready for a shake,” and diagnostics confirmed both local and global movement delivery.
- The original detector rejected any 750 ms history spanning more than 220 points. Earlier physical diagnostics contained 300–500-point areas with repeated rapid reversals. Added regressions reproduced rejection of 300-, 400-, and 500-point shakes, plus a compact shake immediately following long desktop travel; both tests failed against the old code.
- Widened the compact-area limit to 520 points and retained only the newest contiguous movement within that area. The speed window, travel ratio, minimum travel, reversal count, jitter rejection, drag rejection, and cooldown remain enforced.
- Added an oversized continuous-sweep regression to ensure trimming history cannot turn large screen-crossing oscillations into a compact shake. Expanded natural-shake coverage with dense motion samples. All 31 tests pass after the change.
- The user subsequently clarified that Orbit was working and that the reported problem was an expectation mismatch, with no further fix needed. The calibration update had already been installed before that clarification; it is not claimed as a confirmed root-cause repair. Temporary movement diagnostics were then disabled. The earlier mouse-event delivery repair was separately confirmed by the user.


## Right-Click Menu implementation (2026-10-31)

- Added an independent, initially disabled module, Overview card, sidebar page, menu bar toggle, and permission-free preview with Copy/Paste modes.
- Automated checks: 39 tests passed, including eight new menu-model and permission/lifecycle cases; existing Find My Mouse and login-item checks remain passing.
- Built, signed using the existing local Developer ID certificate, installed and launched `/Applications/Orbit.app`. The updater reported launch at login still enabled. Find My Mouse stayed enabled.
- Inspected the settings page and inline action/tag layout through Accessibility and screenshots. Floating-menu lifecycle logging confirmed opening and Escape dismissal. The computer-use window capture did not include the separate floating menu surface, so its live appearance is not claimed as visually verified.
- Finder’s native menu was inspected on disposable `/private/tmp/orbit-menu.AOksEk/Sample.txt`; it exposes identifiers for standard commands, native tag radio controls, and application/plugin submenus. Confirmed Finder’s native Paste (`paste:`), move-Paste (`cmdMoveItemsHere:`), and exact-Paste (`cmdPasteExactly:`) identifiers using the disposable fixture. No real user files were changed.
- Pending user-granted Accessibility access: end-to-end right-click replacement, native command replay, native color tagging, Finder Cut/move-Paste and repeated clipboard changes, generic text-app menus, lazy submenu actions, changed-window handling, multi-display positioning, VoiceOver/keyboard navigation of custom header, and physical Control-click/trackpad behavior. Until these checks pass, treat this utility as experimental and retain Show macOS Menu as the fallback. Unsupported menus are left untouched.
- Signing is local only; this build has not been notarized or prepared for public distribution.

### Accessibility-enabled testing follow-up

- User enabled Accessibility access and Right-Click Menu. The installed app displays “Ready in supported apps”; rebuilding with the same signing identity preserved access and launch at login.
- Runtime diagnostics confirmed successful AX menu-observer registration (AXError.success).
- Automated right-clicks on the disposable Sample.txt opened Finder’s original menu, but did not produce any global NSEvent mouse-monitor callbacks, even with logging before app/context filtering. This automation path therefore has not exercised Orbit’s physical-click activation path. A physical secondary-click check was requested before drawing a compatibility conclusion.
- Live command replay, tagging, Cut/Paste, and generic text-app checks are still unverified. No test-file command was executed and no user file was changed during this follow-up.

- Physical-click confirmation: user reported Orbit’s action tiles appearing after a brief native Finder-menu flash. Runtime logs corroborate a secondary click, successful native-menu capture/cancellation, and Orbit menu opening. This verifies the physical activation path. The captured Finder menu contained 21 commands and no exposed color tags in that context; this does not verify file-tag actions. Copy/Paste, Rename, Share, Trash, fallback replay, and other-app actions remain unverified.

### Action-control follow-up

- After the reported Copy click, Finder’s clipboard inspector showed text rather than the test file. Nothing was pasted. No successful native Copy replay was recorded, so Copy forwarding is not verified.
- Replaced the floating menu’s NSHostingView/SwiftUI buttons with native NSButton controls that accept first mouse while Orbit is a background agent. The settings-page illustration remains SwiftUI. Added safe action-selection/forwarding diagnostics and removed verbose per-click logging.
- All 42 tests passed, including native header callback routing, unavailable-action behavior, Paste replacing Copy, and native-tag callback mapping. Physical click dispatch and native replay still require a repeat Copy check on the installed build; these unit tests do not establish end-to-end success.

### Native replay follow-up

- The physical retry recorded `Action tile selected: copy` and `Forwarding native menu action`, confirming the native header dispatch fix. Finder’s clipboard still contained text; no paste was attempted, and no successful native-menu reopening or command invocation was recorded. This narrows the remaining failure to forwarding/context validation or native-menu reopening.
- Replay now attempts AXShowMenu on the original hit element or supporting ancestors. Its targeted-event fallback copies the original mouse event, retaining window/process routing fields, and separates down/up delivery. Missing replay completion produces a visible error message rather than silently ending.
- All 44 tests passed. New regression cases verify preserved window/process fields, click state, negative display coordinates, source-event immutability, and Control-click/Option modifiers. End-to-end Copy remains pending a physical retry; these results do not establish that Finder replay succeeds.

### Replay timing diagnosis

- The next physical Copy attempt reopened Finder’s native menu at approximately 1.52 seconds after forwarding began. The replay deadline was 1.5 seconds, so the handler discarded the callback before invoking Copy. The expired-response branch did not previously surface an error.
- Extended the bounded replay window to four seconds, set an explicit Accessibility messaging timeout during forwarding, report late responses, and cancel replay on a new unmarked physical mouse click. Error messages now appear next to utility status instead of below the long preview.
- All 44 tests passed after the forwarding changes. Installed the updated bundle with login registration preserved. Physical Copy/Paste confirmation remains pending; no end-to-end success is claimed yet.

### Confirmed physical Copy and native Paste

- On the latest installed build, the physical Copy click logged action selection, native menu reopening, and `Native menu action invoked` approximately 0.11 seconds after forwarding began.
- Finder’s Show Clipboard displayed `Sample.txt` with clipboard contents `text / items`.
- Opened the empty disposable Destination folder through Finder and used native Command-V. Finder displayed Destination/Sample.txt (33 bytes).
- `cmp` confirmed the pasted file matches the source byte-for-byte; both original and destination files remain present. This verifies Orbit’s physical Copy tile → Finder native Copy → clipboard → native Finder Paste path.
- The Orbit Paste tile, Cut/move-Paste, Rename, Share, Trash, color-tag execution, Show macOS Menu replay, and other-app command execution are still separate unverified integration checks. The native-menu flash remains expected for the capture-and-replace approach.

### Orbit Paste and color-tag follow-up

- Physical Orbit Paste was selected on the empty PasteTest folder. Logs recorded native Paste invocation; PasteTest/Sample.txt exists and matches Destination/Sample.txt byte-for-byte. This separately verifies Orbit’s Paste tile, not just Command-V.
- Physical Blue click reopened Finder’s original menu but left the test file untagged. Orbit reported that the command changed; the native tag target was not successfully invoked.
- Updated color replay to recapture Finder’s current tag controls and resolve the chosen color from that fresh snapshot. Added bounded retries for custom-control layout, support for native Pick actions, and identifier matching that tolerates changing labels on unique native IDs while requiring titles for shared plugin IDs.
- All 47 tests passed, including route matching for changing native labels, reused plugin IDs, and refusal to substitute missing named controls. Physical Blue add/remove verification is still pending on this build.

### Native Blue tag confirmed

- The first color retry reported controls unavailable. A subsequent physical Blue action in the same build logged `Native color tag invocation result 0` at 17:28:16.
- The file now stores native `_kMDItemUserTags` value `Blue\n4`, verified by decoding `xattr -px` output as a binary plist. Finder also exposes a tag badge for the file. This confirms Blue addition, with an intermittent lookup failure still observed.
- Simplified live tag lookup to find Finder’s `cmdSetLabel:` widget and its current radio controls directly, avoiding unstable intermediate AX wrappers. All 47 tests passed after this change. Tag removal and remaining utility actions still need device verification.

### Blue removal failure and traversal correction

- User reported Blue removal failed. Metadata still contains `Blue\n4`; native Finder’s menu shows Remove Blue selected (AXValue 1). Runtime probes found zero live controls with the direct-widget lookup.
- Removed the assumption that cmdSetLabel is a direct child of the menu. The lookup now traverses the bounded native menu subtree and accepts only a complete, unambiguous eight-radio group (Clear plus seven colors). It refuses incomplete/ambiguous results.
- All 47 tests passed after the traversal change. Blue removal remains unverified pending another physical invocation. Rename and subsequent action checks have not yet run.

### Blue removal confirmed

- Physical Blue removal with full-tree lookup found all eight native color controls and logged a successful native color action at 17:34:51.
- `_kMDItemUserTags` on PasteTest/Sample.txt is now an empty array, confirming removal of the previously verified `Blue\n4` entry.
- Blue add and removal have both been observed end to end. Other individual colors, clear-all color control, multi-selection, and custom-tag preservation remain unverified integration scenarios.

### Rename confirmed

- User selected Orbit’s Rename tile; Finder displayed its native inline filename editor for PasteTest/Sample.txt.
- Completed the editor through computer-use input with `Orbit Renamed.txt`. Finder displayed the new filename and URL.
- Filesystem verification confirmed the renamed file exists, Sample.txt is absent from PasteTest, and contents still match the 33-byte test source exactly.

### Share follow-up

- User’s Orbit Share attempt selected the tile and reopened a native menu, but no successful native invocation was recorded. Share through Orbit is not verified.
- Finder’s native toolbar Share button opened ShareSheet.Popover for the 33-byte disposable file. Inspected the chooser and cancelled with Escape; no destination was selected and nothing was sent.
- Generalized replay readiness handling: unresolved or disabled commands get bounded layout retries, and other native menu notifications can still supply the correct target. Claim replay before pressing to prevent duplicate operations. Native action selection also supports an explicitly advertised ShowMenu action when Press/Pick are absent.
- All 47 tests passed. Installed the update while preserving login registration. Orbit Share requires a physical retry; native-toolbar success does not establish Orbit Share success.

### Orbit Share confirmed

- User confirmed the Share chooser opened after Orbit Share. Runtime logs recorded successful native command invocation on two consecutive physical Share selections (17:39:45 and 17:39:59).
- The chooser had dismissed by the time Finder was inspected after returning to chat. No share destination was selected by the agent; opening/cancelling the native chooser is verified, actual sending is deliberately untested.

### Cut readiness regression

- Physical Cut selected the tile, but the early native menu candidate exhausted layout retries before the later menu notification arrived. Source remains present and byte-identical; move destination remains empty. Cut preparation was not verified in that attempt.
- Corrected candidate-probe exhaustion to keep the overall replay pending for a later valid menu until its existing four-second deadline. Applied to commands and colors; extended bounded fallback probes across that deadline. Effect invocation still claims replay once before execution.
- Added controlled-time regression tests based on the observed ~0.4s early exhaustion and ~1.85s later menu. All 49 tests passed. Installed update with login registration preserved; Cut/move-Paste still require live retry.

### Cut copied instead of moving

- Physical Cut/Orbit Paste completed native invocations, but both PasteTest/Orbit Renamed.txt and MoveDestination/Orbit Renamed.txt remained present. Destination content matches the source; this is a copy, not a verified Cut/move.
- Replaced the private pasteboard marker with in-memory Cut intent bound to the exact file list and clipboard generation. The reader supports NSURL objects, file-URL items, and legacy filename lists without changing clipboard ownership. Disabling/restarting Orbit clears the move intent. Added explicit preparation and move-intent diagnostics.
- Isolated-pasteboard tests verify modern and legacy reads without altering clipboard generation and rejection of plain text paths. Core tests verify generation/file-set matching and clearing intent. All 53 tests passed.
- Created empty MoveRetry and reopened PasteTest for another physical Cut/move-Paste verification. Previous copies remain for inspection; no real user files were altered.

### Cut intent confirmed; move reopening corrected

- Latest physical Cut logged preparation success with one file. Paste logged move intent true with the same file list, confirming in-memory clipboard tracking. Source remains intact and MoveRetry remains empty after the failed Paste.
- Move-Paste alone bypassed AXShowMenu and relied on targeted CGEvents to reopen with Option; that path produced no menu and timed out. Removed the bypass: use normal AX reopening, then resolve Finder’s already exposed cmdMoveItemsHere alternate through Accessibility.
- The native move command still requires physical verification. No copy fallback is used when a move command is unavailable.

### Cut and native move-Paste confirmed

- Physical Cut logged preparation success with one file. Orbit Paste recognized move intent and successfully invoked Finder’s native move command.
- PasteTest/Orbit Renamed.txt is absent; MoveRetry/Orbit Renamed.txt exists and is byte-identical to the original 33-byte source. This establishes an actual move rather than a copy.
- Created a separate, uniquely named disposable Trash test file in MoveRetry to preserve the verified moved file while testing Delete.

### Delete-to-Trash confirmed

- Physical Orbit Delete successfully invoked Finder’s native command. Orbit Trash Test 01a1931c.txt is absent from MoveRetry and present in the user’s Trash.
- The Trash entry has the same inode (452547890) as the uniquely named test fixture. Content reading inside Trash was restricted, but its name/location and inode establish that this is the same file moved to Trash.
- MoveRetry/Orbit Renamed.txt remains intact and byte-identical to the original source. No Trash was emptied and nothing was permanently deleted.

### Native fallback and lower command list confirmed

- User confirmed Show macOS Menu reopened Finder’s original contextual menu.
- User then chose Get Info from Orbit’s lower command list. Inspected Finder’s Orbit Renamed.txt Info window: correct filename, 33-byte size, MoveRetry location, and expected disposable test contents.
- Closed the Info window. All requested primary Finder tiles now have live-path verification (Copy, Paste, Cut/move-Paste, Rename, Share chooser, Delete-to-Trash), plus Blue add/remove, native fallback, and a representative lower-list command. Individual third-party submenu commands and all display/Space configurations are not exhaustively verified.

### Instant-menu installation

- Built and installed the direct-menu architecture as bundle build 5. The updater reported launch at login still enabled; Orbit’s Overview shows both utilities enabled. Right-Click Menu displays Ready in supported apps.
- Runtime log confirmed `Instant menu mouse filter started`. Inspected the updated settings/preview: Open, Open With, Reveal in Finder, and Show macOS Menu replace the old mirrored native list.
- A signed rollback bundle is retained locally at `.build/Orbit-before-instant.app`. No native menu is captured during normal direct-menu construction; NativeMenuAccess now performs attribute reads and supported main-menu edit actions only.
- New architecture physical no-flash behavior, direct native fallback, and new file-action path remain pending a disposable Finder check. Earlier successful live tests are retained as historical evidence for the capture/replay build.


### Instant menu no-flash verification

- User physically right-clicked MoveRetry/Orbit Renamed.txt and confirmed Orbit appeared directly with no native-menu flash. The user also confirmed Blue tagging and explicit native fallback worked.
- Runtime logs corroborated direct Orbit menu display without opening a native menu and a subsequent explicit native fallback request.
- File metadata contains native Blue tag `Blue\n4`, independently verifying the new NSURL-based tagging path.
- The requested no-flash Finder path is verified on the installed build. Latest suite remains 64 passing tests; no code changed after that run. Other direct actions retain their automated coverage and the earlier capture/replay live evidence is historical rather than a claim of complete live regression coverage for this architecture.


## Instant-menu action regression with computer use

Used `/private/tmp/orbit-instant-regression.m8eosncs` and a uniquely named 93-byte fixture. CUA's app-targeted right-clicks bypass the system event filter, so a DEBUG-only, folder-restricted window supplied explicit file/folder contexts to the **production ContextMenuPresentation, MenuActionHeader, and RightClickUtility handlers**. Anchoring the actual NSMenu to that window exposed its real controls to CUA. This was not the non-mutating Preview menu, and file operations were not invoked by test-only command substitutes. The Finder hit-test/input-filter path had already been physically verified separately.

| Action | Result and independent evidence |
| --- | --- |
| Copy and Paste | Invoked Copy and Paste through Orbit's actual menu; Source/Instant Test.txt remained and CopyDestination/Instant Test.txt matched byte-for-byte. |
| Cut and move-Paste | Invoked Cut from the menu and Paste into MoveDestination; original Source path disappeared and destination matched the independent copy. |
| Rename | Used Orbit's actual Rename dialog; entered Orbit Instant Retest 01a1931c.txt. New path existed, old filename was absent, and contents were unchanged. |
| Share | Orbit opened ShareSheet.Popover for Orbit Instant Retest 01a1931c, showing Text Document / 93 bytes. Cancelled with Escape without selecting a destination. |
| Delete | Clicked Orbit's Delete tile. Source disappeared and the uniquely named Trash entry existed with matching inode 452579123. Independent copied fixture remained intact. Trash was not emptied. |

All six requested direct-action paths passed. No unrelated user files were edited. The test artifact remains recoverable in Trash and the independent copy remains in the temporary test folder. The normal app was relaunched without the test flag afterward; launch at login and enabled utilities were preserved.

The temporary-folder UI is available only in DEBUG builds via `--context-test-root`; it accepts canonical roots named `orbit-instant-regression.*` directly under the system /tmp directory and rejects targets escaping that root. A regression test covers that guard. Latest full suite: **65 passed**, no compiler warnings. No user-facing instant-menu behavior was changed for the test surface; production calls continue using an unanchored menu and normal context resolution.


## Direct Finder and TextEdit regression follow-up

- CUA element and coordinate right-clicks in Finder opened its native menu; CUA right-click in TextEdit also opened its native menu. These automated events do not establish Orbit interception coverage. Normal Orbit is enabled; no test-window context is used in this follow-up.
- User physically selected Orbit Copy and Orbit Paste in TextEdit and reported the fixture sentence duplicated. CUA independently inspected TextEdit and confirmed two identical lines of `Orbit direct TextEdit regression fixture.`. Direct TextEdit Copy/Paste passes with user-operated menu selection and independent UI inspection.
- User physically selected Orbit Cut in TextEdit, confirmed both selected lines disappeared, then selected Orbit Paste and confirmed both returned. CUA independently confirmed the two restored fixture lines. Direct TextEdit Cut/Paste passes with user-operated menu selection and independent UI inspection.
- Direct Finder actions remain pending in this follow-up.

- Direct Finder follow-up: user reported the destination paste used a normal text-style native menu rather than Orbit tiles. The copied fixture matches the original and the source is preserved, but this does not establish an Orbit Paste pass. Investigating Finder background context fallback before continuing.

### Finder background URL fallback

- Physical click diagnostic: `list=true, documentURL=false`, with AXOutline/AXScrollArea/AXSplitGroup/AXWindow ancestors. Finder omitted AXDocument for this ordinary folder window.
- Added a bounded path-bar-only folder lookup when AXDocument is absent. Requires a unique existing directory URL matching the window title; selected descendant folders, ambiguous repeated names, files, and missing titles cannot become inferred destinations. No native context menu is opened.
- Added two focused regressions for selected-child destination confusion, missing/ambiguous folder matches, and non-directory rejection. Full suite: 67 passed. Installed update with launch at login preserved; physical Finder background retry is pending.

- User physically retried Finder blank-area right-click after the path-bar fallback update and confirmed Orbit's large-button menu now appears. Background menu activation fix is physically verified. Direct Orbit file-action regression continues separately.

- Direct Finder Copy/Paste verified: user selected both actions from Orbit large-button menus, then filesystem inspection confirmed Source/Finder Test.txt remains and PasteRetry/Finder Test.txt matches its 40 bytes exactly.

- Direct Finder Cut/move-Paste verified: user selected Orbit Cut in PasteRetry and Orbit Paste in MoveDestination. PasteRetry source is absent; MoveDestination/Finder Test.txt exists and matches the intact 40-byte original in Source.

### Persistent six-action top row

- User clarified that Cut, Copy, Paste, Rename, Share, and Delete should always stay in the large-button row. Replaced the earlier Paste-replaces-Cut/Copy presentation rule with a stable six-tile order. Unavailable actions remain visible and disabled; promoted actions are omitted from the lower list.
- Increased live AppKit and SwiftUI preview width from 380 to 452 points to retain tile sizes. Updated the preview Paste-availability toggle and help/README.
- Updated model and native-button regression tests for stable ordering, disabled actions, and all six action callbacks. Full suite: 67 passed, no warnings. Installed in Applications with launch at login preserved; CUA verified all six preview actions remain visible with Paste both unavailable and available.

- Direct Finder Rename verified on the six-tile build: user invoked Orbit Rename on MoveDestination/Finder Test.txt; CUA entered Orbit Finder Retest 01a1931c.txt in the real Orbit dialog and confirmed. Old path is absent, new path exists, contents match the original.

- Direct Finder Share verified on the six-tile build: after user selected Orbit Share on the renamed fixture, CUA inspected ShareSheet.Popover showing Orbit Finder Retest 01a1931c, Text Document, 40 bytes. CUA cancelled with Escape; no destination was selected and nothing was sent.

- Direct Finder Delete verified on the six-tile build: user selected Orbit Delete on the disposable renamed fixture. MoveDestination source is absent; the uniquely named Trash entry exists with the same recorded inode 452667265. The original Source fixture and independent CopyDestination copy remain intact and byte-identical. No Trash was emptied.

Direct-app regression is complete: Finder Copy/Paste, Cut/move-Paste, Rename, Share chooser, and Delete-to-Trash passed via physical user selection of Orbit commands with independent CUA/filesystem verification. TextEdit Copy/Paste and Cut/Paste passed via physical user selection with CUA verification of restored text. Rename/Share/Delete are file actions and remain disabled for focused text contexts in this architecture. The Finder missing-AXDocument fallback and persistent six-action top row were installed during this follow-up; latest full automated suite remains 67 passing tests.

### Test cleanup

- At user request, moved the three disposable test roots (orbit-menu.AOksEk, orbit-instant-regression.m8eosncs, orbit-direct-regression.izqplt89) and temporary test logs/probes/helpers to recoverable Trash. Saved the unsaved TextEdit fixture into the test root before closing it and trashing that folder; no irreversible Delete prompt was used.
- Closed the Finder test window and Orbit utilities window. Left the unrelated Finder AirDrop window alone. Orbit remains running from Applications. Trash was not emptied; source and validation documentation remain in the workspace.

### Action tile vertical spacing

- Replaced the live action buttons' automatic NSButtonCell imageAbove interior layout with a centered icon-and-label group: 22-point icon slot, 7-point gap, measured label height, and equal remaining top/bottom padding. Tag buttons keep their existing rendering. Native NSButton tracking, target/action wiring, enabled state, accessibility labels, and menu dispatch remain in place.
- Matched the SwiftUI preview icon slot to the live menu. All three focused MenuActionHeaderTests pass, covering six action callbacks, unavailable actions, and color-tag callbacks. Built and installed in Applications with launch at login preserved.
