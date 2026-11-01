# Orbit agent instructions

Orbit is a native SwiftPM macOS menu bar app. See README.md for the architecture and development commands.

## Build and run

Use `./script/build_and_run.sh` (Codex **Run**) to build, replace, and launch `/Applications/Orbit.app` while preserving launch at login. `--build-only` leaves the installed app untouched. Public builds include Sparkle; development builds keep automatic updates disabled.

## Releases

When the user requests a release, use Codex **Release** or `python3 script/release.py` from the repository root. The shared Codex action is in `.codex/environments/environment.toml`. Full setup and recovery instructions are in [docs/RELEASING.md](docs/RELEASING.md).

- Before releasing, increment BOTH version fields in `Resources/Info.plist`, write `docs/releases/<version>.md`, and commit/push the intended changes to `main`. Preserve unrelated work.
- New signing Macs need the existing Apple Developer ID identity/private key, Apple notarization credentials, and Orbit's existing Sparkle signing key in Keychain. Never generate a replacement update key for an existing release channel merely to fix a missing key.
- Non-secret per-Mac labels can live in ignored `.orbit-release.json`; start from `.orbit-release.example.json`. Environment variables take precedence. Never put passwords, tokens, certificates, or private keys into this JSON or Git.
- Use the release command rather than publishing a GitHub release manually: it verifies and uploads the signed/notarized universal app ZIP, checksum, and signed appcast together before publishing as Latest.
- If checks fail, resolve or report the failure. Do not bypass tests/signature verification, reuse stale output, move existing tags, overwrite public assets, or publish a Latest release without its signed feed.
- A read-only audit is `python3 script/release.py --verify v<version>`. Release automation tests are `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Tests/ReleaseAutomationTests -v`.

Adding an action or editing release tooling does not itself call for publishing a new app version.
