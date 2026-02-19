#!/usr/bin/env bash
set -euo pipefail

GIT_ROOT="$(git rev-parse --show-toplevel)"
SPEC_FILE="$GIT_ROOT/Sources/OpenAIFoundation/openapi.yaml"

if [[ ! -f "$SPEC_FILE" ]]; then
  echo "❌ Spec file not found: $SPEC_FILE"
  exit 1
fi

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

apply_transform() {
  local name="$1"
  local perl_expr="$2"
  local before after

  before="$(hash_file "$SPEC_FILE")"
  perl -0777 -i -pe "$perl_expr" "$SPEC_FILE"
  after="$(hash_file "$SPEC_FILE")"

  if [[ "$before" == "$after" ]]; then
    echo "• $name (no changes)"
  else
    echo "✓ $name"
  fi
}

echo "▶ Applying deterministic OpenAPI transforms"

# swift-openapi-generator currently rejects the top-level webhooks section.
apply_transform \
  "remove unsupported top-level webhooks section" \
  's/^webhooks:\n.*?(?=^components:\n)//ms'

# swift-openapi-generator expects numeric bounds for exclusive min/max.
apply_transform \
  "normalize exclusive numeric bounds" \
  's/^(\s*)minimum:\s*(-?(?:\d+(?:\.\d+)?))\s*\n((?:\1maximum:\s*-?(?:\d+(?:\.\d+)?)\s*\n)?)\1exclusiveMinimum:\s*true\s*$/\1minimum: $2\n$3\1exclusiveMinimum: $2/mg;
   s/^(\s*)maximum:\s*(-?(?:\d+(?:\.\d+)?))\s*\n\1exclusiveMaximum:\s*true\s*$/\1maximum: $2\n\1exclusiveMaximum: $2/mg;'

# Ensure multipart image edit uploads have explicit image/mask content types.
apply_transform \
  "add image-edit multipart encoding" \
  's{(operationId:\s*createImageEdit\n.*?multipart/form-data:\n\s+schema:\n\s+\$ref:\s*\'"'"'#/components/schemas/CreateImageEditRequest\'"'"'\n)(\s+)examples:}{$1$2encoding:\n$2  image:\n$2    contentType: image/png\n$2  mask:\n$2    contentType: image/png\n$2examples:}s'

# Preserve final image payloads for image_generation_call in generated types.
# The upstream anyOf(string|null) currently drops `result` in Swift generation.
apply_transform \
  "normalize ImageGenToolCall.result for Swift generation" \
  's{(\n\s+ImageGenToolCall:\n.*?\n\s+result:\n)\s+anyOf:\n\s+- type: string\n\s+description: \|\n\s+The generated image encoded in base64\.\n\s+- type: '\''null'\''}{$1          type: string\n          description: |\n            The generated image encoded in base64.}s;
   s{(\n\s+ImageGenToolCall:\n.*?\n\s+required:\n\s+- type\n\s+- id\n\s+- status\n)\s+- result\n}{$1}s'

echo "✅ OpenAPI transforms complete."
