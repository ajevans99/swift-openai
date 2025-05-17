# Swift OpenAI

[![CI](https://github.com/ajevans99/swift-openai/actions/workflows/swift.yml/badge.svg)](https://github.com/ajevans99/swift-openai/actions/workflows/swift.yml)

A modern Swift package for interacting with OpenAI’s API, built on top of the official OpenAI spec.

This library is a thin, ergonomic layer over types and endpoints generated via [swift-openapi-generator](https://github.com/apple/swift-openapi-generator). It provides a more convenient and opinionated interface for Swift developers interacting with the [OpenAI REST endpoints](https://platform.openai.com/docs/api-reference).

## Features

- Full [Responses](https://platform.openai.com/docs/api-reference/responses) Endpoint Support - Convenient wrappers around the `/responses` endpoint that embraces Swift idioms and concurrency practices, including streaming.
- Type-Safe Tool Calling – Seamless integration with [swift-json-schema](https://github.com/ajevans99/swift-json-schema), enabling robust OpenAI tool support with Swift-native types and validation.
- Transport Layer Agnostic - Bring your own HTTP client. The packge is decoupled from specific networking libraries. Choose your own [`ClientTransport`](https://github.com/apple/swift-openapi-generator?tab=readme-ov-file#package-ecosystem).

## Basic Usage

## Tool Calling

## Examples

Checkout the [Example CLI Project](Example) for some more sample usages.

## Code Genertion

> [!NOTE]
> This section is only relevant for library maintainers. If you're just using the package, you can skip this.

`swift-openai` uses `swift-openapi-generator` to generate models and endpoint definitions directly from OpenAI’s official [openapi.yaml](https://github.com/openai/openai-openapi). This ensures maximum compatibility and future-proofing as the spec evolves.

To ensure the generated code compiles and behaves correctly in Swift, we apply a series of patch files located in the `Patches/` directory to the `swift-openapi.yaml` spec. These are applied before generation via a custom script. This workaround is necessary because the raw OpenAPI spec includes some constructs that are either unsupported or problematic for the Swift OpenAPI toolchain.

| Task                                    | Command          |
|-----------------------------------------|------------------|
| To check for spec changes               | `make check`     |
| To fetch the latest `openapi.yaml`      | `make fetch`     |
| To apply the necessary patches          | `make patches`   |
| To generate the Swift types             | `make generate`  |
| To fetch, patch, and generate           | `make all`       |

To generate patches, make changes to the yaml and run:

```sh
git diff Sources/OpenAIModels/openapi.yaml > Patches/<two-digit-sort-number-here>-<patch-description-here>.patch
```
