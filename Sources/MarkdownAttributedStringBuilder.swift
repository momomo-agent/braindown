import AppKit
import Highlightr

/// Converts parsed MarkdownNodes into a single NSAttributedString for read-only display.
class MarkdownAttributedStringBuilder {
    
    static func build(from nodes: [MarkdownNode], fileDirectory: URL?) -> NSAttributedString {
        let result = NSMutableAttributedString()
        
        var i = 0
        while i < nodes.count {
            let node = nodes[i]
            
            switch node.type {
            case .heading(let level):
                if result.length > 0 { result.append(newline(level <= 2 ? 24 : 16)) }
                result.append(headingString(node: node, level: level))
                if level <= 2 { result.append(newline(4)) }
                
            case .paragraph:
                if result.length > 0 { result.append(newline(8)) }
                result.append(paragraphString(node: node))
                
            case .codeBlock(let language):
                if result.length > 0 { result.append(newline(8)) }
                result.append(codeBlockString(code: node.content, language: language))
                
            case .blockquote:
                if result.length > 0 { result.append(newline(8)) }
                result.append(blockquoteString(node: node))
                
            case .unorderedList:
                var items: [MarkdownNode] = []
                var j = i + 1
                while j < nodes.count, case .listItem(let ordered, _) = nodes[j].type, !ordered {
                    items.append(nodes[j]); j += 1
                }
                if result.length > 0 { result.append(newline(8)) }
                result.append(listString(items: items, ordered: false))
                i = j; continue
                
            case .orderedList:
                var items: [MarkdownNode] = []
                var j = i + 1
                while j < nodes.count, case .listItem(let ordered, _) = nodes[j].type, ordered {
                    items.append(nodes[j]); j += 1
                }
                if result.length > 0 { result.append(newline(8)) }
                result.append(listString(items: items, ordered: true))
                i = j; continue
                
            case .table:
                if result.length > 0 { result.append(newline(8)) }
                result.append(tableString(node: node))
                
            case .horizontalRule:
                if result.length > 0 { result.append(newline(12)) }
                result.append(ruleString())
                result.append(newline(12))
                
            case .listItem, .blank:
                break
            }
            i += 1
        }
        
        return result
    }
    
    // MARK: - Heading
    
    private static func headingString(node: MarkdownNode, level: Int) -> NSAttributedString {
        let font = DesignTokens.headingFont(level: level)
        let color = level == 6 ? DesignTokens.secondaryColor : DesignTokens.headingColor
        return DesignTokens.attributedString(from: node.inlineElements, font: font, color: color, lineHeightMultiple: 1.3)
    }
    
    // MARK: - Paragraph
    
    private static func paragraphString(node: MarkdownNode) -> NSAttributedString {
        return DesignTokens.attributedString(from: node.inlineElements, font: DesignTokens.bodyFont, color: DesignTokens.bodyColor)
    }
    
    // MARK: - Code Block
    
    private static func codeBlockString(code: String, language: String?) -> NSAttributedString {
        let isDark = DesignTokens.isDark
        let codeFont = DesignTokens.codeFont
        let themeName = isDark ? "atom-one-dark" : "atom-one-light"
        
        let h = Highlightr()
        h?.setTheme(to: themeName)
        h?.theme.codeFont = codeFont
        
        let result = NSMutableAttributedString()
        if let h = h, let hl = h.highlight(code, as: language?.lowercased()) {
            let m = NSMutableAttributedString(attributedString: hl)
            m.removeAttribute(.backgroundColor, range: NSRange(location: 0, length: m.length))
            result.append(m)
        } else {
            let fallback: NSColor = isDark ? NSColor(white: 0.8, alpha: 1) : NSColor(white: 0.2, alpha: 1)
            result.append(NSAttributedString(string: code, attributes: [.font: codeFont, .foregroundColor: fallback]))
        }
        
        // Add background color for the whole code block
        result.addAttribute(.backgroundColor, value: DesignTokens.codeBackground, range: NSRange(location: 0, length: result.length))
        
        let paraStyle = NSMutableParagraphStyle()
        paraStyle.lineHeightMultiple = DesignTokens.codeLineHeight
        result.addAttribute(.paragraphStyle, value: paraStyle, range: NSRange(location: 0, length: result.length))
        
        return result
    }
    
    // MARK: - Blockquote
    
    private static func blockquoteString(node: MarkdownNode) -> NSAttributedString {
        let paraStyle = NSMutableParagraphStyle()
        paraStyle.lineHeightMultiple = DesignTokens.lineHeightMultiple
        paraStyle.headIndent = 16
        paraStyle.firstLineHeadIndent = 16
        
        let result = NSMutableAttributedString(string: "│ ", attributes: [
            .font: DesignTokens.bodyFont,
            .foregroundColor: DesignTokens.blockquoteBar
        ])
        result.append(DesignTokens.attributedString(from: node.inlineElements, font: DesignTokens.bodyFont, color: DesignTokens.blockquoteText))
        result.addAttribute(.paragraphStyle, value: paraStyle, range: NSRange(location: 0, length: result.length))
        return result
    }
    
    // MARK: - List
    
    private static func listString(items: [MarkdownNode], ordered: Bool) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for (idx, item) in items.enumerated() {
            if idx > 0 { result.append(NSAttributedString(string: "\n")) }
            let bullet = ordered ? "\(idx + 1). " : "•  "
            let bulletAttr = NSAttributedString(string: bullet, attributes: [
                .font: DesignTokens.bodyFont,
                .foregroundColor: DesignTokens.bulletColor
            ])
            result.append(bulletAttr)
            result.append(DesignTokens.attributedString(from: item.inlineElements, font: DesignTokens.bodyFont, color: DesignTokens.bodyColor))
        }
        
        let paraStyle = NSMutableParagraphStyle()
        paraStyle.lineHeightMultiple = DesignTokens.lineHeightMultiple
        paraStyle.headIndent = 24
        paraStyle.tabStops = [NSTextTab(textAlignment: .left, location: 24)]
        result.addAttribute(.paragraphStyle, value: paraStyle, range: NSRange(location: 0, length: result.length))
        
        return result
    }
    
    // MARK: - Table
    
    private static func tableString(node: MarkdownNode) -> NSAttributedString {
        // Simple tab-separated table rendering
        let lines = node.content.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let result = NSMutableAttributedString()
        
        for (idx, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let stripped = trimmed.replacingOccurrences(of: "|", with: "").replacingOccurrences(of: "-", with: "").replacingOccurrences(of: ":", with: "").trimmingCharacters(in: .whitespaces)
            if stripped.isEmpty { continue } // skip separator
            
            if result.length > 0 { result.append(NSAttributedString(string: "\n")) }
            
            let cells = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "|"))
                .components(separatedBy: "|")
                .map { $0.trimmingCharacters(in: .whitespaces) }
            
            let isHeader = idx == 0
            let font = isHeader ? DesignTokens.boldFont : DesignTokens.bodyFont
            let color = isHeader ? DesignTokens.headingColor : DesignTokens.bodyColor
            
            let joined = cells.joined(separator: "  │  ")
            result.append(NSAttributedString(string: joined, attributes: [.font: font, .foregroundColor: color]))
        }
        
        let paraStyle = NSMutableParagraphStyle()
        paraStyle.lineHeightMultiple = 1.6
        result.addAttribute(.paragraphStyle, value: paraStyle, range: NSRange(location: 0, length: result.length))
        
        return result
    }
    
    // MARK: - Horizontal Rule
    
    private static func ruleString() -> NSAttributedString {
        let rule = String(repeating: "─", count: 40)
        return NSAttributedString(string: rule, attributes: [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: DesignTokens.ruleColor
        ])
    }
    
    // MARK: - Helpers
    
    private static func newline(_ spacing: CGFloat) -> NSAttributedString {
        let paraStyle = NSMutableParagraphStyle()
        paraStyle.paragraphSpacingBefore = 0
        paraStyle.lineHeightMultiple = 0.01
        // Use font size to control spacing
        let fontSize = max(spacing, 1)
        return NSAttributedString(string: "\n", attributes: [
            .font: NSFont.systemFont(ofSize: fontSize),
            .paragraphStyle: paraStyle
        ])
    }
}
