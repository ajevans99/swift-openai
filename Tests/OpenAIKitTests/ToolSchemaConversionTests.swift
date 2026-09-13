import CustomDump
import Foundation
import JSONSchema
import JSONSchemaBuilder
import OpenAPIRuntime
import Testing

@testable import OpenAIKit

@Suite("Tool Schema Conversion")
struct ToolSchemaConversionTests {
  @Test(
    "Supported numbers preserve their mathematical value through OpenAPI encoding",
    arguments: [
      "0", "-0.0", "0e999999999999999999999", "1.0", "1E+2",
      "9007199254740993", "9223372036854775807", "-9223372036854775808",
      "9223372036854775807.0", "0.1", "-0.125", "1e20", "1e100",
      "1e-300", "5e-324", "1.7976931348623157e308",
    ]
  )
  func supportedNumbersRoundTrip(literal: String) throws {
    let source = JSONValue.numberLiteral(try JSONNumberLiteral(literal))
    let container = try OpenAPIValueContainer(jsonValue: source)
    let encoded = try JSONEncoder().encode(container)

    expectNoDifference(try JSONValue.parse(encoded), source)
  }

  @Test("Integer conversion is preferred, including values beyond Double's exact integer range")
  func prefersExactIntegers() throws {
    for integer in [Int.min, -1, 0, 1, 9_007_199_254_740_993, Int.max] {
      let value = try JSONNumberLiteral("\(integer).0")
      let container = try OpenAPIValueContainer(jsonValue: .numberLiteral(value))

      expectNoDifference(container.value as? Int, integer)
    }
  }

  @Test(
    "Unsupported precision, overflow, and underflow throw instead of rounding",
    arguments: [
      "18446744073709551615", "9223372036854775808", "-9223372036854775809",
      "9007199254740993.1", "1.0000000000000000001", "1.234567890123456789",
      "1e309", "-1e309", "1e-324", "-1e-324",
      "1e999999999999999999999", "1e-999999999999999999999",
    ]
  )
  func unsupportedNumbersThrow(literal: String) throws {
    let number = try JSONNumberLiteral(literal)
    #expect(throws: ToolSchemaConversionError.unsupportedNumber(number)) {
      try OpenAPIValueContainer(jsonValue: .numberLiteral(number))
    }
  }

  @Test("Decimal-only precision is rejected because OpenAPI does not support Decimal")
  func decimalOnlyPrecisionThrows() throws {
    let number = try JSONNumberLiteral("1.0000000000000000001")
    expectNoDifference(try JSONNumberLiteral(number.decimalValue()), number)
    #expect(throws: ToolSchemaConversionError.unsupportedNumber(number)) {
      try OpenAPIValueContainer(jsonValue: .numberLiteral(number))
    }
  }

  @Test("Nested arrays and objects preserve numbers and nonnumeric values")
  func nestedValuesRoundTrip() throws {
    let source = try JSONValue.parse(
      Data(#"{"items":[null,true,false,"text",9007199254740993,{"fraction":0.1}],"empty":{}}"#.utf8)
    )
    let container = try OpenAPIValueContainer(jsonValue: source)

    expectNoDifference(try JSONValue.parse(JSONEncoder().encode(container)), source)
  }

  @Test("Nested unsupported numbers propagate through both public tool conversions")
  func nestedErrorsPropagate() throws {
    let number = try JSONNumberLiteral("1e-999")
    let tool = LiteralSchemaTool(
      schema: .object([
        "type": .string("object"),
        "properties": .object([
          "amount": .object(["enum": .array([.numberLiteral(number)])])
        ]),
      ])
    )

    #expect(throws: ToolSchemaConversionError.unsupportedNumber(number)) {
      try tool.toFunctionTool()
    }
    #expect(throws: ToolSchemaConversionError.unsupportedNumber(number)) {
      try tool.toTool()
    }
  }

  @Test("Function tool parameters preserve exact schema constraints on the wire")
  func functionToolParametersRoundTrip() throws {
    let constraint = JSONValue.numberLiteral(try JSONNumberLiteral("9007199254740993"))
    let tool = LiteralSchemaTool(schema: .object(["minimum": constraint]))
    let parameters = try #require(tool.toFunctionTool().toOpenAPI().parameters)

    expectNoDifference(
      try JSONValue.parse(JSONEncoder().encode(parameters)),
      .object(["minimum": constraint])
    )
    _ = try tool.toTool()
  }

  @Test("Boolean root schemas throw rather than trapping", arguments: [true, false])
  func booleanRootsThrow(value: Bool) {
    let tool = LiteralSchemaTool(schema: .boolean(value))
    #expect(throws: ToolSchemaConversionError.unsupportedRootSchema) {
      try tool.toFunctionTool()
    }
    #expect(throws: ToolSchemaConversionError.unsupportedRootSchema) {
      try tool.toTool()
    }
  }
}

struct LiteralSchemaTool: Toolable {
  let name = "literal-schema"
  let description: String? = nil
  let strict = false
  let schema: SchemaValue

  var parameters: JSONAnyValue {
    var component = JSONAnyValue()
    component.schemaValue = schema
    return component
  }

  func call(parameters: JSONValue) async throws -> String {
    "{}"
  }
}
