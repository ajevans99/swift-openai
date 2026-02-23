#!/usr/bin/env bash
set -euo pipefail

GIT_ROOT="$(git rev-parse --show-toplevel)"
TYPES_FILE="$GIT_ROOT/Sources/OpenAIFoundation/Generated/Types.swift"

if [[ ! -f "$TYPES_FILE" ]]; then
  echo "❌ Generated file not found: $TYPES_FILE"
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

  before="$(hash_file "$TYPES_FILE")"
  perl -0777 -i -pe "$perl_expr" "$TYPES_FILE"
  after="$(hash_file "$TYPES_FILE")"

  if [[ "$before" == "$after" ]]; then
    echo "• $name (no changes)"
  else
    echo "✓ $name"
  fi
}

echo "▶ Applying deterministic generated-source transforms"

# swift-openapi-generator currently emits schema-name discriminators for this union,
# but the API returns wire values like `output_text` and `refusal`.
apply_transform \
  "accept wire output-content discriminator values" \
  's/case "OutputTextContent", "#\/components\/schemas\/OutputTextContent":/case "output_text", "OutputTextContent", "#\/components\/schemas\/OutputTextContent":/g;
   s/case "RefusalContent", "#\/components\/schemas\/RefusalContent":/case "refusal", "RefusalContent", "#\/components\/schemas\/RefusalContent":/g;
   s/case "ReasoningTextContent", "#\/components\/schemas\/ReasoningTextContent":/case "reasoning_text", "ReasoningTextContent", "#\/components\/schemas\/ReasoningTextContent":/g;'

# The generator emits schema-name discriminator cases for Tool, but the API returns
# wire values like `image_generation` in `response.created` / `response.in_progress`.
apply_transform \
  "accept wire tool discriminator values" \
  's/case "FunctionTool", "#\/components\/schemas\/FunctionTool":/case "function", "FunctionTool", "#\/components\/schemas\/FunctionTool":/g;
   s/case "FileSearchTool", "#\/components\/schemas\/FileSearchTool":/case "file_search", "FileSearchTool", "#\/components\/schemas\/FileSearchTool":/g;
   s/case "ComputerUsePreviewTool", "#\/components\/schemas\/ComputerUsePreviewTool":/case "computer_use_preview", "ComputerUsePreviewTool", "#\/components\/schemas\/ComputerUsePreviewTool":/g;
   s/case "WebSearchTool", "#\/components\/schemas\/WebSearchTool":/case "web_search", "web_search_2025_08_26", "WebSearchTool", "#\/components\/schemas\/WebSearchTool":/g;
   s/case "MCPTool", "#\/components\/schemas\/MCPTool":/case "mcp", "MCPTool", "#\/components\/schemas\/MCPTool":/g;
   s/case "CodeInterpreterTool", "#\/components\/schemas\/CodeInterpreterTool":/case "code_interpreter", "CodeInterpreterTool", "#\/components\/schemas\/CodeInterpreterTool":/g;
   s/case "ImageGenTool", "#\/components\/schemas\/ImageGenTool":/case "image_generation", "ImageGenTool", "#\/components\/schemas\/ImageGenTool":/g;
   s/case "LocalShellToolParam", "#\/components\/schemas\/LocalShellToolParam":/case "local_shell", "LocalShellToolParam", "#\/components\/schemas\/LocalShellToolParam":/g;
   s/case "FunctionShellToolParam", "#\/components\/schemas\/FunctionShellToolParam":/case "shell", "FunctionShellToolParam", "#\/components\/schemas\/FunctionShellToolParam":/g;
   s/case "CustomToolParam", "#\/components\/schemas\/CustomToolParam":/case "custom", "CustomToolParam", "#\/components\/schemas\/CustomToolParam":/g;
   s/case "WebSearchPreviewTool", "#\/components\/schemas\/WebSearchPreviewTool":/case "web_search_preview", "web_search_preview_2025_03_11", "WebSearchPreviewTool", "#\/components\/schemas\/WebSearchPreviewTool":/g;
   s/case "ApplyPatchToolParam", "#\/components\/schemas\/ApplyPatchToolParam":/case "apply_patch", "ApplyPatchToolParam", "#\/components\/schemas\/ApplyPatchToolParam":/g;'

# The OpenAI spec defines FunctionTool with `description`, `parameters`, and
# `strict`, but the generator currently emits only `type` + `name`.
# Add the missing fields so tool schemas are transmitted to the model.
apply_transform \
  "add missing FunctionTool fields" \
  's/public struct FunctionTool: Codable, Hashable, Sendable \{\n(\s*\/\/\/ The type of the function tool\. Always `function`\.[\s\S]*?\s*public var name: Swift\.String\n)\s*\/\/\/ Creates a new `FunctionTool`\.[\s\S]*?\s*public enum CodingKeys: String, CodingKey \{\n\s*case _type = "type"\n\s*case name\n\s*\}\n\s*\}/public struct FunctionTool: Codable, Hashable, Sendable {\n$1            \/\/\/ A description of the function. Used by the model to determine whether or not to call the function.\n            \/\/\/\n            \/\/\/ - Remark: Added by swift-openai patch: missing generated field from FunctionTool schema.\n            public var description: Swift.String?\n            \/\/\/ A JSON schema object describing the parameters of the function.\n            \/\/\/\n            \/\/\/ - Remark: Added by swift-openai patch: missing generated field from FunctionTool schema.\n            public var parameters: OpenAPIRuntime.OpenAPIObjectContainer?\n            \/\/\/ Whether to enforce strict parameter validation. Default `true`.\n            \/\/\/\n            \/\/\/ - Remark: Added by swift-openai patch: missing generated field from FunctionTool schema.\n            public var strict: Swift.Bool?\n            \/\/\/ Creates a new `FunctionTool`.\n            \/\/\/\n            \/\/\/ - Parameters:\n            \/\/\/   - _type: The type of the function tool. Always `function`.\n            \/\/\/   - name: The name of the function to call.\n            \/\/\/   - description: A description of the function.\n            \/\/\/   - parameters: A JSON schema object describing the parameters of the function.\n            \/\/\/   - strict: Whether to enforce strict parameter validation.\n            public init(\n                _type: Components.Schemas.FunctionTool._TypePayload,\n                name: Swift.String,\n                description: Swift.String? = nil,\n                parameters: OpenAPIRuntime.OpenAPIObjectContainer? = nil,\n                strict: Swift.Bool? = nil\n            ) {\n                self._type = _type\n                self.name = name\n                self.description = description\n                self.parameters = parameters\n                self.strict = strict\n            }\n            public enum CodingKeys: String, CodingKey {\n                case _type = "type"\n                case name\n                case description\n                case parameters\n                case strict\n            }\n        }/s;'

# Some CreateResponse value3 fields are dropped by the generator from the
# nullable anyOf form in the upstream spec. Add `previous_response_id` and
# `stream` so follow-up tool turns remain linked and streaming requests
# actually send `"stream": true`.
apply_transform \
  "add missing CreateResponse.value3 linkage/stream fields" \
  's/public struct Value3Payload: Codable, Hashable, Sendable \{\n(\s*\/\/\/ - Remark: Generated from `#\/components\/schemas\/CreateResponse\/value3\/input`\.\n\s*public var input: Components\.Schemas\.InputParam\?\n)\s*\/\/\/ Creates a new `Value3Payload`\.\n\s*\/\/\/\n\s*\/\/\/ - Parameters:\n\s*\/\/\/   - input:\n\s*public init\(input: Components\.Schemas\.InputParam\? = nil\) \{\n\s*self\.input = input\n\s*\}\n\s*public enum CodingKeys: String, CodingKey \{\n\s*case input\n\s*\}\n\s*\}/public struct Value3Payload: Codable, Hashable, Sendable {\n$1            \/\/\/ - Remark: Added by swift-openai patch: missing previous response linkage in generated schema.\n            public var previousResponseId: Swift.String?\n            \/\/\/ - Remark: Added by swift-openai patch: missing stream flag in generated schema.\n            public var stream: Swift.Bool?\n            \/\/\/ Creates a new `Value3Payload`.\n            \/\/\/\n            \/\/\/ - Parameters:\n            \/\/\/   - input:\n            \/\/\/   - previousResponseId:\n            \/\/\/   - stream:\n            public init(\n                input: Components.Schemas.InputParam? = nil,\n                previousResponseId: Swift.String? = nil,\n                stream: Swift.Bool? = nil\n            ) {\n                self.input = input\n                self.previousResponseId = previousResponseId\n                self.stream = stream\n            }\n            public enum CodingKeys: String, CodingKey {\n                case input\n                case previousResponseId = \"previous_response_id\"\n                case stream\n            }\n        }/s;'

echo "✅ Generated-source transforms complete."
