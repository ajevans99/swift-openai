#!/usr/bin/env bash
set -euo pipefail

# Variables
REPO="https://github.com/openai/openai-openapi.git"
REF="refs/heads/master"
RAW_URL="https://raw.githubusercontent.com/openai/openai-openapi/${REF}/openapi.yaml"

# Figure out the repo root
GIT_ROOT="$(git rev-parse --show-toplevel)"

# Destination directory under the repo
TARGET_DIR="$GIT_ROOT/Sources/OpenAIModels"

# Output files
OUTPUT="$TARGET_DIR/openapi.yaml"
COMMIT_FILE="$TARGET_DIR/openapi.commit"

echo "▶ Fetching OpenAPI spec into $OUTPUT"
curl -sL "$RAW_URL" -o "$OUTPUT"
echo "✅ Spec saved."

echo "▶ Resolving latest commit SHA on '$REF'"
COMMIT=$(git ls-remote "$REPO" "$REF" | awk '{print $1}')
if [[ -z "$COMMIT" ]]; then
  echo "❌ Failed to get commit SHA" >&2
  exit 1
fi
echo "✅ Latest commit on $REF is $COMMIT"

# Write the SHA alongside the spec
echo "$COMMIT" > "$COMMIT_FILE"
echo "✅ Wrote commit SHA to $COMMIT_FILE"
