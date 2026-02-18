#!/usr/bin/env bash
set -euo pipefail

SPEC_URL="https://app.stainless.com/api/spec/documented/openai/openapi.documented.yml"

# Figure out the repo root
GIT_ROOT="$(git rev-parse --show-toplevel)"

# Destination directory under the repo
TARGET_DIR="$GIT_ROOT/Sources/OpenAIFoundation"

# Output files
OUTPUT="$TARGET_DIR/openapi.yaml"
COMMIT_FILE="$TARGET_DIR/openapi.commit"

hash_file() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
  else
    openssl dgst -sha256 "$file" | awk '{print $NF}'
  fi
}

TMP_FILE="$(mktemp)"
trap 'rm -f "$TMP_FILE"' EXIT

echo "▶ Fetching OpenAPI spec from $SPEC_URL"
curl -fsSL "$SPEC_URL" -o "$TMP_FILE"
mv "$TMP_FILE" "$OUTPUT"
echo "✅ Spec saved."

SPEC_SHA256="$(hash_file "$OUTPUT")"
echo "✅ Spec SHA256: $SPEC_SHA256"

# Write the hash alongside the spec.
echo "$SPEC_SHA256" > "$COMMIT_FILE"
echo "✅ Wrote spec hash to $COMMIT_FILE"
