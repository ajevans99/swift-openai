import OpenAICore

extension OutputContent {
  var text: String {
    switch self {
    case .text(let text): return text.text
    case .refusal(let refusal): return "[Refusal] \(refusal.refusal)"
    }
  }
}
