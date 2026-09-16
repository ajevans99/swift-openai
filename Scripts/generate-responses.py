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

    paths = ["Package.swift", "Package.resolved", "Sources"]
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


def generator_provenance(package, allow_uncommitted):
    result = repository_provenance(package, GENERATOR_REPOSITORY, allow_uncommitted)
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
        after = generator_provenance(package, args.allow_uncommitted_generator)
        if before != after:
            raise RuntimeError(
                "Generator sources or dependency resolution changed during generation; "
                "review the changes and rerun"
            )
        if input_hashes != [sha256(path.read_bytes()) for path in input_paths]:
            raise RuntimeError("Generation driver, pinned source, or profile changed during generation; rerun")

        data = generated.read_bytes()
        if not data:
            raise RuntimeError("Generator produced an empty Swift source file")

        provenance = {
            "version": 1,
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
        LOCAL_PROVENANCE.parent.mkdir(parents=True, exist_ok=True)
        LOCAL_PROVENANCE.write_text(json.dumps({
            "generator": after,
            "command": command,
            "swiftToolchain": subprocess.check_output(["swift", "--version"], text=True).strip(),
        }, indent=2) + "\n")


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
