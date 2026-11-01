# Releasing Orbit

## Use the Codex Release action

Select **Release** from the project's Codex actions menu. Its committed definition in `.codex/environments/environment.toml` runs `python3 script/release.py` from the checkout. The existing **Run** action still builds and opens the development app.

The action travels with this Git repository. On another Codex desktop installation, open the Orbit checkout as the project; if actions have not refreshed, reopen the project or open its local environment settings. Agents without that UI can use exactly the same command. See the root [AGENTS.md](../AGENTS.md) and [README](../README.md).

**Release publishes publicly when its checks pass.** Before clicking it, increment the marketing version AND numeric build in `Resources/Info.plist`, add `docs/releases/<version>.md`, and commit/push the intended work to `main`. The script stops for dirty/unpushed source, stale versions, existing tags/output, missing notes, or verification failures. It does not invent release notes or silently commit work.

## Configure each signing Mac once

Building and signing a Mac app requires macOS and Xcode (including Icon Composer/asset compiler support for `Resources/Orbit.icon`), Python 3, and the GitHub CLI authenticated for `jvaudio/Orbit`. A Windows/Linux Codex machine can read these instructions but cannot perform this macOS signing process locally; use a configured Mac.

Provision these through secure local setup, never through Git or chat:

1. The existing Developer ID Application certificate **and its private key**, for team `SF9QX9G45C`, in Keychain. Use the same signing team to preserve app trust and Accessibility approvals.
2. A working Apple `notarytool` Keychain profile for that team. Its name is a local label and may differ between Macs. Create it interactively with `xcrun notarytool store-credentials orbit-notary`; enter credentials only in the local prompt. An existing valid profile can be reused.
3. Orbit's **existing** Sparkle private signing key, in Keychain account `com.jerryvoelker.Orbit`, transferred through an approved secure backup/migration process. It must match `SUPublicEDKey` in `Resources/Info.plist`. Creating a new unrelated key would prevent installed Orbit copies from trusting updates. This repository contains only the public key.

Copy the example config:

```sh
cp .orbit-release.example.json .orbit-release.json
```

Edit `notary_profile` to match that Mac's Keychain profile. Optional `code_sign_identity` selects the Developer ID certificate; otherwise the packager discovers one. `sparkle_account` defaults to Orbit's dedicated Keychain account. The local JSON is Git-ignored and accepts only these three non-secret labels. `ORBIT_NOTARY_PROFILE`, `ORBIT_SPARKLE_ACCOUNT`, and `ORBIT_CODE_SIGN_IDENTITY` environment values override the JSON.

```sh
python3 script/release.py --check-config
```

This checks config shape and required labels without building, signing, tagging, or publishing. It does not prove credentials are usable; Keychain access, actual signatures, notarization, and GitHub permissions are verified by the release process. macOS may ask the operator to approve signing-tool access to Keychain.

Each separate checkout/worktree needs its own ignored JSON, or environment variables. The shared Codex action itself contains no absolute paths or machine-specific signing profile.

## What Release does

The release command runs tests, builds/signs/notarizes a universal app, signs its update feed, and validates the archive before extracting it. It creates the version tag and uploads the app ZIP, `SHA256SUMS.txt`, and `appcast.xml` into a draft. It downloads and independently verifies the draft before publishing as Latest, then verifies anonymous public downloads and the stable updater feed. Private keys stay in Keychain. The running installed app is left untouched.

## If a release stops

Read the reported failure and keep the release unpublished until it is resolved. Existing output is retained for inspection; move stale output aside before rebuilding. A created tag is not automatically deleted or moved. A failed draft can be inspected with GitHub's UI/CLI, and audited once published using `python3 script/release.py --verify v<version>`. The automated command deliberately refuses to overwrite tags or public releases; resolve a partial release explicitly rather than forcing a retry over it. Never mark a draft Latest unless its exact three assets have passed all checks.

The GitHub published-release guard is an additional asynchronous check, not a substitute for using this command. Its manual verification mode is read-only. No new app release is needed just to change the Codex action or these instructions.
