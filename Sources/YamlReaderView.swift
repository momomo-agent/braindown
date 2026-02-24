import SwiftUI
import Yams

/// Parses YAML text and reuses the structured data rendering pipeline
struct YamlReaderView: View {
    let yamlText: String
    
    @State private var parsed: Any?
    @State private var parseError: String?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let error = parseError {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text(error)
                            .foregroundColor(Color(nsColor: DesignTokens.bodyColor))
                    }
                    .padding()
                } else if let value = parsed {
                    StructuredDataView(value: value)
                }
            }
            .padding(.horizontal, 48)
            .padding(.vertical, 32)
            .frame(maxWidth: DesignTokens.maxContentWidth + 96, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: DesignTokens.isDark ? NSColor(white: 0.08, alpha: 1) : .white))
        .onAppear { parse() }
        .onChange(of: yamlText) { _, _ in parse() }
    }
    
    private func parse() {
        do {
            let result = try Yams.load(yaml: yamlText)
            parsed = normalizeYams(result)
            parseError = nil
        } catch {
            parseError = error.localizedDescription
            parsed = nil
        }
    }
    
    /// Yams returns [String: Any?] and [Any?], normalize to non-optional
    private func normalizeYams(_ value: Any?) -> Any {
        if let dict = value as? [String: Any?] {
            var out: [String: Any] = [:]
            for (k, v) in dict {
                out[k] = normalizeYams(v)
            }
            return out
        }
        if let arr = value as? [Any?] {
            return arr.map { normalizeYams($0) }
        }
        return value ?? "null"
    }
}
