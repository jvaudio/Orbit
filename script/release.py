#!/usr/bin/env python3
"""Build/publish a release, or independently verify a published release. No private keys leave Keychain."""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parent.parent
REPO = "jvaudio/Orbit"
TEAM = "SF9QX9G45C"
FEED = f"https://github.com/{REPO}/releases/latest/download/appcast.xml"


def run(*args, capture=False):
    result = subprocess.run([str(a) for a in args], cwd=ROOT, check=True,
                            stdout=subprocess.PIPE if capture else None, text=True)
    return result.stdout.strip() if capture else None


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def load_release_config():
    """Load non-secret per-checkout labels; explicit environment values win."""
    path = ROOT / ".orbit-release.json"
    if path.exists():
        try:
            settings = json.loads(path.read_text())
        except (ValueError, OSError) as error:
            raise RuntimeError(f"Cannot read {path.name}: {error}") from error
        allowed = {"notary_profile": "ORBIT_NOTARY_PROFILE",
                   "sparkle_account": "ORBIT_SPARKLE_ACCOUNT",
                   "code_sign_identity": "ORBIT_CODE_SIGN_IDENTITY"}
        require(isinstance(settings, dict) and set(settings) <= set(allowed),
                "Release config accepts only notary_profile, sparkle_account, and code_sign_identity; never store credentials here")
        for key, value in settings.items():
            require(isinstance(value, str) and bool(value.strip()), f"Invalid release config value: {key}")
            os.environ.setdefault(allowed[key], value)
    require(bool(os.environ.get("ORBIT_NOTARY_PROFILE")),
            "Configure this Mac first: copy .orbit-release.example.json to .orbit-release.json and set its Keychain profile name. See docs/RELEASING.md.")


def api(path):
    return json.loads(run("gh", "api", path, capture=True))


def version_tuple(value):
    require(re.fullmatch(r"\d+\.\d+\.\d+", value), "Version must be major.minor.patch")
    return tuple(int(part) for part in value.split("."))


def names(version):
    return [f"Orbit-{version}-macOS-universal.zip", "SHA256SUMS.txt", "appcast.xml"]


def source_info(tag):
    response = api(f"repos/{REPO}/contents/Resources/Info.plist?ref={tag}")
    return plistlib.loads(base64.b64decode(response["content"]))


def download(url, target):
    run("curl", "--fail", "--location", "--silent", "--show-error", "--retry", "3",
        "--output", target, url)


def verify_files(directory, info):
    version = info["CFBundleShortVersionString"]
    archive_name, checksum_name, feed_name = names(version)
    for name in names(version):
        require((directory / name).is_file(), f"Missing required asset: {name}")
    checksum = (directory / checksum_name).read_text().strip()
    match = re.fullmatch(r"([0-9a-f]{64})  " + re.escape(archive_name), checksum)
    require(match is not None, "Checksum must name exactly the release archive")
    digest = hashlib.sha256((directory / archive_name).read_bytes()).hexdigest()
    require(digest == match[1], "Archive checksum mismatch")
    with tempfile.TemporaryDirectory(prefix="orbit-release-verify-") as work:
        work = Path(work)
        expected = work / "Expected.plist"
        expected.write_bytes(plistlib.dumps(info))
        # Verify the feed and archive BEFORE extracting executable code.
        run("swift", ROOT / "script/verify_appcast.swift", expected,
            directory / feed_name, directory / archive_name)
        extracted = work / "extracted"
        run("ditto", "-x", "-k", directory / archive_name, extracted)
        require({p.name for p in extracted.iterdir()} <= {"Orbit.app", "__MACOSX"},
                "Archive contains unexpected top-level files")
        app = extracted / "Orbit.app"
        actual = plistlib.loads((app / "Contents/Info.plist").read_bytes())
        require(actual == info, "Packaged Info.plist differs from tagged source")
        require(actual.get("SUFeedURL") == FEED and actual.get("SURequireSignedFeed") is True
                and actual.get("SUVerifyUpdateBeforeExtraction") is True,
                "Update trust configuration is missing or incorrect")
        run("codesign", "--verify", "--deep", "--strict", app)
        signature = subprocess.run(["codesign", "-dv", "--verbose=4", str(app)],
                                   capture_output=True, text=True, check=True).stderr
        require(f"TeamIdentifier={TEAM}" in signature and "(runtime)" in signature,
                "Expected signing team and hardened runtime required")
        run("xcrun", "stapler", "validate", app)
        run("spctl", "--assess", "--type", "execute", "--verbose=2", app)
        architectures = run("lipo", "-archs", app / "Contents/MacOS/Orbit", capture=True).split()
        require(set(architectures) == {"arm64", "x86_64"}, "App must be universal")
    print(f"Verified {version}: signed/notarized universal app, checksum, and signed feed.")


def verify_remote(tag, *, draft=False, latest=False):
    info = source_info(tag)
    require(tag == "v" + info["CFBundleShortVersionString"], "Tag/source version mismatch")
    release = api(f"repos/{REPO}/releases/tags/{tag}")
    required = names(info["CFBundleShortVersionString"])
    assets = {a["name"]: a for a in release["assets"]}
    require(all(n in assets and assets[n]["size"] > 0 for n in required),
            "Release is missing a required nonempty app, checksum, or feed asset")
    with tempfile.TemporaryDirectory(prefix="orbit-release-download-") as work:
        work = Path(work)
        if draft:
            run("gh", "release", "download", tag, "--repo", REPO, "--dir", work,
                *[part for n in required for part in ("--pattern", n)])
        else:
            require(not release["draft"], "Release is still a draft")
            for name in required:
                download(assets[name]["browser_download_url"], work / name)
        verify_files(work, info)
        if latest:
            stable = work / "latest.xml"
            download(FEED, stable)
            require(stable.read_bytes() == (work / "appcast.xml").read_bytes(),
                    "Stable latest-feed URL does not match this release")


def publish():
    require(not run("git", "status", "--porcelain", capture=True), "Commit all changes before releasing")
    require(run("git", "branch", "--show-current", capture=True) == "main", "Release from main")
    head = run("git", "rev-parse", "HEAD", capture=True)
    remote = run("git", "ls-remote", "origin", "refs/heads/main", capture=True).split()[0]
    require(head == remote, "Push main and ensure it matches origin before releasing")
    info = plistlib.loads((ROOT / "Resources/Info.plist").read_bytes())
    version = info["CFBundleShortVersionString"]
    version_tuple(version)
    require(str(info["CFBundleVersion"]).isdigit(), "Build number must be an integer")
    latest = api(f"repos/{REPO}/releases/latest")
    previous = source_info(latest["tag_name"])
    require(version_tuple(version) > version_tuple(previous["CFBundleShortVersionString"])
            and int(info["CFBundleVersion"]) > int(previous["CFBundleVersion"]),
            "Increment BOTH marketing version and build number before releasing")
    tag = f"v{version}"
    require(not run("git", "tag", "--list", tag, capture=True), f"Tag {tag} already exists")
    require(not run("git", "ls-remote", "--tags", "origin", f"refs/tags/{tag}", capture=True),
            f"Remote tag {tag} already exists")
    notes = ROOT / f"docs/releases/{version}.md"
    require(notes.is_file(), f"Missing release notes: {notes}")
    output = ROOT / f"dist/release/{version}"
    require(not output.exists(), f"Output already exists: {output}; move it aside before releasing")
    run(ROOT / "script/package_release.sh")
    verify_files(output, info)
    require(not run("git", "status", "--porcelain", capture=True), "Build changed tracked source; aborting")
    require(run("git", "rev-parse", "HEAD", capture=True) == head, "HEAD changed during build")
    require(run("git", "ls-remote", "origin", "refs/heads/main", capture=True).split()[0] == head,
            "Remote main changed during build; release aborted")
    run("git", "tag", "-a", tag, "-m", f"Orbit {version}")
    run("git", "push", "origin", tag)
    run("gh", "release", "create", tag, "--repo", REPO, "--verify-tag", "--draft",
        "--title", f"Orbit {version}", "--notes-file", notes,
        *[output / n for n in names(version)])
    # Any failure until this point leaves only a draft, never a broken live feed.
    verify_remote(tag, draft=True)
    run("gh", "release", "edit", tag, "--repo", REPO, "--draft=false", "--latest")
    try:
        # GitHub's stable redirect can briefly cache the preceding Latest release.
        for attempt in range(6):
            try:
                verify_remote(tag, latest=True)
                break
            except (RuntimeError, subprocess.CalledProcessError):
                if attempt == 5:
                    raise
                time.sleep(5)
    except Exception:
        run("gh", "release", "edit", tag, "--repo", REPO, "--draft=true")
        raise RuntimeError("Public verification failed; release returned to draft. Inspect before retrying.")
    print(f"Published and verified https://github.com/{REPO}/releases/tag/{tag}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--verify", metavar="TAG", help="Read-only verification of an existing public release")
    modes.add_argument("--check-config", action="store_true", help="Validate non-secret local configuration without building or publishing")
    args = parser.parse_args()
    if args.verify:
        verify_remote(args.verify)
    else:
        load_release_config()
        if args.check_config:
            print("Release configuration loaded. Credential availability is checked during signing; nothing was built or published.")
        else:
            publish()


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, subprocess.CalledProcessError) as error:
        print(f"Release stopped: {error}", file=sys.stderr)
        sys.exit(1)
