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

# Newer generator output also includes `defer_loading`; preserve it while
# restoring the nullable fields omitted from the schema.
apply_transform \
  "add missing FunctionTool fields with deferLoading" \
  's{public struct FunctionTool: Codable, Hashable, Sendable \{\n            /// The type of the function tool\. Always `function`\.[\s\S]*?            public var name: Swift\.String\n            /// Whether this function is deferred and loaded via tool search\.\n            ///\n            /// - Remark: Generated from `#/components/schemas/FunctionTool/defer_loading`\.\n            public var deferLoading: Swift\.Bool\?\n            /// Creates a new `FunctionTool`\.[\s\S]*?            public enum CodingKeys: String, CodingKey \{\n                case _type = "type"\n                case name\n                case deferLoading = "defer_loading"\n            \}\n        \}}{public struct FunctionTool: Codable, Hashable, Sendable {\n            /// The type of the function tool. Always `function`.\n            ///\n            /// - Remark: Generated from `#/components/schemas/FunctionTool/type`.\n            @frozen public enum _TypePayload: String, Codable, Hashable, Sendable, CaseIterable {\n                case function = "function"\n            }\n            /// The type of the function tool. Always `function`.\n            ///\n            /// - Remark: Generated from `#/components/schemas/FunctionTool/type`.\n            public var _type: Components.Schemas.FunctionTool._TypePayload\n            /// The name of the function to call.\n            ///\n            /// - Remark: Generated from `#/components/schemas/FunctionTool/name`.\n            public var name: Swift.String\n            /// A description of the function. Used by the model to determine whether or not to call the function.\n            ///\n            /// - Remark: Restored by swift-openai patch from nullable anyOf schema.\n            public var description: Swift.String?\n            /// A JSON schema object describing the parameters of the function.\n            ///\n            /// - Remark: Restored by swift-openai patch from nullable anyOf schema.\n            public var parameters: OpenAPIRuntime.OpenAPIObjectContainer?\n            /// Whether to enforce strict parameter validation. Default `true`.\n            ///\n            /// - Remark: Restored by swift-openai patch from nullable anyOf schema.\n            public var strict: Swift.Bool?\n            /// Whether this function is deferred and loaded via tool search.\n            ///\n            /// - Remark: Generated from `#/components/schemas/FunctionTool/defer_loading`.\n            public var deferLoading: Swift.Bool?\n            /// Creates a new `FunctionTool`.\n            ///\n            /// - Parameters:\n            ///   - _type: The type of the function tool. Always `function`.\n            ///   - name: The name of the function to call.\n            ///   - description: A description of the function.\n            ///   - parameters: A JSON schema object describing the parameters of the function.\n            ///   - strict: Whether to enforce strict parameter validation.\n            ///   - deferLoading: Whether this function is deferred and loaded via tool search.\n            public init(\n                _type: Components.Schemas.FunctionTool._TypePayload,\n                name: Swift.String,\n                description: Swift.String? = nil,\n                parameters: OpenAPIRuntime.OpenAPIObjectContainer? = nil,\n                strict: Swift.Bool? = nil,\n                deferLoading: Swift.Bool? = nil\n            ) {\n                self._type = _type\n                self.name = name\n                self.description = description\n                self.parameters = parameters\n                self.strict = strict\n                self.deferLoading = deferLoading\n            }\n            public enum CodingKeys: String, CodingKey {\n                case _type = "type"\n                case name\n                case description\n                case parameters\n                case strict\n                case deferLoading = "defer_loading"\n            }\n        }}s;'

# Some CreateResponse value3 fields are dropped by the generator from the
# nullable anyOf form in the upstream spec. Add `previous_response_id` and
# `stream` so follow-up tool turns remain linked and streaming requests
# actually send `"stream": true`.
apply_transform \
  "add missing CreateResponse.value3 linkage/stream fields" \
  's/public struct Value3Payload: Codable, Hashable, Sendable \{\n(\s*\/\/\/ - Remark: Generated from `#\/components\/schemas\/CreateResponse\/value3\/input`\.\n\s*public var input: Components\.Schemas\.InputParam\?\n)\s*\/\/\/ Creates a new `Value3Payload`\.\n\s*\/\/\/\n\s*\/\/\/ - Parameters:\n\s*\/\/\/   - input:\n\s*public init\(input: Components\.Schemas\.InputParam\? = nil\) \{\n\s*self\.input = input\n\s*\}\n\s*public enum CodingKeys: String, CodingKey \{\n\s*case input\n\s*\}\n\s*\}/public struct Value3Payload: Codable, Hashable, Sendable {\n$1            \/\/\/ - Remark: Added by swift-openai patch: missing previous response linkage in generated schema.\n            public var previousResponseId: Swift.String?\n            \/\/\/ - Remark: Added by swift-openai patch: missing stream flag in generated schema.\n            public var stream: Swift.Bool?\n            \/\/\/ Creates a new `Value3Payload`.\n            \/\/\/\n            \/\/\/ - Parameters:\n            \/\/\/   - input:\n            \/\/\/   - previousResponseId:\n            \/\/\/   - stream:\n            public init(\n                input: Components.Schemas.InputParam? = nil,\n                previousResponseId: Swift.String? = nil,\n                stream: Swift.Bool? = nil\n            ) {\n                self.input = input\n                self.previousResponseId = previousResponseId\n                self.stream = stream\n            }\n            public enum CodingKeys: String, CodingKey {\n                case input\n                case previousResponseId = \"previous_response_id\"\n                case stream\n            }\n        }/s;'

# The OpenAI API may omit `detail` for input images; default to `.auto` on decode.
apply_transform \
  "default InputImageContent.detail to auto" \
  's/(public struct InputImageContent: Codable, Hashable, Sendable \{[\s\S]*?public enum CodingKeys: String, CodingKey \{\n\s*case _type = \"type\"\n\s*case detail\n\s*case imageUrl = \"image_url\"\n\s*case fileId = \"file_id\"\n\s*\}\n)(\s*\})/$1\n            public init(from decoder: any Decoder) throws {\n                let container = try decoder.container(keyedBy: CodingKeys.self)\n                self._type = try container.decode(Components.Schemas.InputImageContent._TypePayload.self, forKey: ._type)\n                self.detail = try container.decodeIfPresent(Components.Schemas.ImageDetail.self, forKey: .detail) ?? .auto\n                self.imageUrl = try container.decodeIfPresent(Swift.String.self, forKey: .imageUrl)\n                self.fileId = try container.decodeIfPresent(Swift.String.self, forKey: .fileId)\n            }\n\n            public func encode(to encoder: any Encoder) throws {\n                var container = encoder.container(keyedBy: CodingKeys.self)\n                try container.encode(self._type, forKey: ._type)\n                try container.encode(self.detail, forKey: .detail)\n                try container.encodeIfPresent(self.imageUrl, forKey: .imageUrl)\n                try container.encodeIfPresent(self.fileId, forKey: .fileId)\n            }\n$2/s;'

# Newer generator output drops `image_url` / `file_id` entirely for this type.
apply_transform \
  "restore InputImageContent image refs" \
  's{public struct InputImageContent: Codable, Hashable, Sendable \{\n            /// The type of the input item\. Always `input_image`\.[\s\S]*?            public var detail: Components\.Schemas\.ImageDetail\n            /// Creates a new `InputImageContent`\.\n            ///\n            /// - Parameters:\n            ///   - _type: The type of the input item\. Always `input_image`\.\n            ///   - detail: The detail level of the image to be sent to the model\. One of `high`, `low`, `auto`, or `original`\. Defaults to `auto`\.\n            public init\(\n                _type: Components\.Schemas\.InputImageContent\._TypePayload,\n                detail: Components\.Schemas\.ImageDetail\n            \) \{\n                self\._type = _type\n                self\.detail = detail\n            \}\n            public enum CodingKeys: String, CodingKey \{\n                case _type = "type"\n                case detail\n            \}\n        \}}{public struct InputImageContent: Codable, Hashable, Sendable {\n            /// The type of the input item. Always `input_image`.\n            ///\n            /// - Remark: Generated from `#/components/schemas/InputImageContent/type`.\n            @frozen public enum _TypePayload: String, Codable, Hashable, Sendable, CaseIterable {\n                case inputImage = "input_image"\n            }\n            /// The type of the input item. Always `input_image`.\n            ///\n            /// - Remark: Generated from `#/components/schemas/InputImageContent/type`.\n            public var _type: Components.Schemas.InputImageContent._TypePayload\n            /// The detail level of the image to be sent to the model. One of `high`, `low`, `auto`, or `original`. Defaults to `auto`.\n            ///\n            /// - Remark: Generated from `#/components/schemas/InputImageContent/detail`.\n            public var detail: Components.Schemas.ImageDetail\n            /// The URL of the image to be sent to the model. A fully qualified URL or base64 encoded image in a data URL.\n            ///\n            /// - Remark: Restored by swift-openai patch from nullable anyOf schema.\n            public var imageUrl: Swift.String?\n            /// The ID of the file to be sent to the model.\n            ///\n            /// - Remark: Restored by swift-openai patch from nullable anyOf schema.\n            public var fileId: Swift.String?\n            /// Creates a new `InputImageContent`.\n            ///\n            /// - Parameters:\n            ///   - _type: The type of the input item. Always `input_image`.\n            ///   - detail: The detail level of the image to be sent to the model. One of `high`, `low`, `auto`, or `original`. Defaults to `auto`.\n            ///   - imageUrl: The URL of the image to be sent to the model.\n            ///   - fileId: The ID of the file to be sent to the model.\n            public init(\n                _type: Components.Schemas.InputImageContent._TypePayload,\n                detail: Components.Schemas.ImageDetail,\n                imageUrl: Swift.String? = nil,\n                fileId: Swift.String? = nil\n            ) {\n                self._type = _type\n                self.detail = detail\n                self.imageUrl = imageUrl\n                self.fileId = fileId\n            }\n            public enum CodingKeys: String, CodingKey {\n                case _type = "type"\n                case detail\n                case imageUrl = "image_url"\n                case fileId = "file_id"\n            }\n\n            public init(from decoder: any Decoder) throws {\n                let container = try decoder.container(keyedBy: CodingKeys.self)\n                self._type = try container.decode(Components.Schemas.InputImageContent._TypePayload.self, forKey: ._type)\n                self.detail = try container.decodeIfPresent(Components.Schemas.ImageDetail.self, forKey: .detail) ?? .auto\n                self.imageUrl = try container.decodeIfPresent(Swift.String.self, forKey: .imageUrl)\n                self.fileId = try container.decodeIfPresent(Swift.String.self, forKey: .fileId)\n            }\n\n            public func encode(to encoder: any Encoder) throws {\n                var container = encoder.container(keyedBy: CodingKeys.self)\n                try container.encode(self._type, forKey: ._type)\n                try container.encode(self.detail, forKey: .detail)\n                try container.encodeIfPresent(self.imageUrl, forKey: .imageUrl)\n                try container.encodeIfPresent(self.fileId, forKey: .fileId)\n            }\n        }}s;'

# Newer generator output drops `file_id` from InputFileContent.
apply_transform \
  "restore InputFileContent fileId property" \
  's/public var _type: Components\.Schemas\.InputFileContent\._TypePayload\n            \/\/\/ The name of the file to be sent to the model\./public var _type: Components.Schemas.InputFileContent._TypePayload\n            \/\/\/ The ID of the file to be sent to the model.\n            \/\/\/\n            \/\/\/ - Remark: Restored by swift-openai patch from nullable anyOf schema.\n            public var fileId: Swift.String?\n            \/\/\/ The name of the file to be sent to the model./s;'

apply_transform \
  "restore InputFileContent fileId init" \
  's/public init\(\n                _type: Components\.Schemas\.InputFileContent\._TypePayload,\n                filename: Swift\.String\? = nil,\n                fileData: Swift\.String\? = nil,\n                fileUrl: Swift\.String\? = nil,\n                detail: Components\.Schemas\.FileInputDetail\? = nil\n            \) \{\n                self\._type = _type\n                self\.filename = filename\n                self\.fileData = fileData\n                self\.fileUrl = fileUrl\n                self\.detail = detail\n            \}/public init(\n                _type: Components.Schemas.InputFileContent._TypePayload,\n                fileId: Swift.String? = nil,\n                filename: Swift.String? = nil,\n                fileData: Swift.String? = nil,\n                fileUrl: Swift.String? = nil,\n                detail: Components.Schemas.FileInputDetail? = nil\n            ) {\n                self._type = _type\n                self.fileId = fileId\n                self.filename = filename\n                self.fileData = fileData\n                self.fileUrl = fileUrl\n                self.detail = detail\n            }/s;'

apply_transform \
  "restore InputFileContent fileId coding key" \
  's/public enum CodingKeys: String, CodingKey \{\n                case _type = "type"\n                case filename\n/public enum CodingKeys: String, CodingKey {\n                case _type = "type"\n                case fileId = "file_id"\n                case filename\n/s;'

TYPES_FILE="$TYPES_FILE" python3 - <<'PY'
import os
from pathlib import Path

path = Path(os.environ["TYPES_FILE"])
text = path.read_text()


def replace_once(name: str, old: str, new: str) -> None:
    global text
    if old in text:
        text = text.replace(old, new, 1)
        print(f"✓ {name}")
    elif new in text:
        print(f"• {name} (already applied)")
    else:
        print(f"• {name} (no changes)")


def replace_required_once(name: str, old: str, new: str) -> None:
    global text
    if old in text:
        text = text.replace(old, new, 1)
        print(f"✓ {name}")
    elif new in text:
        print(f"• {name} (already applied)")
    else:
        raise RuntimeError(f"{name}: required generated patch target not found")


replace_required_once(
    "restore Reasoning request fields",
    """public struct Reasoning: Codable, Hashable, Sendable {
            /// Creates a new `Reasoning`.
            public init() {}
        }""",
    """public enum ReasoningEffort: String, Codable, Hashable, Sendable, CaseIterable {
            case none = "none"
            case minimal = "minimal"
            case low = "low"
            case medium = "medium"
            case high = "high"
            case xhigh = "xhigh"
        }
        public struct Reasoning: Codable, Hashable, Sendable {
            @frozen public enum SummaryPayload: String, Codable, Hashable, Sendable, CaseIterable {
                case auto = "auto"
                case concise = "concise"
                case detailed = "detailed"
            }
            /// Constrains effort on reasoning for reasoning models.
            ///
            /// - Remark: Restored by swift-openai patch from nullable anyOf schema.
            public var effort: Components.Schemas.ReasoningEffort?
            /// A summary of the reasoning performed by the model.
            ///
            /// - Remark: Restored by swift-openai patch from nullable anyOf schema.
            public var summary: Components.Schemas.Reasoning.SummaryPayload?
            /// Deprecated: use `summary` instead.
            ///
            /// - Remark: Restored by swift-openai patch from nullable anyOf schema.
            public var generateSummary: Swift.String?
            /// Creates a new `Reasoning`.
            ///
            /// - Parameters:
            ///   - effort: Constrains effort on reasoning for reasoning models.
            ///   - summary: A summary of the reasoning performed by the model.
            ///   - generateSummary: Deprecated reasoning summary setting.
            public init(
                effort: Components.Schemas.ReasoningEffort? = nil,
                summary: Swift.String? = nil,
                generateSummary: Swift.String? = nil
            ) {
                self.effort = effort
                self.summary = summary.flatMap(Components.Schemas.Reasoning.SummaryPayload.init(rawValue:))
                self.generateSummary = generateSummary
            }
            public enum CodingKeys: String, CodingKey {
                case effort
                case summary
                case generateSummary = "generate_summary"
            }
        }""",
)

replace_required_once(
    "restore ResponseProperties request fields",
    """public struct ResponseProperties: Codable, Hashable, Sendable {
            /// Model ID used to generate the response, like `gpt-4o` or `o3`. OpenAI
            /// offers a wide range of models with different capabilities, performance
            /// characteristics, and price points. Refer to the [model guide](/docs/models)
            /// to browse and compare available models.
            ///
            ///
            /// - Remark: Generated from `#/components/schemas/ResponseProperties/model`.
            public var model: Components.Schemas.ModelIdsResponses?
            /// - Remark: Generated from `#/components/schemas/ResponseProperties/text`.
            public var text: Components.Schemas.ResponseTextParam?
            /// - Remark: Generated from `#/components/schemas/ResponseProperties/tools`.
            public var tools: Components.Schemas.ToolsArray?
            /// - Remark: Generated from `#/components/schemas/ResponseProperties/tool_choice`.
            public var toolChoice: Components.Schemas.ToolChoiceParam?
            /// Creates a new `ResponseProperties`.
            ///
            /// - Parameters:
            ///   - model: Model ID used to generate the response, like `gpt-4o` or `o3`. OpenAI
            ///   - text:
            ///   - tools:
            ///   - toolChoice:
            public init(
                model: Components.Schemas.ModelIdsResponses? = nil,
                text: Components.Schemas.ResponseTextParam? = nil,
                tools: Components.Schemas.ToolsArray? = nil,
                toolChoice: Components.Schemas.ToolChoiceParam? = nil
            ) {
                self.model = model
                self.text = text
                self.tools = tools
                self.toolChoice = toolChoice
            }
            public enum CodingKeys: String, CodingKey {
                case model
                case text
                case tools
                case toolChoice = "tool_choice"
            }
        }""",
    """public struct ResponseProperties: Codable, Hashable, Sendable {
            @frozen public enum TruncationPayload: String, Codable, Hashable, Sendable, CaseIterable {
                case auto = "auto"
                case disabled = "disabled"
            }
            /// The unique ID of the previous response to the model.
            ///
            /// - Remark: Restored by swift-openai patch from nullable anyOf schema.
            public var previousResponseId: Swift.String?
            /// Model ID used to generate the response, like `gpt-4o` or `o3`.
            ///
            /// - Remark: Generated from `#/components/schemas/ResponseProperties/model`.
            public var model: Components.Schemas.ModelIdsResponses?
            /// Reasoning configuration for the response.
            ///
            /// - Remark: Restored by swift-openai patch from nullable anyOf schema.
            public var reasoning: Components.Schemas.Reasoning?
            /// An upper bound for generated output tokens.
            ///
            /// - Remark: Restored by swift-openai patch from nullable anyOf schema.
            public var maxOutputTokens: Swift.Int?
            /// A system or developer message inserted into the model context.
            ///
            /// - Remark: Restored by swift-openai patch from CreateResponse schema.
            public var instructions: Swift.String?
            /// - Remark: Generated from `#/components/schemas/ResponseProperties/text`.
            public var text: Components.Schemas.ResponseTextParam?
            /// - Remark: Generated from `#/components/schemas/ResponseProperties/tools`.
            public var tools: Components.Schemas.ToolsArray?
            /// - Remark: Generated from `#/components/schemas/ResponseProperties/tool_choice`.
            public var toolChoice: Components.Schemas.ToolChoiceParam?
            /// The truncation strategy to use for the model response.
            ///
            /// - Remark: Restored by swift-openai patch from nullable anyOf schema.
            public var truncation: Components.Schemas.ResponseProperties.TruncationPayload?
            /// Creates a new `ResponseProperties`.
            public init(
                previousResponseId: Swift.String? = nil,
                model: Components.Schemas.ModelIdsResponses? = nil,
                reasoning: Components.Schemas.Reasoning? = nil,
                maxOutputTokens: Swift.Int? = nil,
                instructions: Swift.String? = nil,
                text: Components.Schemas.ResponseTextParam? = nil,
                tools: Components.Schemas.ToolsArray? = nil,
                toolChoice: Components.Schemas.ToolChoiceParam? = nil,
                truncation: Components.Schemas.ResponseProperties.TruncationPayload? = nil
            ) {
                self.previousResponseId = previousResponseId
                self.model = model
                self.reasoning = reasoning
                self.maxOutputTokens = maxOutputTokens
                self.instructions = instructions
                self.text = text
                self.tools = tools
                self.toolChoice = toolChoice
                self.truncation = truncation
            }
            public enum CodingKeys: String, CodingKey {
                case previousResponseId = "previous_response_id"
                case model
                case reasoning
                case maxOutputTokens = "max_output_tokens"
                case instructions
                case text
                case tools
                case toolChoice = "tool_choice"
                case truncation
            }
        }""",
)

replace_required_once(
    "restore CreateResponse value3 request fields",
    """public struct Value3Payload: Codable, Hashable, Sendable {
                /// - Remark: Generated from `#/components/schemas/CreateResponse/value3/input`.
                public var input: Components.Schemas.InputParam?
            /// - Remark: Added by swift-openai patch: missing previous response linkage in generated schema.
            public var previousResponseId: Swift.String?
            /// - Remark: Added by swift-openai patch: missing stream flag in generated schema.
            public var stream: Swift.Bool?
            /// Creates a new `Value3Payload`.
            ///
            /// - Parameters:
            ///   - input:
            ///   - previousResponseId:
            ///   - stream:
            public init(
                input: Components.Schemas.InputParam? = nil,
                previousResponseId: Swift.String? = nil,
                stream: Swift.Bool? = nil
            ) {
                self.input = input
                self.previousResponseId = previousResponseId
                self.stream = stream
            }
            public enum CodingKeys: String, CodingKey {
                case input
                case previousResponseId = "previous_response_id"
                case stream
            }
        }""",
    """public struct Value3Payload: Codable, Hashable, Sendable {
                /// - Remark: Generated from `#/components/schemas/CreateResponse/value3/input`.
                public var input: Components.Schemas.InputParam?
                /// Specify additional output data to include in the model response.
                ///
                /// - Remark: Restored by swift-openai patch from nullable anyOf schema.
                public var include: [Components.Schemas.IncludeEnum]?
                /// Whether to allow the model to run tool calls in parallel.
                ///
                /// - Remark: Restored by swift-openai patch from nullable anyOf schema.
                public var parallelToolCalls: Swift.Bool?
                /// Whether to store the generated model response for later retrieval.
                ///
                /// - Remark: Restored by swift-openai patch from nullable anyOf schema.
                public var store: Swift.Bool?
                /// A system or developer message inserted into the model context.
                ///
                /// - Remark: Restored by swift-openai patch from nullable anyOf schema.
                public var instructions: Swift.String?
                /// - Remark: Added by swift-openai patch: missing previous response linkage in generated schema.
                public var previousResponseId: Swift.String?
                /// - Remark: Added by swift-openai patch: missing stream flag in generated schema.
                public var stream: Swift.Bool?
                /// Creates a new `Value3Payload`.
                public init(
                    input: Components.Schemas.InputParam? = nil,
                    include: [Components.Schemas.IncludeEnum]? = nil,
                    parallelToolCalls: Swift.Bool? = nil,
                    store: Swift.Bool? = nil,
                    instructions: Swift.String? = nil,
                    previousResponseId: Swift.String? = nil,
                    stream: Swift.Bool? = nil
                ) {
                    self.input = input
                    self.include = include
                    self.parallelToolCalls = parallelToolCalls
                    self.store = store
                    self.instructions = instructions
                    self.previousResponseId = previousResponseId
                    self.stream = stream
                }
                public enum CodingKeys: String, CodingKey {
                    case input
                    case include
                    case parallelToolCalls = "parallel_tool_calls"
                    case store
                    case instructions
                    case previousResponseId = "previous_response_id"
                    case stream
                }
            }""",
)

path.write_text(text)
PY

echo "✅ Generated-source transforms complete."
