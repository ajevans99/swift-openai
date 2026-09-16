import importlib.util
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch


SPEC = importlib.util.spec_from_file_location(
    "generate_responses", Path(__file__).resolve().parents[1] / "generate-responses.py"
)
generation = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(generation)


class InputFixture(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.inputs = Path(self.temporary.name)
        self.override = patch.object(generation, "INPUTS", self.inputs)
        self.override.start()
        self.addCleanup(self.override.stop)
        self.source = {
            "version": 1,
            "specification": {"path": "openapi.json", "sha256": generation.sha256(b'{"openapi":"3.1.0"}')},
            "license": {"path": "openapi.LICENSE", "sha256": generation.sha256(b"Example license")},
        }
        (self.inputs / "openapi.json").write_bytes(b'{"openapi":"3.1.0"}')
        (self.inputs / "openapi.LICENSE").write_bytes(b"Example license")
        self.write_source()

    def write_source(self):
        (self.inputs / "source.json").write_text(json.dumps(self.source))


class InputVerificationTests(InputFixture):
    def test_matching_assets_are_accepted_offline(self):
        with patch.object(generation.urllib.request, "urlopen") as network:
            self.assertEqual(generation.verify_inputs(), self.source)
            network.assert_not_called()

    def test_modified_specification_is_rejected(self):
        (self.inputs / "openapi.json").write_bytes(b"modified")
        with self.assertRaisesRegex(ValueError, "specification SHA256 mismatch"):
            generation.verify_inputs()

    def test_modified_license_is_rejected(self):
        (self.inputs / "openapi.LICENSE").write_bytes(b"modified")
        with self.assertRaisesRegex(ValueError, "license SHA256 mismatch"):
            generation.verify_inputs()

    def test_missing_asset_is_rejected(self):
        (self.inputs / "openapi.json").unlink()
        with self.assertRaises(FileNotFoundError):
            generation.verify_inputs()

    def test_unknown_version_is_rejected(self):
        self.source["version"] = 2
        self.write_source()
        with self.assertRaisesRegex(ValueError, "Unsupported source provenance version"):
            generation.verify_inputs()

    def test_asset_outside_input_directory_is_rejected(self):
        self.source["specification"]["path"] = "../openapi.json"
        self.write_source()
        with self.assertRaisesRegex(ValueError, "Asset path must be directly inside"):
            generation.verify_inputs()

    def test_failed_fetch_does_not_overwrite_pinned_asset(self):
        self.source["specification"]["url"] = "https://example.invalid/spec.json"
        self.write_source()
        with patch.object(generation.urllib.request, "urlopen") as network:
            network.return_value.read.return_value = b"wrong bytes"
            with self.assertRaisesRegex(ValueError, "specification SHA256 mismatch"):
                generation.verify_inputs(fetch=True)
        self.assertEqual((self.inputs / "openapi.json").read_bytes(), b'{"openapi":"3.1.0"}')


class GenerationWorkflowTests(InputFixture):
    def setUp(self):
        super().setUp()
        self.output = self.inputs / "Generated" / "Client.swift"
        self.provenance = self.inputs / "generation.json"
        (self.inputs / "profile.json").write_text('{"version":1,"operations":{}}')
        self.args = SimpleNamespace(
            generator_package=self.inputs / "generator",
            allow_uncommitted_generator=False,
            check=False,
            scratch_path=self.inputs / "build",
            jobs=1,
            build_system="native",
        )
        for attribute, value in (
            ("ROOT", self.inputs),
            ("OUTPUT", self.output),
            ("PROVENANCE", self.provenance),
            ("LOCAL_PROVENANCE", self.inputs / "local-generation.json"),
        ):
            override = patch.object(generation, attribute, value)
            override.start()
            self.addCleanup(override.stop)
        provenance = patch.object(
            generation, "generator_provenance", return_value={"revision": "test-revision"}
        )
        self.generator_provenance = provenance.start()
        self.addCleanup(provenance.stop)

        def emit_fixture(command, **_):
            Path(command[command.index("--output") + 1]).write_bytes(b"// Generated test fixture\n")

        process = patch.object(generation.subprocess, "run", side_effect=emit_fixture)
        self.process = process.start()
        self.addCleanup(process.stop)
        version = patch.object(generation.subprocess, "check_output", return_value="Swift test toolchain")
        version.start()
        self.addCleanup(version.stop)

    def test_generation_and_drift_check_match(self):
        generation.generate(self.args, self.source)
        self.args.check = True
        generation.generate(self.args, self.source)
        metadata = json.loads(self.provenance.read_text())
        self.assertEqual(metadata["output"]["sha256"], generation.sha256(self.output.read_bytes()))
        self.assertEqual(metadata["profileSHA256"], generation.sha256((self.inputs / "profile.json").read_bytes()))

    def test_build_controls_are_passed_without_affecting_generator_arguments(self):
        generation.generate(self.args, self.source)
        command = self.process.call_args.args[0]
        self.assertEqual(command[command.index("--jobs") + 1], "1")
        self.assertEqual(command[command.index("--build-system") + 1], "native")
        self.assertEqual(command[command.index("--scratch-path") + 1], str(self.args.scratch_path.resolve()))
        self.assertEqual(command[command.index("--operation") + 1], "createResponse")

    def test_local_checkout_paths_are_separate_from_portable_drift_record(self):
        self.generator_provenance.return_value = {
            "revision": "same-commit", "sourceSHA256": "same-content", "resolvedPath": "/first/checkout",
        }
        generation.generate(self.args, self.source)
        first = self.provenance.read_bytes()
        self.generator_provenance.return_value["resolvedPath"] = "/relocated/checkout"
        self.args.check = True
        generation.generate(self.args, self.source)
        self.assertEqual(self.provenance.read_bytes(), first)
        self.assertNotIn(b"resolvedPath", first)
        local = json.loads(generation.LOCAL_PROVENANCE.read_text())
        self.assertEqual(local["generator"]["resolvedPath"], "/relocated/checkout")

    def test_source_drift_fails_without_overwriting(self):
        generation.generate(self.args, self.source)
        self.output.write_bytes(b"manually changed")
        self.args.check = True
        with self.assertRaisesRegex(RuntimeError, "Swift source has drifted"):
            generation.generate(self.args, self.source)
        self.assertEqual(self.output.read_bytes(), b"manually changed")

    def test_metadata_drift_fails_without_overwriting(self):
        generation.generate(self.args, self.source)
        self.provenance.write_bytes(b"manually changed")
        self.args.check = True
        with self.assertRaisesRegex(RuntimeError, "provenance has drifted"):
            generation.generate(self.args, self.source)
        self.assertEqual(self.provenance.read_bytes(), b"manually changed")

    def test_generator_change_during_run_writes_no_artifacts(self):
        for key in ("revision", "sourceSHA256", "resolvedPath"):
            with self.subTest(changed=key):
                self.generator_provenance.side_effect = [{key: "before"}, {key: "after"}]
                with self.assertRaisesRegex(RuntimeError, "changed during generation"):
                    generation.generate(self.args, self.source)
                self.assertFalse(self.output.exists())
                self.assertFalse(self.provenance.exists())

    def test_driver_change_during_run_writes_no_artifacts(self):
        driver = self.inputs / "driver.py"
        driver.write_bytes(b"before")

        def change_driver(command, **_):
            Path(command[command.index("--output") + 1]).write_bytes(b"// Test fixture\n")
            driver.write_bytes(b"after")

        self.process.side_effect = change_driver
        with patch.object(generation, "__file__", str(driver)):
            with self.assertRaisesRegex(RuntimeError, "Generation driver"):
                generation.generate(self.args, self.source)
        self.assertFalse(self.output.exists())
        self.assertFalse(self.provenance.exists())

    def test_profile_change_during_run_writes_no_artifacts(self):
        def change_profile(command, **_):
            Path(command[command.index("--output") + 1]).write_bytes(b"// Test fixture\n")
            (self.inputs / "profile.json").write_bytes(b"changed")

        self.process.side_effect = change_profile
        with self.assertRaisesRegex(RuntimeError, "profile changed during generation"):
            generation.generate(self.args, self.source)
        self.assertFalse(self.output.exists())
        self.assertFalse(self.provenance.exists())


class GeneratorProvenanceTests(unittest.TestCase):
    def test_canonical_alias_records_real_path_and_untracked_source_bytes(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            checkout = root / "feature-worktree"
            (checkout / "Sources").mkdir(parents=True)
            (checkout / "Package.swift").write_bytes(b"manifest")
            (checkout / "Sources" / "Untracked.swift").write_bytes(b"helper")
            alias = root / "swift-json-schema"
            alias.symlink_to(checkout, target_is_directory=True)
            with patch.object(generation, "git", side_effect=[
                generation.GENERATOR_REPOSITORY, "?? Sources/Untracked.swift", "base-commit",
            ]), patch.object(
                generation.subprocess, "check_output",
                return_value=b"Package.swift\0Sources/Untracked.swift\0",
            ):
                result = generation.repository_provenance(alias, generation.GENERATOR_REPOSITORY, True)
        self.assertEqual(result["resolvedPath"], str(checkout.resolve()))
        self.assertTrue(result["uncommittedSources"])
        self.assertEqual(result["sourceFiles"]["Sources/Untracked.swift"], generation.sha256(b"helper"))
        self.assertEqual(result["sourceFiles"]["Package.swift"], generation.sha256(b"manifest"))

    def test_json_schema_runtime_override_has_separate_provenance(self):
        with patch.dict(generation.os.environ, {"JSON_SCHEMA_RUNTIME_PATH": "/example/schema"}, clear=True):
            with patch.object(
                generation, "repository_provenance",
                side_effect=[{"revision": "generator"}, {"revision": "schema", "uncommittedSources": True}],
            ):
                result = generation.generator_provenance(Path("/example/generator"), True)
        self.assertEqual(
            result["dependencyOverrides"],
            {"JSON_SCHEMA_RUNTIME_PATH": {"revision": "schema", "uncommittedSources": True}},
        )

    def test_sdk_runtime_override_has_separate_provenance(self):
        with patch.dict(generation.os.environ, {"OPENAI_RESPONSES_RUNTIME_PATH": "/example/runtime"}, clear=True):
            with patch.object(
                generation, "repository_provenance",
                side_effect=[{"revision": "generator"}, {"revision": "runtime", "uncommittedSources": True}],
            ):
                result = generation.generator_provenance(Path("/example/generator"), True)
        self.assertEqual(
            result["sdkRuntimeOverride"],
            {"revision": "runtime", "uncommittedSources": True},
        )

    def test_local_dependency_override_has_separate_provenance(self):
        with patch.dict(generation.os.environ, {"JSON_SCHEMA_CODEGEN_PATH": "/example/core"}, clear=True):
            with patch.object(
                generation, "repository_provenance",
                side_effect=[{"revision": "generator"}, {"revision": "core", "uncommittedSources": True}],
            ):
                result = generation.generator_provenance(Path("/example/generator"), True)
        self.assertEqual(
            result["dependencyOverrides"],
            {"JSON_SCHEMA_CODEGEN_PATH": {"revision": "core", "uncommittedSources": True}},
        )

    def test_uncommitted_sources_require_explicit_opt_in(self):
        with patch.object(generation, "git", side_effect=[generation.GENERATOR_REPOSITORY, " M Sources/Example.swift"]):
            with self.assertRaisesRegex(ValueError, "uncommitted changes"):
                generation.repository_provenance(
                    Path("/example/generator"), generation.GENERATOR_REPOSITORY, False
                )


if __name__ == "__main__":
    unittest.main()
