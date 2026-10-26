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
import urllib.parse

import beta_release as beta
import local_apk as gate


def receipt(name="4.0.0-beta.2", code=227):
    return {"schemaVersion": 1, "kind": "beecount-beta-release" if "-beta." in name else "beecount-android-release", "package": gate.PACKAGE,
            "versionName": name, "versionCode": code, "sourceSha": "a" * 40,
            "certificateSha256": beta.PRODUCTION_CERTIFICATE, "apkSha256": "b" * 64, "abi": gate.ABI}


class SummaryTests(unittest.TestCase):
    def test_only_reviewed_summary_is_extracted_and_other_sections_are_excluded(self):
        notes = "# Beta\n\n## 更新摘要\n\n- 首页显示完整。\n- 标签显示更清楚。\n\n## 已知问题\n- 仍待真机验收。\n## 构建身份\n" + "a" * 40
        self.assertEqual(beta.extract_update_summary(notes), ["首页显示完整。", "标签显示更清楚。"])

    def test_only_five_short_items_are_sent_from_a_large_manual_section(self):
        notes = "## 更新摘要\n" + "\n".join("- " + str(i) + "很长的改进" * 100 for i in range(10))
        summary = beta.extract_update_summary(notes)
        self.assertEqual(len(summary), 5)
        self.assertTrue(all(len(line) <= 80 and line.endswith("…") for line in summary))

    def test_missing_duplicate_empty_or_non_bullet_summary_is_rejected(self):
        for notes in ["# No summary", "## 更新摘要\n## 其他\n- no", "## 更新摘要\n- a\n## 更新摘要\n- b",
                      "## 更新摘要\n```\ncommit\n```", "## 更新摘要\nnot a bullet"]:
            with self.subTest(notes=notes), self.assertRaises(gate.GateError):
                beta.extract_update_summary(notes)

    def test_commit_sha_and_links_are_not_user_visible_bullets(self):
        for value in ["commit " + "a" * 40, "Full log https://example.invalid/log", "Merge pull request #10"]:
            with self.subTest(value=value), self.assertRaises(gate.GateError):
                beta.extract_update_summary("## 更新摘要\n- " + value)

    def test_unicode_truncation_preserves_combining_emoji_zwj_and_flag_clusters(self):
        for cluster in ["e\u0301", "👩🏽‍💻", "👨‍👩‍👧‍👦", "🇨🇳"]:
            value = "中" * 78 + cluster + "后续内容"
            shortened = beta.short_summary_item(value)
            self.assertEqual(shortened, "中" * 78 + "…")
            shortened.encode("utf-8", errors="strict")
        self.assertEqual(beta.short_summary_item("中" * 90), "中" * 79 + "…")

    def test_telegram_is_labelled_and_bounded_without_commit_metadata(self):
        text = beta.telegram_text({"versionName": "4.0.0-beta.2", "versionCode": 227,
            "notificationSummary": ["变化" * 90] * 5,
            "releaseUrl": f"https://github.com/{beta.REPOSITORY}/releases/tag/4.0.0-beta.2",
            "sourceSha": "a" * 40})
        self.assertIn("Beta 内测", text)
        self.assertIn(beta.FEEDBACK, text)
        self.assertNotIn("a" * 40, text)
        self.assertLessEqual(len(text), 900)
        self.assertLessEqual(len(text.splitlines()), 12)


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
        r = receipt("4.0.0-beta.3", 231)
        candidate, floor = self.floor(version="4.0.0-beta.4", records=[r])
        self.assertEqual((candidate.code, floor), (232, 231))

    def test_remote_receipt_version_downgrade_and_bad_identity_refuse(self):
        r = receipt("4.0.0-beta.3", 228)
        with self.assertRaises(ValueError):
            self.floor(records=[r])
        r["package"] += ".qa"
        with self.assertRaises(gate.GateError):
            self.floor(version="4.0.0-beta.4", records=[r])

    def test_stable_cannot_enter_beta_workflow(self):
        with self.assertRaises(gate.GateError):
            self.floor(version="4.0.0")

    def test_receiptless_4x_stable_cannot_reuse_a_stale_external_floor(self):
        for name, actual_code, stale_floor, next_version in [
            ("4.0.0", 300, "226", "4.0.1-beta.1"),
            ("4.0.1", 301, "300", "4.0.2-beta.1"),
        ]:
            with self.subTest(name=name, actual=actual_code), self.assertRaisesRegex(gate.GateError, "缺少可信版本回执"):
                beta.release_floor(mock.Mock(), [{"tag_name": name, "draft": False}], stale_floor, next_version)

    def test_verified_stable_receipt_wins_over_stale_external_floor(self):
        candidate, floor = self.floor("226", "4.0.1-beta.1", [receipt("4.0.0", 300)])
        self.assertEqual((candidate.code, floor), (301, 300))
        candidate, floor = self.floor("300", "4.0.2-beta.1", [receipt("4.0.1", 301)])
        self.assertEqual((candidate.code, floor), (302, 301))

    def test_legacy_39_may_use_verified_floor_but_new_beta_or_draft_may_not(self):
        candidate, _ = beta.release_floor(mock.Mock(), [{"tag_name": "3.9.0", "draft": False}], "226", "4.0.0-beta.2")
        self.assertEqual(candidate.code, 227)
        for draft in [False, True]:
            with self.subTest(draft=draft), self.assertRaisesRegex(gate.GateError, "缺少可信版本回执"):
                beta.release_floor(mock.Mock(), [{"tag_name": "4.0.0-beta.1", "draft": draft}], "226", "4.0.0-beta.2")

    def test_untrusted_receipt_cannot_be_used_as_floor(self):
        for field, value in [("sourceSha", "wrong"), ("certificateSha256", "f" * 64),
                             ("abi", "x86_64"), ("kind", "unverified"), ("apkSha256", "")]:
            r = receipt(); r[field] = value
            with self.subTest(field=field), self.assertRaises(gate.GateError):
                self.floor("226", "4.0.0-beta.3", [r])


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
        beta.save_context({"status": "verified", "versionName": "4.0.0-beta.2", "versionCode": 227,
                           "notes": "## 更新摘要\n- 用户可见改进。"})
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
            floor=226, manifest=str(manifest), runParent=str(self.root), notes="## 更新摘要\n- 用户可见改进。\n")
        os.environ["GITHUB_RUN_ID"] = "123"
        client = mock.Mock(); client.releases.return_value = []
        client.request.side_effect = [None, {"id": 1, "html_url": "https://github.com/draft"},
            {"object": {"sha": "a" * 40}}, {"html_url": "https://github.com/published"}]
        with mock.patch.object(beta, "GitHub", return_value=client), mock.patch.object(gate, "verify_apk", return_value=artifact), contextlib.redirect_stdout(io.StringIO()):
            beta.publish()
        names = [call.args[1] for call in client.upload.call_args_list]
        self.assertEqual(names, [beta.RESERVATION, apk.name, apk.name + ".sha256", beta.RECEIPT])
        self.assertEqual(client.request.call_args_list[0].args[1], f"/repos/{beta.REPOSITORY}/git/refs")
        self.assertEqual(client.request.call_args_list[1].args[2]["make_latest"], "false")
        self.assertIs(client.request.call_args_list[1].args[2]["generate_release_notes"], False)
        self.assertEqual(client.request.call_args.args[0], "PATCH")
        self.assertEqual(client.request.call_args.args[2]["make_latest"], "false")
        self.assertEqual(beta.read_context()["status"], "published")

    def test_notification_refuses_before_publish_and_never_uses_argv(self):
        self.write_context(status="verified")
        with mock.patch.object(beta, "open_url") as request, self.assertRaises(gate.GateError):
            beta.notify()
        request.assert_not_called()

    def test_missing_summary_stops_plan_before_build_or_any_github_write(self):
        os.environ.update(GITHUB_REPOSITORY=beta.REPOSITORY, GITHUB_EVENT_NAME="workflow_dispatch",
            BETA_EXPECTED_CERTIFICATE=beta.PRODUCTION_CERTIFICATE, BETA_VERSION="4.0.0-beta.2", BETA_CHANNEL_FLOOR="226")
        client = mock.Mock(); client.releases.return_value = []
        results = [subprocess.CompletedProcess([], 1), subprocess.CompletedProcess([], 1),
                   subprocess.CompletedProcess([], 0, stdout="# 说明\n" + "没有摘要的正文。" * 30 + beta.FEEDBACK)]
        with mock.patch.object(beta, "source_sha", return_value="a" * 40), mock.patch.object(beta, "GitHub", return_value=client), \
             mock.patch.object(subprocess, "run", side_effect=results), mock.patch.object(gate, "prepare_or_build") as build, \
             self.assertRaisesRegex(gate.GateError, "更新摘要"):
            beta.plan()
        build.assert_not_called()
        client.request.assert_not_called()
        self.assertFalse(self.context.exists())

    def test_notify_payload_contains_original_summary_without_full_history(self):
        self.write_context(status="published", versionName="4.0.0-beta.2", versionCode=227,
            releaseUrl=f"https://github.com/{beta.REPOSITORY}/releases/tag/4.0.0-beta.2",
            notificationSummary=["原公告的改进。"], sourceSha="a" * 40)
        os.environ.update(TELEGRAM_BOT_TOKEN="123:synthetic", TELEGRAM_CHAT_ID="synthetic-chat")
        with mock.patch.object(beta, "open_url", return_value=io.BytesIO(b'{"ok":true}')) as request, contextlib.redirect_stdout(io.StringIO()):
            beta.notify()
        payload = urllib.parse.parse_qs(request.call_args.args[0].data.decode())
        self.assertIn("原公告的改进。", payload["text"][0])
        self.assertNotIn("a" * 40, payload["text"][0])

    def notification_fixture(self):
        os.environ.update(GITHUB_REPOSITORY=beta.REPOSITORY, GITHUB_EVENT_NAME="workflow_dispatch",
                          BETA_EXPECTED_CERTIFICATE=beta.PRODUCTION_CERTIFICATE, BETA_VERSION="4.0.0-beta.2")
        release = {"id": 2, "tag_name": "4.0.0-beta.2", "draft": False, "prerelease": True,
                   "body": "## 更新摘要\n- 原公告的改进。\n## 构建身份\n" + "a" * 40,
                   "html_url": f"https://github.com/{beta.REPOSITORY}/releases/tag/4.0.0-beta.2",
                   "assets": [{"id": 3, "name": beta.RECEIPT},
                              {"id": 4, "name": "beecount-4.0.0-beta.2-arm64-v8a.apk", "size": 100,
                               "digest": "sha256:" + "b" * 64}]}
        client = mock.Mock()
        client.releases.return_value = [release]
        client.receipt.return_value = receipt()
        return client, release

    def test_notification_only_loads_verified_published_receipt_without_any_writes(self):
        client, _ = self.notification_fixture()
        with mock.patch.object(beta, "GitHub", return_value=client), mock.patch.object(gate, "prepare_or_build") as build, contextlib.redirect_stdout(io.StringIO()):
            beta.notification_plan()
        build.assert_not_called()
        client.request.assert_not_called()
        client.upload.assert_not_called()
        self.assertEqual(beta.read_context()["mode"], "notify-only")
        self.assertEqual(beta.read_context()["versionCode"], 227)
        self.assertEqual(beta.read_context()["notificationSummary"], ["原公告的改进。"])
        self.assertNotIn("runParent", beta.read_context())

    def test_notification_only_refuses_draft_stable_missing_or_tampered_identity(self):
        for change in ["draft", "stable", "missing", "cert", "sha", "url", "summary"]:
            client, release = self.notification_fixture()
            if change == "draft": release["draft"] = True
            if change == "stable": release["prerelease"] = False
            if change == "missing": release["assets"] = []
            if change == "cert": client.receipt.return_value["certificateSha256"] = "f" * 64
            if change == "sha": release["assets"][1]["digest"] = "sha256:" + "c" * 64
            if change == "url": release["html_url"] = "https://other.example/download"
            if change == "summary": release["body"] = "No reviewed summary"
            with self.subTest(change=change), mock.patch.object(beta, "GitHub", return_value=client), self.assertRaises(gate.GateError):
                beta.notification_plan()
            client.request.assert_not_called()
            client.upload.assert_not_called()
            self.assertFalse(self.context.exists())

    def test_authorization_not_forwarded_to_redirected_asset_host(self):
        req = urllib.request.Request("https://api.github.com/repos/test", headers={"Authorization": "Bearer synthetic"})
        redirected = beta.SafeRedirect().redirect_request(req, None, 302, "Found", {}, "https://objects.githubusercontent.com/asset")
        self.assertIsNone(redirected.get_header("Authorization"))


class Arm64ContractTests(unittest.TestCase):
    def test_flutter_target_is_single_arm64_and_default_is_unchanged(self):
        args = (Path("flutter"), "a" * 40, "4.0.0-beta.2", 227, "now")
        self.assertIn("--target-platform=android-arm64", gate.build_command(*args, arm64_only=True))
        self.assertIn("--split-per-abi", gate.build_command(*args, arm64_only=True))
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
        # A real ARM64 build rejected the former combination of NDK filters
        # and ABI splits. The single-ABI split and artifact gate own this rule.
        self.assertNotIn("ndk { abiFilters", gradle)
        self.assertIn("universalApk !arm64OnlyApk", gradle)
        self.assertNotRegex(beta_yaml, r"run:.*\$\{\{ inputs\.")
        notification = beta_yaml.split("\n  notify-only:", 1)[1]
        self.assertIn("contents: read", notification)
        self.assertIn("notification_plan", notification)
        self.assertNotIn("ANDROID_KEYSTORE", notification)
        self.assertNotIn("beta_release.py build", notification)
        self.assertNotIn("beta_release.py publish", notification)


if __name__ == "__main__":
    unittest.main()
