import copy
import importlib.util
import json
from pathlib import Path
import subprocess
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
        resolution = patch.object(
            generation, "resolution_provenance", return_value={"lockSHA256": "resolved-lock"}
        )
        self.resolution_provenance = resolution.start()
        self.addCleanup(resolution.stop)

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

    def test_toolchain_resolution_is_audited_without_portable_source_drift(self):
        generation.generate(self.args, self.source)
        first = self.provenance.read_bytes()
        self.resolution_provenance.return_value = {
            "lockSHA256": "swift-6.1-resolved-lock", "swiftToolchain": "Swift 6.1",
        }
        self.args.check = True
        generation.generate(self.args, self.source)
        self.assertEqual(self.provenance.read_bytes(), first)
        local = json.loads(generation.LOCAL_PROVENANCE.read_text())
        self.assertEqual(local["resolution"], self.resolution_provenance.return_value)

    def test_resolution_change_during_run_writes_no_artifacts(self):
        for key in ("lockSHA256", "dependencies", "swiftToolchain"):
            with self.subTest(changed=key):
                self.resolution_provenance.side_effect = [{key: "before"}, {key: "after"}]
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
    def setUp(self):
        lock = patch.object(
            generation, "committed_dependency_lock",
            return_value={"sha256": "committed-lock", "contents": {"pins": []}},
        )
        lock.start()
        self.addCleanup(lock.stop)

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


class PublishedSourceTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.package = Path(temporary.name)
        (self.package / "Sources").mkdir()
        (self.package / "Sources" / "Client.swift").write_text("// Client\n")
        (self.package / "Package.swift").write_text("// Manifest\n")
        self.lock = b'{"version":3,"pins":[]}\n'
        (self.package / "Package.resolved").write_bytes(self.lock)
        for arguments in (
            ["init", "--quiet"],
            ["remote", "add", "origin", generation.GENERATOR_REPOSITORY],
            ["add", "."],
            ["-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
             "commit", "--quiet", "-m", "Fixture"],
        ):
            subprocess.run(["git", "-C", str(self.package), *arguments], check=True)
        environment = patch.dict(generation.os.environ, {}, clear=True)
        environment.start()
        self.addCleanup(environment.stop)

    def test_lock_only_resolution_keeps_exact_committed_source_identity(self):
        before = generation.generator_provenance(self.package, False)
        (self.package / "Package.resolved").write_text('{"version":3,"pins":[],"originHash":"resolved"}')
        after = generation.generator_provenance(self.package, False)
        self.assertEqual(before, after)
        self.assertFalse(after["uncommittedSources"])
        self.assertEqual(after["committedDependencyLock"]["sha256"], generation.sha256(self.lock))
        self.assertEqual(after["committedDependencyLock"]["contents"], json.loads(self.lock))

    def test_source_and_manifest_changes_remain_rejected(self):
        for name in ("Sources/Client.swift", "Package.swift", "Package@swift-6.1.swift"):
            with self.subTest(file=name):
                path = self.package / name
                original = path.read_bytes() if path.exists() else None
                path.write_bytes(b"changed")
                with self.assertRaisesRegex(ValueError, "uncommitted changes"):
                    generation.generator_provenance(self.package, False)
                if original is None:
                    path.unlink()
                else:
                    path.write_bytes(original)


class ResolutionTests(unittest.TestCase):
    def setUp(self):
        self.package = Path("/example/generator")
        self.pins = {
            identity: {
                "identity": identity, "kind": "remoteSourceControl",
                "location": f"https://example.invalid/{identity}.git",
                "state": {"revision": "a" * 40, "version": "1.0.0"},
            }
            for identity in sorted(generation.REQUIRED_DEPENDENCIES | {"transitive"})
        }
        self.lock = {"version": 3, "pins": list(self.pins.values())}
        self.tree = {
            "path": str(self.package),
            "dependencies": [
                {
                    "identity": identity, "path": str(self.package / identity),
                    "url": pin["location"], "version": pin["state"]["version"],
                    "dependencies": [],
                }
                for identity, pin in self.pins.items()
            ],
        }
        git = patch.object(
            generation, "git",
            side_effect=lambda _, *args: "a" * 40 if args == ("rev-parse", "HEAD") else "",
        )
        self.git = git.start()
        self.addCleanup(git.stop)

    def test_graph_matches_every_remote_pin_and_checkout(self):
        generation.verify_required_pins(self.pins, self.pins, {})
        dependencies = generation.verify_resolved_graph(self.tree, self.lock, self.package, {})
        self.assertEqual(set(dependencies), set(self.pins))

    def test_required_dependency_changes_or_missing_pins_fail(self):
        for identity in generation.REQUIRED_DEPENDENCIES:
            for field in ("revision", "version", "location", "kind", "missing"):
                with self.subTest(identity=identity, field=field):
                    changed = copy.deepcopy(self.pins)
                    if field == "missing":
                        del changed[identity]
                    elif field in ("revision", "version"):
                        changed[identity]["state"][field] = "unexpected"
                    else:
                        changed[identity][field] = "unexpected"
                    with self.assertRaisesRegex(ValueError, "required dependency|Required dependency"):
                        generation.verify_required_pins(changed, self.pins, {})

    def test_transitive_resolution_may_differ_but_must_match_actual_lock(self):
        changed = copy.deepcopy(self.pins)
        changed["transitive"]["state"]["version"] = "2.0.0"
        generation.verify_required_pins(changed, self.pins, {})
        lock = {"pins": list(changed.values())}
        with self.assertRaisesRegex(ValueError, "does not match its lock"):
            generation.verify_resolved_graph(self.tree, lock, self.package, {})
        next(node for node in self.tree["dependencies"] if node["identity"] == "transitive")["version"] = "2.0.0"
        generation.verify_resolved_graph(self.tree, lock, self.package, {})

    def test_toolchain_can_replace_a_transitive_package_identity(self):
        changed = copy.deepcopy(self.pins)
        replacement = changed.pop("transitive")
        replacement["identity"] = "toolchain-alternative"
        replacement["location"] = "https://example.invalid/toolchain-alternative.git"
        changed[replacement["identity"]] = replacement
        generation.verify_required_pins(changed, self.pins, {})
        node = next(node for node in self.tree["dependencies"] if node["identity"] == "transitive")
        node["identity"] = replacement["identity"]
        node["url"] = replacement["location"]
        generation.verify_resolved_graph(self.tree, {"pins": list(changed.values())}, self.package, {})

    def test_wrong_checkout_revision_and_dirty_dependencies_fail(self):
        self.git.side_effect = lambda _, *args: "b" * 40 if args == ("rev-parse", "HEAD") else ""
        with self.assertRaisesRegex(ValueError, "does not match its lock"):
            generation.verify_resolved_graph(self.tree, self.lock, self.package, {})
        self.git.side_effect = lambda _, *args: "a" * 40 if args == ("rev-parse", "HEAD") else " M Package.swift"
        with self.assertRaisesRegex(ValueError, "checkout is modified"):
            generation.verify_resolved_graph(self.tree, self.lock, self.package, {})

    def test_graph_must_include_exact_lock_identities_and_required_dependencies(self):
        self.tree["dependencies"].pop()
        with self.assertRaisesRegex(ValueError, "different identities"):
            generation.verify_resolved_graph(self.tree, self.lock, self.package, {})
        self.tree["dependencies"] = []
        with self.assertRaisesRegex(ValueError, "missing required"):
            generation.verify_resolved_graph(self.tree, self.lock, self.package, {})

    def test_unapproved_local_override_is_rejected(self):
        self.tree["dependencies"][0]["url"] = "/unexpected/local/checkout"
        with self.assertRaisesRegex(ValueError, "does not match its lock"):
            generation.verify_resolved_graph(self.tree, self.lock, self.package, {})

    def test_capture_retains_literal_lock_hash_contents_graph_and_toolchain(self):
        with tempfile.TemporaryDirectory() as temporary:
            package = Path(temporary)
            self.tree["path"] = str(package)
            data = (json.dumps(self.lock, indent=2) + "\n").encode()
            (package / "Package.resolved").write_bytes(data)
            args = SimpleNamespace(scratch_path=package / "build")
            generator = {"committedDependencyLock": {"contents": self.lock}}
            with patch.dict(generation.os.environ, {}, clear=True), patch.object(
                generation.subprocess, "check_output",
                side_effect=[json.dumps(self.tree), "Swift 6.1\n"],
            ):
                result = generation.resolution_provenance(package, args, generator)
        self.assertEqual(result["lockSHA256"], generation.sha256(data))
        self.assertEqual(result["lock"], self.lock)
        self.assertEqual(set(result["dependencies"]), set(self.pins))
        self.assertEqual(result["swiftToolchain"], "Swift 6.1")


if __name__ == "__main__":
    unittest.main()
