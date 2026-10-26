"""Local-only refusal tests. Never sign/build/install or access real credentials.

The optional positive artifact check reads the already verified public 3.9.0 APK.
No mock APK is ever represented as a successful release artifact.
"""

import argparse
import base64
import contextlib
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import unittest
from unittest import mock
import zipfile

import local_apk as gate

PUBLIC_CERT = "0db081285aca34ec4a93137999524c2a3d05f58c5d9ed9899952c6669dab1e9f"


class TemporaryCase(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="beecount-apk-gate-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)

    def registry(self):
        path = self.root / "delivered.jsonl"
        gate.init_registry(path)
        return path

    def record(self, name="4.0.0-beta.1"):
        return {"deliveredAtUtc": "2026-10-26T01:00:00+00:00", "versionName": name,
                "versionCode": gate.parse_version(name).code, "sourceSha": "1" * 40,
                "apkSha256": "2" * 64, "certificateSha256": PUBLIC_CERT,
                "acceptanceReportSha256": "3" * 64, "abi": gate.ABI, "package": gate.PACKAGE}


class RegistryTests(TemporaryCase):
    def test_missing_registry_cannot_silently_reset_history(self):
        with self.assertRaises(gate.GateError):
            gate.registry_snapshot(self.root / "missing.jsonl")

    def test_append_preserves_prefix_and_highest_delivered_code_wins(self):
        registry = self.registry()
        before = registry.read_bytes()
        gate.append_delivery(registry, self.record("4.0.0-beta.2"))
        self.assertTrue(registry.read_bytes().startswith(before))
        self.assertEqual(gate.registry_snapshot(registry)["maximumCode"], 4_000_002)
        with self.assertRaises(ValueError):
            gate.validate_candidate("4.0.0-beta.1", minimum_code=max(225, gate.registry_snapshot(registry)["maximumCode"]))
        self.assertEqual(gate.validate_candidate("4.0.0", minimum_code=4_000_002).code, 4_000_099)

    def test_equal_and_lower_delivery_cannot_append(self):
        registry = self.registry()
        gate.append_delivery(registry, self.record("4.0.0-beta.2"))
        before = registry.read_bytes()
        for name in ["4.0.0-beta.1", "4.0.0-beta.2"]:
            with self.assertRaises(gate.GateError):
                gate.append_delivery(registry, self.record(name))
        self.assertEqual(registry.read_bytes(), before)

    def test_tamper_and_truncated_tail_are_refused(self):
        registry = self.registry()
        gate.append_delivery(registry, self.record())
        original = registry.read_bytes()
        registry.write_bytes(original.replace(b'"sourceSha":"1', b'"sourceSha":"a', 1))
        with self.assertRaises(gate.GateError):
            gate.registry_snapshot(registry)
        registry.write_bytes(original[:-1])
        with self.assertRaises(gate.GateError):
            gate.registry_snapshot(registry)

    def test_existing_registry_is_never_reinitialized(self):
        registry = self.registry()
        original = registry.read_bytes()
        with self.assertRaises(gate.GateError):
            gate.init_registry(registry)
        self.assertEqual(original, registry.read_bytes())

    def test_removing_a_whole_valid_tail_is_detected_by_high_water_receipt(self):
        registry = self.registry()
        prefix = registry.read_bytes()
        gate.append_delivery(registry, self.record())
        registry.write_bytes(prefix)
        with self.assertRaises(gate.GateError):
            gate.registry_snapshot(registry)

    def test_lost_high_water_receipt_does_not_reset_history(self):
        registry = self.registry()
        gate.registry_head(registry).unlink()
        with self.assertRaises(gate.GateError):
            gate.registry_snapshot(registry)


class SigningTests(TemporaryCase):
    def test_missing_credentials_refuses_before_any_subprocess(self):
        registry = self.registry()
        args = argparse.Namespace(expected_certificate=PUBLIC_CERT, registry=registry,
                                  minimum_code=225, version="4.0.0-beta.1", credentials_file=None)
        with mock.patch.dict(os.environ, {}, clear=True), mock.patch.object(subprocess, "run") as command:
            with self.assertRaises(gate.GateError):
                gate.prepare_or_build(args)
        command.assert_not_called()

    def test_registry_floor_refuses_candidate_before_credentials_or_flutter(self):
        registry = self.registry()
        gate.append_delivery(registry, self.record("4.0.0-beta.2"))
        args = argparse.Namespace(expected_certificate=PUBLIC_CERT, registry=registry,
                                  minimum_code=225, version="4.0.0-beta.1", credentials_file=None)
        with mock.patch.object(subprocess, "run") as command:
            with self.assertRaises(ValueError):
                gate.prepare_or_build(args)
        command.assert_not_called()

    def test_world_readable_credentials_and_debug_alias_are_refused(self):
        store = self.root / "sample-store"
        gate.write_private(store, b"deliberately not a keystore")
        data = {"storeFile": str(store), "storePassword": "synthetic-only",
                "keyAlias": "synthetic-key", "keyPassword": "synthetic-only"}
        path = self.root / "private.json"
        path.write_text(json.dumps(data))
        path.chmod(0o644)
        with self.assertRaises(gate.GateError):
            gate.load_credentials(path, {})
        data["keyAlias"] = "androiddebugkey"
        path.write_text(json.dumps(data)); path.chmod(0o600)
        with self.assertRaises(gate.GateError):
            gate.load_credentials(path, {})

    def signing_failure(self, response=None):
        store = self.root / "not-real-keystore"
        gate.write_private(store, b"no key material")
        credentials = {"storeFile": str(store), "storePassword": "unit-test-only",
                       "keyAlias": "unit-test-only", "keyPassword": "unit-test-only"}
        calls = []

        class RefusalRunner:
            def run(self, arguments, *, label):
                calls.append((arguments, label))
                if label == "unlock-private-key":
                    if response is None:
                        raise gate.GateError("synthetic password-unlock failure")
                    return json.dumps(response)
                return ""

        with self.assertRaises(gate.GateError):
            gate.verify_signing(credentials, PUBLIC_CERT, Path("/not-executed-java"), RefusalRunner(), self.root)
        self.assertFalse(any("flutter" in str(item) for args, _ in calls for item in args))
        self.assertFalse(any("unit-test-only" in str(item) for args, _ in calls for item in args))

    def test_password_unlock_error_cannot_reach_flutter(self):
        self.signing_failure()

    def test_unlocked_key_with_wrong_certificate_cannot_reach_flutter(self):
        self.signing_failure({"privateKeyUnlocked": True, "debugCertificate": False,
                              "certificateSha256": "f" * 64})

    def test_real_java_invalid_store_refuses_and_removes_temporary_material(self):
        java_value, sdk_value = os.environ.get("JAVA_HOME"), os.environ.get("ANDROID_SDK_ROOT")
        flutter_value = os.environ.get("BEECOUNT_FLUTTER_FOR_PREFLIGHT_TEST")
        if not java_value or not sdk_value or not flutter_value:
            self.skipTest("optional: local Java/SDK/Flutter paths; Flutter itself is never executed")
        store = self.root / "invalid-store"
        gate.write_private(store, b"intentionally invalid; no key material")
        credentials = self.root / "synthetic-input.json"
        gate.write_private(credentials, json.dumps({"storeFile": str(store), "storePassword": "synthetic-only",
                             "keyAlias": "synthetic-only", "keyPassword": "synthetic-only"}).encode())
        args = argparse.Namespace(expected_certificate=PUBLIC_CERT, registry=self.registry(), minimum_code=225,
                    version="4.0.0-beta.1", credentials_file=credentials, java_home=Path(java_value),
                    sdk_root=Path(sdk_value), flutter=Path(flutter_value), build_tools="36.0.0",
                    run_parent=self.root, source_sha="a" * 40, execute=False)
        with contextlib.redirect_stdout(io.StringIO()), self.assertRaises(gate.GateError):
            gate.prepare_or_build(args)
        runs = list(self.root.glob("beecount-local-apk-*"))
        self.assertEqual(len(runs), 1)
        manifest = json.loads((runs[0] / "manifest.json").read_text())
        self.assertEqual(manifest["status"], "failed")
        self.assertEqual([row["label"] for row in manifest["commands"]],
                         ["java-version", "compile-signing-probe", "unlock-private-key"])
        self.assertTrue(manifest["temporarySigningMaterialRemoved"])
        self.assertFalse((runs[0] / "signing.properties").exists())
        self.assertFalse((runs[0] / "signing.keystore").exists())
        self.assertNotIn("synthetic-only", (runs[0] / "logs/unlock-private-key.log").read_text())

    def test_accidental_password_argument_is_not_echoed(self):
        stderr = io.StringIO()
        with contextlib.redirect_stderr(stderr), self.assertRaises(SystemExit):
            gate.parser().parse_args(["init-registry", "--registry", "/unused", "--password", "synthetic-secret-not-for-output"])
        self.assertNotIn("synthetic-secret-not-for-output", stderr.getvalue())

    def test_properties_roundtrip_uses_real_java_reader(self):
        java_home = Path(os.environ.get("JAVA_HOME", "/nonexistent"))
        if not (java_home / "bin/javac").is_file():
            self.skipTest("set JAVA_HOME to run Java Properties compatibility check")
        values = {"storeFile": r"/test only/C:\路径\store.jks", "storePassword": " leading =:# !\\\t\n\ré😀  ",
                  "keyAlias": "#alias:!= 演示", "keyPassword": "\\u1234\fwith spaces "}
        properties = self.root / "synthetic.properties"
        gate.write_private(properties, gate.properties_bytes(values))
        source = self.root / "PropertiesReader.java"
        source.write_text('''import java.util.*;import java.io.*;
public class PropertiesReader {public static void main(String[] a)throws Exception{
Properties p=new Properties();try(InputStream f=new FileInputStream(a[0])){p.load(f);}
for(String k:new String[]{"storeFile","storePassword","keyAlias","keyPassword"}){
System.out.println(k+":"+Base64.getEncoder().encodeToString(p.getProperty(k).getBytes("UTF-8")));}}}''')
        subprocess.run([java_home / "bin/javac", source], check=True, capture_output=True)
        read = subprocess.run([java_home / "bin/java", "-cp", self.root, "PropertiesReader", properties],
                              check=True, capture_output=True, text=True).stdout
        actual = {line.split(":", 1)[0]: base64.b64decode(line.split(":", 1)[1]).decode() for line in read.splitlines()}
        self.assertEqual(values, actual)


class SourceAndArtifactRefusalTests(TemporaryCase):
    def make_tar(self, name, data=b"sample", *, link=None):
        path = self.root / "source.tar"
        with tarfile.open(path, "w") as tar:
            member = tarfile.TarInfo(name)
            if link:
                member.type = tarfile.SYMTYPE; member.linkname = link
                tar.addfile(member)
            else:
                member.size = len(data); tar.addfile(member, io.BytesIO(data))
        return path

    def test_archive_rejects_traversal_and_private_configuration(self):
        for index, name in enumerate(["../outside", "android/key.properties", ".env"]):
            with self.assertRaises(gate.GateError):
                gate.extract_archive(self.make_tar(name), self.root / ("extracted" + str(index)))

    def test_archive_rejects_outside_symlink(self):
        with self.assertRaises(gate.GateError):
            gate.extract_archive(self.make_tar("outside-link", link="../../outside"), self.root / "copy")

    def test_gallery_overlay_refuses_new_production_asset_dependency(self):
        (self.root / gate.GALLERY).mkdir(parents=True)
        (self.root / gate.GALLERY_ENTRY).write_text("// development only")
        (self.root / "assets/v4_gallery").mkdir(parents=True)
        (self.root / "pubspec.yaml").write_text("flutter:\n  assets:\n    - assets/v4_gallery/\n")
        (self.root / "lib/main.dart").write_text("final file = 'assets/v4_gallery/picture.png';")
        with self.assertRaises(gate.GateError):
            gate.release_overlay(self.root)
        self.assertTrue((self.root / "assets/v4_gallery").exists())

    def test_overlay_records_each_removed_sample_and_stubs_import_graph(self):
        (self.root / gate.GALLERY).mkdir(parents=True)
        (self.root / gate.GALLERY_ENTRY).write_text("// original component gallery")
        (self.root / gate.GALLERY / "sample.dart").write_text("// synthetic development data")
        (self.root / "assets/v4_gallery").mkdir(parents=True)
        (self.root / "assets/v4_gallery/example.json").write_text("{}")
        (self.root / "pubspec.yaml").write_text("flutter:\n  assets:\n    - assets/v4_gallery/\n    - assets/logo.svg\n")
        (self.root / "lib/main.dart").write_text("void main() {}")
        receipt = gate.release_overlay(self.root)
        self.assertFalse((self.root / "assets/v4_gallery").exists())
        self.assertFalse((self.root / gate.GALLERY / "sample.dart").exists())
        self.assertIn("UnsupportedError", (self.root / gate.GALLERY_ENTRY).read_text())
        self.assertNotIn("assets/v4_gallery/", (self.root / "pubspec.yaml").read_text())
        self.assertTrue(any(row["path"] == "assets/v4_gallery/example.json" and row["afterSha256"] is None for row in receipt["changes"]))

    def test_only_exact_untracked_generated_plugin_registrant_is_allowed(self):
        before = {"lib/main.dart": "a" * 64, "pubspec.lock": "b" * 64}
        after = dict(before, **{gate.GENERATED_REGISTRANT: "c" * 64})
        overlay = gate.generated_source_overlay(before, after)
        self.assertEqual(overlay[0]["path"], gate.GENERATED_REGISTRANT)
        self.assertEqual(overlay[0]["sha256"], "c" * 64)
        for bad in [dict(after, **{"lib/main.dart": "d" * 64}),
                    dict(after, **{"android/app/src/main/java/Other.java": "d" * 64})]:
            with self.assertRaises(gate.GateError):
                gate.generated_source_overlay(before, bad)
        # If a future commit intentionally tracks it, original bytes still must not change.
        with self.assertRaises(gate.GateError):
            gate.generated_source_overlay(after, dict(after, **{gate.GENERATED_REGISTRANT: "d" * 64}))

    def test_gallery_import_cannot_hide_unconditional_route_behind_unrelated_debug_flag(self):
        (self.root / gate.GALLERY).mkdir(parents=True)
        (self.root / gate.GALLERY_ENTRY).write_text("// original component gallery")
        (self.root / "assets/v4_gallery").mkdir(parents=True)
        (self.root / "pubspec.yaml").write_text("flutter:\n  assets:\n    - assets/v4_gallery/\n")
        importer = self.root / "lib/pages/main/home_page.dart"
        importer.parent.mkdir(parents=True)
        importer.write_text("import '../../presentation/v4/gallery/component_gallery_page.dart';\n"
                            "void unrelated() { if (kDebugMode) print('example'); }\n"
                            "final route = const ComponentGalleryPage();\n")
        with self.assertRaises(gate.GateError):
            gate.release_overlay(self.root)

    def test_testonly_debug_and_instrumentation_are_rejected(self):
        for manifest in ["E: instrumentation (line=2)",
                         "A: android:debuggable(0x0101000f)=(type 0x12)0xffffffff",
                         "A: android:testOnly(0x0101000f)=(type 0x12)0xffffffff",
                         'A: android:name="com.tntlikely.beecount.qa.MainActivity"']:
            with self.assertRaises(gate.GateError):
                gate.manifest_gate(manifest)

    def test_missing_actual_manifest_fields_are_rejected(self):
        with self.assertRaises(gate.GateError):
            gate.parse_badging("package: name='com.tntlikely.beecount' versionCode='4000001' versionName='4.0.0-beta.1'\n")

    def test_contaminated_archive_is_rejected_before_external_tools(self):
        # Deliberately invalid artifact: this is solely a refusal fixture, never a successful APK.
        archive = self.root / "invalid-artifact.apk"
        with zipfile.ZipFile(archive, "w") as zip_file:
            zip_file.writestr("AndroidManifest.xml", "not an Android binary manifest")
            zip_file.writestr("assets/flutter_assets/assets/v4_gallery/example.json", "{}")
        with self.assertRaises(gate.GateError):
            gate.audit_zip(archive)

    def test_debug_kernel_payload_is_rejected_even_with_release_filename(self):
        archive = self.root / "beecount-prod-release.apk"
        with zipfile.ZipFile(archive, "w") as zip_file:
            zip_file.writestr("AndroidManifest.xml", "invalid negative fixture")
            zip_file.writestr("assets/flutter_assets/kernel_blob.bin", "invalid negative fixture")
        with self.assertRaises(gate.GateError):
            gate.audit_zip(archive)

    def test_duplicate_arm64_metadata_is_rejected(self):
        directory = self.root / "build/app/outputs/apk/prod/release"
        directory.mkdir(parents=True)
        row = {"filters": [{"filterType": "ABI", "value": "arm64-v8a"}], "versionCode": 4_000_001,
               "versionName": "4.0.0-beta.1", "outputFile": "misleading-name.apk"}
        (directory / "output-metadata.json").write_text(json.dumps({"applicationId": gate.PACKAGE,
                         "variantName": "prodRelease", "elements": [row, row]}))
        with self.assertRaises(gate.GateError):
            gate.select_arm64(self.root, "4.0.0-beta.1", 4_000_001)

    def test_build_plan_is_normal_release_with_no_qa_entry(self):
        command = gate.build_command("/not-executed/flutter", "a" * 40, "4.0.0-beta.1", 4_000_001, "2026-10-26T01:00:00+00:00")
        self.assertIn("--release", command)
        self.assertEqual(command[command.index("--flavor") + 1], "prod")
        self.assertIn("--target=lib/main.dart", command)
        self.assertIn("--dart-define=CI_VERSION=4.0.0-beta.1", command)
        self.assertIn("--dart-define=BEECOUNT_V4_RECORDING=false", command)
        self.assertFalse(any("integration_test" in item or "--split-per-abi" in item for item in command))


class PublicArtifactTests(TemporaryCase):
    def test_real_public_390_identity_without_signing_or_building(self):
        fixture = os.environ.get("BEECOUNT_PUBLIC_APK_FIXTURE")
        sdk_value, java_value = os.environ.get("ANDROID_SDK_ROOT"), os.environ.get("JAVA_HOME")
        if not fixture or not sdk_value or not java_value:
            self.skipTest("optional: provide verified public APK, SDK and Java17 paths")
        path, sdk, java = Path(fixture), Path(sdk_value), Path(java_value)
        self.assertEqual(gate.sha256(path), "f946b99f749be5f6376399e41824043d15a9fdd6047c1b779f7319090dc416a8")
        runner = gate.Runner(self.root, gate.clean_environment(java, sdk))
        result = gate.verify_apk(path, expected_version="3.9.0", expected_code=225,
                    expected_certificate=PUBLIC_CERT, tools=sdk / "build-tools/36.0.0", runner=runner)
        self.assertEqual(result["abis"], [gate.ABI])
        self.assertEqual(result["package"], gate.PACKAGE)
        self.assertFalse(any("flutter" in item["label"] for item in runner.commands))


if __name__ == "__main__":
    unittest.main()
