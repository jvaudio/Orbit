import importlib.util
from pathlib import Path
import plistlib
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("orbit_release", Path(__file__).resolve().parents[2] / "script/release.py")
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class PublicationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "Resources").mkdir()
        (self.root / "Resources/Info.plist").write_bytes(plistlib.dumps({
            "CFBundleShortVersionString": "0.1.2", "CFBundleVersion": "7"}))
        (self.root / "docs/releases").mkdir(parents=True)
        (self.root / "docs/releases/0.1.2.md").write_text("Release notes")
        self.calls = []
        self.dirty = False
        self.patchers = [
            patch.object(release, "ROOT", self.root),
            patch.object(release, "run", side_effect=self.run_command),
            patch.object(release, "api", return_value={"tag_name": "v0.1.1"}),
            patch.object(release, "source_info", return_value={"CFBundleShortVersionString": "0.1.1", "CFBundleVersion": "6"}),
            patch.object(release, "verify_files"),
            patch.object(release, "verify_remote"),
            patch.object(release.time, "sleep"),
        ]
        for patcher in self.patchers:
            patcher.start()
            self.addCleanup(patcher.stop)

    def run_command(self, *args, **kwargs):
        args = tuple(str(a) for a in args)
        self.calls.append(args)
        if args[:3] == ("git", "status", "--porcelain"):
            return " M file" if self.dirty else ""
        if args[:3] == ("git", "branch", "--show-current"):
            return "main"
        if args[:3] == ("git", "rev-parse", "HEAD"):
            return "abc123"
        if args[:3] == ("git", "ls-remote", "origin"):
            return "abc123\trefs/heads/main"
        return ""

    def testOnlyPublishesAfterDraftIsIndependentlyVerified(self):
        release.verify_remote.side_effect = lambda tag, **kwargs: self.calls.append(("verified-draft" if kwargs.get("draft") else "verified-public",))
        release.publish()
        create = next(c for c in self.calls if c[:3] == ("gh", "release", "create"))
        self.assertIn("--draft", create)
        for name in release.names("0.1.2"):
            self.assertTrue(any(a.endswith("/" + name) for a in create))
        release.verify_remote.assert_any_call("v0.1.2", draft=True)
        release.verify_remote.assert_any_call("v0.1.2", latest=True)
        publish_index = next(i for i, c in enumerate(self.calls) if "--draft=false" in c)
        self.assertLess(self.calls.index(("verified-draft",)), publish_index)
        self.assertGreater(self.calls.index(("verified-public",)), publish_index)

    def testDraftVerificationFailureNeverPublishes(self):
        release.verify_remote.side_effect = RuntimeError("Missing feed")
        with self.assertRaisesRegex(RuntimeError, "Missing feed"):
            release.publish()
        self.assertFalse(any("--draft=false" in c for c in self.calls))

    def testPublicVerificationFailureReturnsReleaseToDraft(self):
        def verify(tag, **kwargs):
            if not kwargs.get("draft"):
                raise RuntimeError("Invalid public signature")
        release.verify_remote.side_effect = verify
        with self.assertRaisesRegex(RuntimeError, "returned to draft"):
            release.publish()
        self.assertEqual(release.verify_remote.call_count, 7)
        self.assertTrue(any("--draft=true" in c for c in self.calls))

    def testDirtySourceStopsBeforePackagingOrGitMutation(self):
        self.dirty = True
        with self.assertRaisesRegex(RuntimeError, "Commit all changes"):
            release.publish()
        self.assertEqual(len(self.calls), 1)

    def testUnchangedVersionStopsBeforePackaging(self):
        (self.root / "Resources/Info.plist").write_bytes(plistlib.dumps({
            "CFBundleShortVersionString": "0.1.1", "CFBundleVersion": "7"}))
        with self.assertRaisesRegex(RuntimeError, "Increment BOTH"):
            release.publish()
        self.assertFalse(any(c[0].endswith("package_release.sh") for c in self.calls))



class AssetTests(unittest.TestCase):
    def testChecksumMismatchRejectsBeforeSwiftOrExtraction(self):
        with tempfile.TemporaryDirectory() as root:
            root = Path(root)
            archive = "Orbit-0.1.2-macOS-universal.zip"
            (root / archive).write_bytes(b"altered archive")
            (root / "SHA256SUMS.txt").write_text("0" * 64 + "  " + archive + "\n")
            (root / "appcast.xml").write_text("feed")
            with patch.object(release, "run") as run:
                with self.assertRaisesRegex(RuntimeError, "checksum mismatch"):
                    release.verify_files(root, {"CFBundleShortVersionString": "0.1.2"})
                run.assert_not_called()

    def testMissingUploadedFeedRejectsBeforeDownload(self):
        info = {"CFBundleShortVersionString": "0.1.2", "CFBundleVersion": "7"}
        response = {"assets": [{"name": "Orbit-0.1.2-macOS-universal.zip", "size": 50},
                               {"name": "SHA256SUMS.txt", "size": 98}]}
        with patch.object(release, "source_info", return_value=info), patch.object(release, "api", return_value=response), patch.object(release, "download") as download:
            with self.assertRaisesRegex(RuntimeError, "missing a required"):
                release.verify_remote("v0.1.2")
            download.assert_not_called()


if __name__ == "__main__":
    unittest.main()
