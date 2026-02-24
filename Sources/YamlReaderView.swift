import SwiftUI
import Yams

/// Parses YAML text and reuses the structured data rendering pipeline
struct YamlReaderView: View {
    let yamlText: String
    
    @State private var parsed: Any?
    @State private var parseError: String?
    
    /// Extract leading comment block from YAML source
    private var headerComments: [String] {
        var comments: [String] = []
        for line in yamlText.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") {
                // Strip leading # and optional space
                let text = String(trimmed.dropFirst()).trimmingCharacters(in: .init(charactersIn: " "))
                if !text.isEmpty { comments.append(text) }
            } else if trimmed.isEmpty {
                continue
            } else {
                break
            }
        }
        return comments
    }
    
    var body: some View {
        GeometryReader { geo in
            ScrollView {
                let insetX = Self.calcInsetX(geo.size.width)
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
                        // Show YAML header comments if present
                        if !headerComments.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(Array(headerComments.enumerated()), id: \.offset) { _, line in
                                    Text(line)
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(nsColor: DesignTokens.secondaryColor))
                                }
                            }
                            .padding(.bottom, 16)
                        }
                        StructuredDataView(value: value)
                    }
                }
                .padding(.horizontal, insetX)
                .padding(.vertical, 32)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: DesignTokens.isDark ? NSColor(white: 0.08, alpha: 1) : .white))
        .onAppear { parse() }
        .onChange(of: yamlText) { _, _ in parse() }
    }
    
    /// Same centering logic as MarkdownEditorView.calcInsetX
    private static func calcInsetX(_ scrollWidth: CGFloat) -> CGFloat {
        let contentWidth = min(DesignTokens.maxContentWidth, scrollWidth - 80)
        let effectiveWidth = max(contentWidth, 300)
        return max(40, (scrollWidth - effectiveWidth) / 2)
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
