import Foundation

// MARK: - Markdown AST Node

enum MarkdownNodeType {
    case heading(level: Int)
    case paragraph
    case codeBlock(language: String?)
    case blockquote
    case unorderedList
    case orderedList(start: Int)
    case listItem(ordered: Bool, index: Int)
    case horizontalRule
    case table
    case blank
}

struct MarkdownNode {
    let type: MarkdownNodeType
    let rawLines: [String]       // original markdown lines
    let content: String          // processed content (without syntax markers)
    let inlineElements: [InlineElement]
}

// MARK: - Inline Elements

enum InlineStyle {
    case bold
    case italic
    case boldItalic
    case code
    case link(url: String)
    case image(alt: String, url: String)
    case plain
}

struct InlineElement {
    let text: String
    let style: InlineStyle
}

// MARK: - Parser

class MarkdownParser {
    
    static func parse(_ markdown: String) -> [MarkdownNode] {
        let lines = markdown.components(separatedBy: "\n")
        var nodes: [MarkdownNode] = []
        var i = 0
        
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Blank line
            if trimmed.isEmpty {
                nodes.append(MarkdownNode(type: .blank, rawLines: [line], content: "", inlineElements: []))
                i += 1
                continue
            }
            
            // Horizontal rule: ---, ***, ___
            if isHorizontalRule(trimmed) {
                nodes.append(MarkdownNode(type: .horizontalRule, rawLines: [line], content: "", inlineElements: []))
                i += 1
                continue
            }
            
            // Heading: # ... ######
            if let (level, content) = parseHeading(trimmed) {
                let inlines = parseInline(content)
                nodes.append(MarkdownNode(type: .heading(level: level), rawLines: [line], content: content, inlineElements: inlines))
                i += 1
                continue
            }
            
            // Code block: ```
            if trimmed.hasPrefix("```") {
                let lang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                let language = lang.isEmpty ? nil : lang
                var codeLines: [String] = [line]
                var codeContent: [String] = []
                i += 1
                while i < lines.count {
                    if lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                        codeLines.append(lines[i])
                        i += 1
                        break
                    }
                    codeContent.append(lines[i])
                    codeLines.append(lines[i])
                    i += 1
                }
                let content = codeContent.joined(separator: "\n")
                nodes.append(MarkdownNode(type: .codeBlock(language: language), rawLines: codeLines, content: content, inlineElements: [InlineElement(text: content, style: .plain)]))
                continue
            }
            
            // Blockquote: >
            if trimmed.hasPrefix(">") {
                var quoteLines: [String] = []
                var rawLines: [String] = []
                while i < lines.count {
                    let l = lines[i]
                    let t = l.trimmingCharacters(in: .whitespaces)
                    if t.hasPrefix(">") {
                        var stripped = String(t.dropFirst())
                        if stripped.hasPrefix(" ") { stripped = String(stripped.dropFirst()) }
                        quoteLines.append(stripped)
                        rawLines.append(l)
                        i += 1
                    } else if t.isEmpty {
                        break
                    } else {
                        break
                    }
                }
                let content = quoteLines.joined(separator: "\n")
                let inlines = parseInline(content)
                nodes.append(MarkdownNode(type: .blockquote, rawLines: rawLines, content: content, inlineElements: inlines))
                continue
            }
            
            // Table: starts with |
            if trimmed.hasPrefix("|") {
                var tableLines: [String] = []
                while i < lines.count {
                    let t = lines[i].trimmingCharacters(in: .whitespaces)
                    if t.hasPrefix("|") || (t.contains("|") && t.contains("-")) {
                        tableLines.append(lines[i])
                        i += 1
                    } else {
                        break
                    }
                }
                let content = tableLines.joined(separator: "\n")
                nodes.append(MarkdownNode(type: .table, rawLines: tableLines, content: content, inlineElements: [InlineElement(text: content, style: .plain)]))
                continue
            }
            
            // Unordered list: - or * or +
            if isUnorderedListItem(trimmed) {
                var listRawLines: [String] = []
                var items: [MarkdownNode] = []
                var idx = 0
                while i < lines.count {
                    let t = lines[i].trimmingCharacters(in: .whitespaces)
                    if isUnorderedListItem(t) {
                        let itemContent = extractListItemContent(t)
                        let inlines = parseInline(itemContent)
                        items.append(MarkdownNode(type: .listItem(ordered: false, index: idx), rawLines: [lines[i]], content: itemContent, inlineElements: inlines))
                        listRawLines.append(lines[i])
                        idx += 1
                        i += 1
                    } else if t.isEmpty {
                        break
                    } else if lines[i].hasPrefix("  ") || lines[i].hasPrefix("\t") {
                        // continuation line
                        if !items.isEmpty {
                            listRawLines.append(lines[i])
                        }
                        i += 1
                    } else {
                        break
                    }
                }
                let allContent = items.map { $0.content }.joined(separator: "\n")
                var node = MarkdownNode(type: .unorderedList, rawLines: listRawLines, content: allContent, inlineElements: [])
                // Store items in a way we can access them - we'll use rawLines per item
                nodes.append(node)
                for item in items {
                    nodes.append(item)
                }
                continue
            }
            
            // Ordered list: 1. 2. etc
            if isOrderedListItem(trimmed) {
                var listRawLines: [String] = []
                var items: [MarkdownNode] = []
                var idx = 1
                while i < lines.count {
                    let t = lines[i].trimmingCharacters(in: .whitespaces)
                    if isOrderedListItem(t) {
                        let itemContent = extractOrderedListItemContent(t)
                        let inlines = parseInline(itemContent)
                        items.append(MarkdownNode(type: .listItem(ordered: true, index: idx), rawLines: [lines[i]], content: itemContent, inlineElements: inlines))
                        listRawLines.append(lines[i])
                        idx += 1
                        i += 1
                    } else if t.isEmpty {
                        break
                    } else {
                        break
                    }
                }
                let allContent = items.map { $0.content }.joined(separator: "\n")
                nodes.append(MarkdownNode(type: .orderedList(start: 1), rawLines: listRawLines, content: allContent, inlineElements: []))
                for item in items {
                    nodes.append(item)
                }
                continue
            }
            
            // Paragraph (default)
            var paraLines: [String] = []
            while i < lines.count {
                let t = lines[i].trimmingCharacters(in: .whitespaces)
                if t.isEmpty || t.hasPrefix("#") || t.hasPrefix("```") || t.hasPrefix(">") || t.hasPrefix("|") || isHorizontalRule(t) || isUnorderedListItem(t) || isOrderedListItem(t) {
                    break
                }
                paraLines.append(lines[i])
                i += 1
            }
            let content = paraLines.joined(separator: " ")
            let inlines = parseInline(content)
            nodes.append(MarkdownNode(type: .paragraph, rawLines: paraLines, content: content, inlineElements: inlines))
        }
        
        return nodes
    }
    
    // MARK: - Heading
    
    private static func parseHeading(_ line: String) -> (Int, String)? {
        var level = 0
        for ch in line {
            if ch == "#" { level += 1 } else { break }
        }
        guard level >= 1 && level <= 6 else { return nil }
        guard line.count > level else { return (level, "") }
        let rest = String(line.dropFirst(level))
        guard rest.first == " " else { return nil }
        return (level, rest.trimmingCharacters(in: .whitespaces))
    }
    
    // MARK: - Horizontal Rule
    
    private static func isHorizontalRule(_ line: String) -> Bool {
        let stripped = line.replacingOccurrences(of: " ", with: "")
        if stripped.count >= 3 {
            if stripped.allSatisfy({ $0 == "-" }) { return true }
            if stripped.allSatisfy({ $0 == "*" }) { return true }
            if stripped.allSatisfy({ $0 == "_" }) { return true }
            if stripped.allSatisfy({ $0 == "=" }) { return true }
        }
        return false
    }
    
    // MARK: - List Detection
    
    private static func isUnorderedListItem(_ line: String) -> Bool {
        if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") { return true }
        return false
    }
    
    private static func isOrderedListItem(_ line: String) -> Bool {
        let pattern = #"^\d+\.\s"#
        return line.range(of: pattern, options: .regularExpression) != nil
    }
    
    private static func extractListItemContent(_ line: String) -> String {
        // Remove leading - * + and space
        if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
            return String(line.dropFirst(2))
        }
        return line
    }
    
    private static func extractOrderedListItemContent(_ line: String) -> String {
        if let range = line.range(of: #"^\d+\.\s"#, options: .regularExpression) {
            return String(line[range.upperBound...])
        }
        return line
    }
    
    // MARK: - Inline Parsing
    
    static func parseInline(_ text: String) -> [InlineElement] {
        var elements: [InlineElement] = []
        let chars = Array(text)
        var i = 0
        var buffer = ""
        
        func flushBuffer() {
            if !buffer.isEmpty {
                elements.append(InlineElement(text: buffer, style: .plain))
                buffer = ""
            }
        }
        
        while i < chars.count {
            // Inline code: `...`
            if chars[i] == "`" && !lookingAt(chars, i, "```") {
                flushBuffer()
                i += 1
                var code = ""
                while i < chars.count && chars[i] != "`" {
                    code.append(chars[i])
                    i += 1
                }
                if i < chars.count { i += 1 } // skip closing `
                elements.append(InlineElement(text: code, style: .code))
                continue
            }
            
            // Bold+Italic: ***...*** or ___...___
            if i + 2 < chars.count && ((chars[i] == "*" && chars[i+1] == "*" && chars[i+2] == "*") || (chars[i] == "_" && chars[i+1] == "_" && chars[i+2] == "_")) {
                let marker = chars[i]
                flushBuffer()
                i += 3
                var content = ""
                while i + 2 < chars.count && !(chars[i] == marker && chars[i+1] == marker && chars[i+2] == marker) {
                    content.append(chars[i])
                    i += 1
                }
                if i + 2 < chars.count { i += 3 }
                elements.append(InlineElement(text: content, style: .boldItalic))
                continue
            }
            
            // Bold: **...** or __...__
            if i + 1 < chars.count && ((chars[i] == "*" && chars[i+1] == "*") || (chars[i] == "_" && chars[i+1] == "_")) {
                let marker = chars[i]
                flushBuffer()
                i += 2
                var content = ""
                while i + 1 < chars.count && !(chars[i] == marker && chars[i+1] == marker) {
                    content.append(chars[i])
                    i += 1
                }
                if i + 1 < chars.count { i += 2 }
                elements.append(InlineElement(text: content, style: .bold))
                continue
            }
            
            // Italic: *...* or _..._
            if (chars[i] == "*" || chars[i] == "_") {
                let marker = chars[i]
                // Check it's not just a standalone * or _
                if i + 1 < chars.count && chars[i+1] != " " && chars[i+1] != marker {
                    flushBuffer()
                    i += 1
                    var content = ""
                    while i < chars.count && chars[i] != marker {
                        content.append(chars[i])
                        i += 1
                    }
                    if i < chars.count { i += 1 }
                    if !content.isEmpty {
                        elements.append(InlineElement(text: content, style: .italic))
                    }
                    continue
                }
            }
            
            // Image: ![alt](url)
            if chars[i] == "!" && i + 1 < chars.count && chars[i+1] == "[" {
                let startI = i
                i += 2
                var altText = ""
                while i < chars.count && chars[i] != "]" {
                    altText.append(chars[i])
                    i += 1
                }
                if i < chars.count && chars[i] == "]" {
                    i += 1
                    if i < chars.count && chars[i] == "(" {
                        i += 1
                        var url = ""
                        while i < chars.count && chars[i] != ")" {
                            url.append(chars[i])
                            i += 1
                        }
                        if i < chars.count { i += 1 }
                        flushBuffer()
                        elements.append(InlineElement(text: altText, style: .image(alt: altText, url: url)))
                        continue
                    }
                }
                // Not a valid image, treat as plain text
                i = startI
                buffer.append(chars[i])
                i += 1
                continue
            }
            
            // Link: [text](url)
            if chars[i] == "[" {
                let startI = i
                i += 1
                var linkText = ""
                while i < chars.count && chars[i] != "]" {
                    linkText.append(chars[i])
                    i += 1
                }
                if i < chars.count && chars[i] == "]" {
                    i += 1
                    if i < chars.count && chars[i] == "(" {
                        i += 1
                        var url = ""
                        while i < chars.count && chars[i] != ")" {
                            url.append(chars[i])
                            i += 1
                        }
                        if i < chars.count { i += 1 }
                        flushBuffer()
                        elements.append(InlineElement(text: linkText, style: .link(url: url)))
                        continue
                    }
                }
                // Not a valid link, treat as plain text
                i = startI
                buffer.append(chars[i])
                i += 1
                continue
            }
            
            buffer.append(chars[i])
            i += 1
        }
        
        flushBuffer()
        return elements
    }
    
    private static func lookingAt(_ chars: [Character], _ index: Int, _ str: String) -> Bool {
        let strChars = Array(str)
        for j in 0..<strChars.count {
            if index + j >= chars.count || chars[index + j] != strChars[j] { return false }
        }
        return true
    }
    
    // MARK: - Serialize back to Markdown
    
    static func serialize(_ nodes: [MarkdownNode]) -> String {
        return nodes.map { node in
            node.rawLines.joined(separator: "\n")
        }.joined(separator: "\n")
    }
}
