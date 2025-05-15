#!/usr/bin/env bash
set -euo pipefail

# Locate repo root
GIT_ROOT="$(git rev-parse --show-toplevel)"

# Define where patches live and where the spec lives
PATCH_DIR="$GIT_ROOT/Patches"
TARGET_DIR="$GIT_ROOT/Sources/OpenAIModels"
TARGET_FILE="openapi.yaml"

# Sanity checks
if [[ ! -d "$PATCH_DIR" ]]; then
  echo "❌ Patches directory not found: $PATCH_DIR"
  exit 1
fi
if [[ ! -f "$TARGET_DIR/$TARGET_FILE" ]]; then
  echo "❌ Spec file not found: $TARGET_DIR/$TARGET_FILE"
  exit 1
fi

# Apply patches
pushd "$TARGET_DIR" > /dev/null
for patch in "$PATCH_DIR"/*.patch; do
  [[ -e "$patch" ]] || { echo "No patch files in $PATCH_DIR"; break; }
  echo "▶ Applying $(basename "$patch")"
  patch -u "$TARGET_FILE" < "$patch"
done
popd > /dev/null

echo "✅ All patches applied."
