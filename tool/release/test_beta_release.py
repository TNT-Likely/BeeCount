"""Offline orchestration/denial tests, never a simulated successful APK audit."""
import json
import base64
import contextlib
import io
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock
import urllib.request

import beta_release as beta
import local_apk as gate


class FloorTests(unittest.TestCase):
    def floor(self, floor="225", version="4.0.0-beta.2", records=()):
        client = mock.Mock()
        client.receipt.side_effect = records
        releases = [{"tag_name": r["versionName"], "assets": [{"id": i, "name": beta.RECEIPT}]}
                    for i, r in enumerate(records)]
        return beta.release_floor(client, releases, floor, version)

    def test_local_delivered_226_is_used_even_with_channel225(self):
        candidate, floor = self.floor()
        self.assertEqual((candidate.code, floor), (227, 226))

    def test_missing_injected_or_exhausted_floor_refuses(self):
        for value in ["", "1; id", "$(id)", "-1", "299"]:
            with self.subTest(value=value), self.assertRaises((gate.GateError, ValueError)):
                self.floor(value)

    def test_remote_and_draft_receipts_raise_the_floor(self):
        r = {"schemaVersion": 1, "package": gate.PACKAGE, "versionName": "4.0.0-beta.3", "versionCode": 231}
        candidate, floor = self.floor(version="4.0.0-beta.4", records=[r])
        self.assertEqual((candidate.code, floor), (232, 231))

    def test_remote_receipt_version_downgrade_and_bad_identity_refuse(self):
        r = {"schemaVersion": 1, "package": gate.PACKAGE, "versionName": "4.0.0-beta.3", "versionCode": 228}
        with self.assertRaises(ValueError):
            self.floor(records=[r])
        r["package"] += ".qa"
        with self.assertRaises(gate.GateError):
            self.floor(version="4.0.0-beta.4", records=[r])

    def test_stable_cannot_enter_beta_workflow(self):
        with self.assertRaises(gate.GateError):
            self.floor(version="4.0.0")

    def test_legacy_stable_tag_also_prevents_beta_version_downgrade(self):
        with self.assertRaises(ValueError):
            beta.release_floor(mock.Mock(), [{"tag_name": "4.0.0", "draft": False}], "300", "4.0.0-beta.2")


class SourceTests(unittest.TestCase):
    def test_only_v4_ancestor_commits_are_accepted(self):
        with tempfile.TemporaryDirectory() as root:
            def git(*args):
                return subprocess.check_output(["git", "-C", root, *args], stderr=subprocess.DEVNULL, text=True).strip()
            git("init", "-q")
            git("config", "user.email", "fixture@example.invalid")
            git("config", "user.name", "Fixture")
            git("remote", "add", "origin", "https://github.com/TNT-Likely/BeeCount.git")
            git("commit", "--allow-empty", "-qm", "fixture")
            ancestor = git("rev-parse", "HEAD")
            git("update-ref", "refs/remotes/origin/v4", ancestor)
            self.assertEqual(beta.source_sha("v4", Path(root)), ancestor)
            self.assertEqual(beta.source_sha(ancestor, Path(root)), ancestor)
            git("checkout", "--orphan", "unrelated")
            git("commit", "--allow-empty", "-qm", "unrelated fixture")
            with self.assertRaises(gate.GateError):
                beta.source_sha(git("rev-parse", "HEAD"), Path(root))
            for value in ["main", "HEAD", "v4; id", "$(id)", "../v4"]:
                with self.assertRaises(gate.GateError):
                    beta.source_sha(value, Path(root))


class DispatchTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.context = self.root / "context.json"
        self.env = mock.patch.dict(os.environ, {"BETA_CONTEXT": str(self.context), "RUNNER_TEMP": str(self.root)}, clear=True)
        self.env.start(); self.addCleanup(self.env.stop)

    def write_context(self, **values):
        gate.write_private(self.context, json.dumps(values).encode())

    def test_missing_signing_refuses_before_flutter_or_network(self):
        self.write_context(status="planned")
        with mock.patch.object(gate, "prepare_or_build") as build, mock.patch.object(beta, "GitHub") as github:
            with self.assertRaises(gate.GateError):
                beta.build()
        build.assert_not_called(); github.assert_not_called()

    def test_wrapped_base64_is_accepted_without_exposing_private_values(self):
        raw = b"not a real signing key"
        wrapped = base64.b64encode(raw).decode()
        os.environ.update(ANDROID_KEYSTORE_BASE64=wrapped[:8] + "\n" + wrapped[8:],
            ANDROID_KEYSTORE_PASSWORD="synthetic-secret", ANDROID_KEY_ALIAS="synthetic-alias", ANDROID_KEY_PASSWORD="synthetic-key")
        _, decoded = beta.signing_inputs()
        self.assertEqual(decoded, raw)
        os.environ["ANDROID_KEY_ALIAS"] = "androiddebugkey"
        with self.assertRaises(gate.GateError):
            beta.signing_inputs()

    def test_unverified_context_and_existing_release_cannot_publish(self):
        self.write_context(status="planned")
        with mock.patch.object(beta, "GitHub") as github, self.assertRaises(gate.GateError):
            beta.publish()
        github.assert_not_called()
        beta.save_context({"status": "verified", "versionName": "4.0.0-beta.2"})
        client = mock.Mock()
        client.releases.return_value = [{"tag_name": "4.0.0-beta.2"}]
        with mock.patch.object(beta, "GitHub", return_value=client), self.assertRaises(gate.GateError):
            beta.publish()
        client.request.assert_not_called()

    def test_control_flow_uploads_floor_before_apk_and_publishes_last(self):
        # This only tests orchestration with an explicitly stubbed auditor; it
        # does not assert that this synthetic file is a signed/valid APK.
        apk = self.root / "synthetic.apk"; apk.write_bytes(b"not an apk")
        artifact = {"apkSha256": "a" * 64}
        manifest = self.root / "manifest.json"
        manifest.write_text(json.dumps({"artifactRelativePath": apk.name, "artifact": artifact,
            "javaHome": str(self.root), "toolsPath": str(self.root / "build-tools/36.0.0")}))
        self.write_context(status="verified", versionName="4.0.0-beta.2", versionCode=227,
            sourceSha="a" * 40, certificateSha256=beta.PRODUCTION_CERTIFICATE,
            floor=226, manifest=str(manifest), runParent=str(self.root), notes="Reviewed notes")
        os.environ["GITHUB_RUN_ID"] = "123"
        client = mock.Mock(); client.releases.return_value = []
        client.request.side_effect = [None, {"id": 1, "html_url": "https://github.com/draft"},
            {"object": {"sha": "a" * 40}}, {"html_url": "https://github.com/published"}]
        with mock.patch.object(beta, "GitHub", return_value=client), mock.patch.object(gate, "verify_apk", return_value=artifact), contextlib.redirect_stdout(io.StringIO()):
            beta.publish()
        names = [call.args[1] for call in client.upload.call_args_list]
        self.assertEqual(names, [beta.RESERVATION, apk.name, apk.name + ".sha256", beta.RECEIPT])
        self.assertEqual(client.request.call_args_list[0].args[1], f"/repos/{beta.REPOSITORY}/git/refs")
        self.assertEqual(client.request.call_args.args[0], "PATCH")
        self.assertEqual(beta.read_context()["status"], "published")

    def test_notification_refuses_before_publish_and_never_uses_argv(self):
        self.write_context(status="verified")
        with mock.patch.object(beta, "open_url") as request, self.assertRaises(gate.GateError):
            beta.notify()
        request.assert_not_called()

    def test_authorization_not_forwarded_to_redirected_asset_host(self):
        req = urllib.request.Request("https://api.github.com/repos/test", headers={"Authorization": "Bearer synthetic"})
        redirected = beta.SafeRedirect().redirect_request(req, None, 302, "Found", {}, "https://objects.githubusercontent.com/asset")
        self.assertIsNone(redirected.get_header("Authorization"))


class Arm64ContractTests(unittest.TestCase):
    def test_flutter_target_is_single_arm64_and_default_is_unchanged(self):
        args = (Path("flutter"), "a" * 40, "4.0.0-beta.2", 227, "now")
        self.assertIn("--target-platform=android-arm64", gate.build_command(*args, arm64_only=True))
        self.assertIn("--target-platform=android-arm,android-arm64,android-x64", gate.build_command(*args))

    def test_arm64_only_metadata_rejects_additional_artifacts(self):
        with tempfile.TemporaryDirectory() as temp:
            source = Path(temp); output = source / "build/app/outputs/apk/prod/release"; output.mkdir(parents=True)
            apk = output / "arm64.apk"; apk.write_bytes(b"not an apk")
            data = {"applicationId": gate.PACKAGE, "variantName": "prodRelease", "elements": [{
                "filters": [{"filterType": "ABI", "value": gate.ABI}], "versionCode": 227,
                "versionName": "4.0.0-beta.2", "outputFile": apk.name}]}
            (output / "output-metadata.json").write_text(json.dumps(data))
            self.assertEqual(gate.select_arm64(source, "4.0.0-beta.2", 227, arm64_only=True), apk)
            (output / "universal.apk").write_bytes(b"not an apk")
            with self.assertRaises(gate.GateError):
                gate.select_arm64(source, "4.0.0-beta.2", 227, arm64_only=True)

    def test_workflows_separate_beta_and_share_delivery_mutex(self):
        root = Path(__file__).resolve().parents[2]
        beta_yaml = (root / ".github/workflows/beta-release.yml").read_text()
        stable_yaml = (root / ".github/workflows/release.yml").read_text()
        self.assertNotIn("\n  push:", beta_yaml)
        for text in [beta_yaml, stable_yaml]:
            self.assertIn("group: beecount-android-delivery", text)
            self.assertIn("cancel-in-progress: false", text)
        self.assertIn('"!*beta*"', stable_yaml)
        self.assertIn('"${TARGET_TAG,,}" == *beta*', stable_yaml)
        self.assertNotIn("|| github.event_name == 'push'", stable_yaml)
        gradle = (root / "android/app/build.gradle").read_text()
        self.assertIn("ndk { abiFilters 'arm64-v8a' }", gradle)
        self.assertIn("universalApk !arm64OnlyApk", gradle)
        self.assertNotRegex(beta_yaml, r"run:.*\$\{\{ inputs\.")


if __name__ == "__main__":
    unittest.main()
