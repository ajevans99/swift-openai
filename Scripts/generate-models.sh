#!/usr/bin/env bash
set -euo pipefail

GIT_ROOT="$(git rev-parse --show-toplevel)"
if [[ -z "$GIT_ROOT" ]]; then
  echo "❌ Not inside a Git repo."
  exit 1
fi

SPEC="$GIT_ROOT/Sources/OpenAIModels/openapi.yaml"
CONFIG="$GIT_ROOT/Sources/OpenAIModels/openapi-generator-config.yaml"
OUT_DIR="$GIT_ROOT/Sources/OpenAIModels/Generated"

# Sanity checks
if [[ ! -f "$SPEC" ]]; then
  echo "❌ Spec not found at $SPEC"
  exit 1
fi
if [[ ! -f "$CONFIG" ]]; then
  echo "❌ Config not found at $CONFIG"
  exit 1
fi
mkdir -p "$OUT_DIR"

# Run the generator
echo "▶ Generating models from $SPEC"
swift run swift-openapi-generator generate \
  "$SPEC" \
  --config "$CONFIG" \
  --output-directory "$OUT_DIR"

echo "✅ Models generated into $OUT_DIR"
