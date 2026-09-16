#!/usr/bin/env python3
"""Generate the opt-in Responses client without modifying the legacy pipeline."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import urllib.request


ROOT = Path(__file__).resolve().parent.parent
INPUTS = ROOT / "Generation" / "OpenAIResponses"
OUTPUT = ROOT / "Sources" / "OpenAIResponses" / "Generated" / "OpenAIResponsesAPI.swift"
PROVENANCE = INPUTS / "generation.json"
LOCAL_PROVENANCE = ROOT / ".build" / "responses-generation-local.json"
GENERATOR_REPOSITORY = "https://github.com/ajevans99/swift-openapi-schema-codegen"
NAMESPACE = "OpenAIResponsesAPI"
OPERATION = "createResponse"
REQUIRED_DEPENDENCIES = {
    "swift-json-schema", "swift-json-schema-codegen", "swift-openapi-schema",
}
DEPENDENCY_OVERRIDES = {
    "JSON_SCHEMA_CODEGEN_PATH": "swift-json-schema-codegen",
    "OPENAPI_SCHEMA_PATH": "swift-openapi-schema",
    "JSON_SCHEMA_RUNTIME_PATH": "swift-json-schema",
}


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def verify_inputs(fetch=False):
    source = json.loads((INPUTS / "source.json").read_text())
    if source["version"] != 1:
        raise ValueError("Unsupported source provenance version")

    for key in ("specification", "license"):
        asset = source[key]
        path = INPUTS / asset["path"]
        if path.parent != INPUTS:
            raise ValueError(f"Asset path must be directly inside {INPUTS}")
        data = (
            urllib.request.urlopen(asset["url"], timeout=60).read()
            if fetch
            else path.read_bytes()
        )
        actual = sha256(data)
        if actual != asset["sha256"]:
            raise ValueError(f"{key} SHA256 mismatch: expected {asset['sha256']}, got {actual}")
        if fetch:
            path.write_bytes(data)

    return source


def git(package, *arguments):
    return subprocess.check_output(
        ["git", "-C", str(package), *arguments], text=True
    ).strip()


def repository_provenance(package, expected_repository, allow_uncommitted):
    repository = git(package, "remote", "get-url", "origin")
    repository = repository.removesuffix(".git").replace(
        "git@github.com:", "https://github.com/"
    )
    if repository != expected_repository:
        raise ValueError(f"Unexpected generator repository: {repository}")

    paths = [":(top,glob)Package*.swift", "Sources"]
    changes = git(package, "status", "--porcelain", "--", *paths)
    if changes and not allow_uncommitted:
        raise ValueError(
            "Generator sources have uncommitted changes; publish/pin them first, or use "
            "--allow-uncommitted-generator explicitly for development"
        )

    names = subprocess.check_output(
        ["git", "-C", str(package), "ls-files", "-z", "--cached", "--others",
         "--exclude-standard", "--", *paths]
    ).split(b"\0")
    files = {}
    for raw_name in sorted(set(names) - {b""}):
        name = raw_name.decode()
        path = package / name
        files[name] = sha256(path.read_bytes()) if path.is_file() else None

    return {
        "repository": repository,
        "revision": git(package, "rev-parse", "HEAD"),
        "resolvedPath": str(package.resolve()),
        "uncommittedSources": bool(changes),
        "sourceFiles": files,
        "sourceSHA256": sha256(
            json.dumps(files, sort_keys=True, separators=(",", ":")).encode()
        ),
    }


def committed_dependency_lock(package):
    data = subprocess.check_output(
        ["git", "-C", str(package), "show", "HEAD:Package.resolved"]
    )
    return {"sha256": sha256(data), "contents": json.loads(data)}


def generator_provenance(package, allow_uncommitted):
    result = repository_provenance(package, GENERATOR_REPOSITORY, allow_uncommitted)
    result["committedDependencyLock"] = committed_dependency_lock(package)
    result["dependencyOverrides"] = {}
    for variable, repository in {
        "JSON_SCHEMA_CODEGEN_PATH": "https://github.com/ajevans99/swift-json-schema-codegen",
        "OPENAPI_SCHEMA_PATH": "https://github.com/ajevans99/swift-openapi-schema",
        "JSON_SCHEMA_RUNTIME_PATH": "https://github.com/ajevans99/swift-json-schema",
    }.items():
        if variable not in os.environ:
            continue
        if not os.environ[variable]:
            raise ValueError(f"{variable} must be unset or contain a package path")
        result["dependencyOverrides"][variable] = repository_provenance(
            Path(os.environ[variable]).resolve(), repository, allow_uncommitted
        )
    result["sdkRuntimeOverride"] = None
    if "OPENAI_RESPONSES_RUNTIME_PATH" in os.environ:
        if not os.environ["OPENAI_RESPONSES_RUNTIME_PATH"]:
            raise ValueError("OPENAI_RESPONSES_RUNTIME_PATH must be unset or contain a package path")
        result["sdkRuntimeOverride"] = repository_provenance(
            Path(os.environ["OPENAI_RESPONSES_RUNTIME_PATH"]).resolve(),
            GENERATOR_REPOSITORY,
            allow_uncommitted,
        )
    return result


def verify_required_pins(pins, committed_pins, overrides):
    for identity in sorted(REQUIRED_DEPENDENCIES - overrides.keys()):
        if identity not in pins or identity not in committed_pins:
            raise ValueError(f"Missing required dependency: {identity}")
        if pins[identity] != committed_pins[identity]:
            raise ValueError(f"Required dependency differs from published generator lock: {identity}")


def verify_resolved_graph(tree, lock, package, overrides):
    pins = {entry["identity"]: entry for entry in lock["pins"]}
    dependencies = {}

    def visit(node):
        identity = node["identity"]
        path = Path(node["path"]).resolve()
        if identity in overrides:
            if path != overrides[identity]:
                raise ValueError(f"Dependency override resolves to an unexpected checkout: {identity}")
            revision = git(path, "rev-parse", "HEAD")
        else:
            pin = pins.get(identity)
            if (
                pin is None
                or pin["kind"] != "remoteSourceControl"
                or node["url"] != pin["location"]
                or node["version"] != pin["state"].get("version", "unspecified")
                or git(path, "rev-parse", "HEAD") != pin["state"]["revision"]
            ):
                raise ValueError(f"Resolved dependency does not match its lock: {identity}")
            if git(path, "status", "--porcelain", "--untracked-files=all"):
                raise ValueError(f"Resolved dependency checkout is modified: {identity}")
            revision = pin["state"]["revision"]
        record = {
            "identity": identity, "url": node["url"], "version": node["version"],
            "revision": revision, "resolvedPath": str(path),
        }
        if identity in dependencies and dependencies[identity] != record:
            raise ValueError(f"Conflicting resolved dependency identity: {identity}")
        dependencies[identity] = record
        for child in node["dependencies"]:
            visit(child)

    if Path(tree["path"]).resolve() != package.resolve():
        raise ValueError("Resolved graph belongs to a different generator checkout")
    for dependency in tree["dependencies"]:
        visit(dependency)
    if not REQUIRED_DEPENDENCIES <= dependencies.keys():
        raise ValueError("Resolved graph is missing required generator dependencies")
    if set(pins) - overrides.keys() != dependencies.keys() - overrides.keys():
        raise ValueError("Resolved dependency graph and lock contain different identities")
    return dependencies


def resolution_provenance(package, args, generator):
    tree = json.loads(subprocess.check_output([
        "swift", "package", "--package-path", str(package),
        "--scratch-path", str(args.scratch_path.resolve()),
        "show-dependencies", "--format", "json",
    ], text=True))
    data = (package / "Package.resolved").read_bytes()
    lock = json.loads(data)
    pins = {entry["identity"]: entry for entry in lock["pins"]}
    committed_pins = {
        entry["identity"]: entry
        for entry in generator["committedDependencyLock"]["contents"]["pins"]
    }
    overrides = {
        identity: Path(os.environ[variable]).resolve()
        for variable, identity in DEPENDENCY_OVERRIDES.items()
        if variable in os.environ
    }
    verify_required_pins(pins, committed_pins, overrides)
    dependencies = verify_resolved_graph(tree, lock, package, overrides)
    return {
        "lockSHA256": sha256(data),
        "lock": lock,
        "dependencies": dependencies,
        "swiftToolchain": subprocess.check_output(["swift", "--version"], text=True).strip(),
    }


def portable_provenance(value):
    if isinstance(value, dict):
        return {
            key: portable_provenance(item)
            for key, item in value.items()
            if key != "resolvedPath"
        }
    return value


def generate(args, source):
    package = args.generator_package.resolve()
    before = generator_provenance(package, args.allow_uncommitted_generator)
    profile = INPUTS / "profile.json"
    input_paths = [
        Path(__file__).resolve(),
        INPUTS / "source.json", profile,
        INPUTS / source["specification"]["path"],
        INPUTS / source["license"]["path"],
    ]
    input_hashes = [sha256(path.read_bytes()) for path in input_paths]
    resolution_before = resolution_provenance(package, args, before)

    with tempfile.TemporaryDirectory(prefix="openai-responses-") as temporary:
        generated = Path(temporary) / OUTPUT.name
        command = [
            "swift", "run", "--package-path", str(package),
            "--scratch-path", str(args.scratch_path.resolve()),
            "--jobs", str(args.jobs),
        ]
        if args.build_system:
            command += ["--build-system", args.build_system]
        command += [
            "openapi-json-codegen",
            str(INPUTS / source["specification"]["path"]),
            "--operation", OPERATION,
            "--profile", str(profile),
            "--namespace", NAMESPACE,
            "--output", str(generated),
        ]
        subprocess.run(command, check=True, cwd=ROOT)
        resolution_after = resolution_provenance(package, args, before)
        after = generator_provenance(package, args.allow_uncommitted_generator)
        if before != after:
            raise RuntimeError(
                "Generator sources or dependency resolution changed during generation; "
                "review the changes and rerun"
            )
        if resolution_before != resolution_after:
            raise RuntimeError("Resolved dependency lock, graph, or toolchain changed during generation; rerun")
        if input_hashes != [sha256(path.read_bytes()) for path in input_paths]:
            raise RuntimeError("Generation driver, pinned source, or profile changed during generation; rerun")

        data = generated.read_bytes()
        if not data:
            raise RuntimeError("Generator produced an empty Swift source file")

        provenance = {
            "version": 2,
            "driverSHA256": input_hashes[0],
            "generator": portable_provenance(after),
            "specificationSHA256": source["specification"]["sha256"],
            "licenseSHA256": source["license"]["sha256"],
            "profileSHA256": sha256(profile.read_bytes()),
            "namespace": NAMESPACE,
            "operationIDs": [OPERATION],
            "output": {
                "path": str(OUTPUT.relative_to(ROOT)),
                "sha256": sha256(data),
            },
        }
        metadata = (json.dumps(provenance, indent=2) + "\n").encode()
        LOCAL_PROVENANCE.parent.mkdir(parents=True, exist_ok=True)
        LOCAL_PROVENANCE.write_text(json.dumps({
            "generator": after,
            "command": command,
            "resolution": resolution_after,
            "generation": provenance,
        }, indent=2) + "\n")
        if args.check:
            if not OUTPUT.is_file() or OUTPUT.read_bytes() != data:
                raise RuntimeError("Generated Responses Swift source has drifted")
            if not PROVENANCE.is_file() or PROVENANCE.read_bytes() != metadata:
                raise RuntimeError("Responses generation provenance has drifted")
            print("Responses source and provenance match regeneration")
        else:
            OUTPUT.parent.mkdir(parents=True, exist_ok=True)
            OUTPUT.write_bytes(data)
            PROVENANCE.write_bytes(metadata)
            print(f"Generated {OUTPUT.relative_to(ROOT)}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--fetch-inputs", action="store_true", help="Fetch and verify pinned assets only")
    mode.add_argument("--verify-inputs", action="store_true", help="Verify pinned assets offline only")
    mode.add_argument("--check", action="store_true", help="Regenerate into a temporary directory and compare")
    parser.add_argument("--generator-package", type=Path, help="Checkout of the pinned generator package")
    parser.add_argument("--scratch-path", type=Path, default=ROOT / ".build" / "responses-generator",
                        help="SDK-owned SwiftPM generator build cache")
    parser.add_argument("--jobs", type=int, default=1, help="Maximum concurrent generator build jobs")
    parser.add_argument("--build-system", choices=["native", "swiftbuild"],
                        help="Override the Swift toolchain's default build backend")
    parser.add_argument("--allow-uncommitted-generator", action="store_true",
                        help="Record the source digest of an unpublished development generator")
    args = parser.parse_args()
    if args.jobs < 1:
        parser.error("--jobs must be positive")
    if not (args.fetch_inputs or args.verify_inputs or args.generator_package):
        parser.error("--generator-package is required for generation and drift checks")
    source = verify_inputs(fetch=args.fetch_inputs)
    if args.fetch_inputs or args.verify_inputs:
        print("Pinned OpenAI specification and license hashes match")
        return
    generate(args, source)


if __name__ == "__main__":
    main()
