import AppKit
import Foundation
import Highlightr

class MarkdownTextStorage: NSTextStorage {
    
    private let backingStore = NSMutableAttributedString()
    private var markdownSource: String = ""
    private var nodes: [MarkdownNode] = []
    private var isUpdatingFromMarkdown = false
    
    // 当前文件的目录，用于解析相对路径图片
    var currentFileDirectory: URL?
    
    // Typography constants — Craft/Notion inspired
    // 间距系统：8 / 12 / 16 / 24 / 32（Refactoring UI）
    static let bodySize: CGFloat = 16
    static let lineHeightMultiple: CGFloat = 1.65
    static let paragraphSpacing: CGFloat = 12   // 收紧段间距
    static let blockSpacing: CGFloat = 24       // 系统值
    static let maxContentWidth: CGFloat = 680
    
    static func fontSize(for level: Int) -> CGFloat {
        switch level {
        case 1: return 28   // H1: 不需要太大，靠字重和留白
        case 2: return 22   // H2: 适度
        case 3: return 18   // H3: 接近正文，靠 semibold 区分
        case 4: return 16   // H4: 同正文大小，靠字重
        case 5: return 16
        case 6: return 13   // H6: 小标签
        default: return bodySize
        }
    }
    
    // MARK: - NSTextStorage Required Overrides
    
    override var string: String {
        return backingStore.string
    }
    
    override func attributes(at location: Int, effectiveRange range: NSRangePointer?) -> [NSAttributedString.Key: Any] {
        return backingStore.attributes(at: location, effectiveRange: range)
    }
    
    override func replaceCharacters(in range: NSRange, with str: String) {
        beginEditing()
        backingStore.replaceCharacters(in: range, with: str)
        edited(.editedCharacters, range: range, changeInLength: str.count - range.length)
        endEditing()
    }
    
    override func setAttributes(_ attrs: [NSAttributedString.Key: Any]?, range: NSRange) {
        beginEditing()
        backingStore.setAttributes(attrs, range: range)
        edited(.editedAttributes, range: range, changeInLength: 0)
        endEditing()
    }
    
    override func processEditing() {
        if !isUpdatingFromMarkdown {
            // User is editing the rich text — we don't re-apply styles during live editing
            // to avoid cursor jumping. Styles are applied on load.
        }
        super.processEditing()
    }
    
    // MARK: - Load Markdown
    
    func loadMarkdown(_ markdown: String) {
        self.markdownSource = markdown
        self.nodes = MarkdownParser.parse(markdown)
        
        isUpdatingFromMarkdown = true
        
        let result = NSMutableAttributedString()
        
        for node in nodes {
            switch node.type {
            case .heading(let level):
                result.append(buildHeading(node, level: level))
                result.append(newline(paragraphSpacing: Self.paragraphSpacing))
            case .paragraph:
                result.append(buildParagraph(node))
                result.append(newline(paragraphSpacing: Self.paragraphSpacing))
            case .codeBlock(let language):
                result.append(newline(paragraphSpacing: 8))
                result.append(buildCodeBlock(node, language: language))
                result.append(newline(paragraphSpacing: 24))
            case .blockquote:
                result.append(buildBlockquote(node))
                result.append(newline(paragraphSpacing: Self.paragraphSpacing))
            case .listItem(let ordered, let index):
                result.append(buildListItem(node, ordered: ordered, index: index))
                result.append(newline(paragraphSpacing: 4))
            case .horizontalRule:
                result.append(buildHorizontalRule())
                result.append(newline(paragraphSpacing: 4))
            case .table:
                result.append(newline(paragraphSpacing: 8))
                result.append(buildTable(node))
                result.append(newline(paragraphSpacing: 24))
            case .unorderedList, .orderedList, .blank:
                continue
            }
        }
        
        // 一次性替换，只触发一次 layout
        beginEditing()
        let fullRange = NSRange(location: 0, length: backingStore.length)
        backingStore.replaceCharacters(in: fullRange, with: result)
        edited(.editedCharacters, range: fullRange, changeInLength: result.length - fullRange.length)
        edited(.editedAttributes, range: NSRange(location: 0, length: result.length), changeInLength: 0)
        endEditing()
        
        isUpdatingFromMarkdown = false
    }
    
    // MARK: - Export Markdown
    
    func exportMarkdown() -> String {
        // Return the original markdown source — for now we keep the source in sync
        // A full implementation would serialize the attributed string back to markdown
        return markdownSource
    }
    
    func updateMarkdownSource(_ newSource: String) {
        self.markdownSource = newSource
    }
    
    // MARK: - Build Attributed Strings
    
    private func bodyFont() -> NSFont {
        return NSFont.systemFont(ofSize: Self.bodySize)
    }
    
    private func bodyColor() -> NSColor {
        let isDark = NSApp?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark ? NSColor(white: 0.85, alpha: 1) : NSColor(white: 0.15, alpha: 1)
    }
    
    private func baseParagraphStyle(spacing: CGFloat = 0) -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = Self.lineHeightMultiple
        style.paragraphSpacing = spacing
        return style
    }
    
    private func newline(paragraphSpacing: CGFloat = 0) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.paragraphSpacing = paragraphSpacing
        style.lineHeightMultiple = 0.1
        return NSAttributedString(string: "\n", attributes: [
            .font: NSFont.systemFont(ofSize: 1),
            .paragraphStyle: style
        ])
    }
    
    private func buildHeading(_ node: MarkdownNode, level: Int) -> NSAttributedString {
        let size = Self.fontSize(for: level)
        let font: NSFont
        switch level {
        // Notion 风格：H1/H2 用衬线体，跟正文无衬线形成优雅对比
        case 1:
            font = NSFontManager.shared.font(
                withFamily: "Georgia", traits: .boldFontMask, weight: 9, size: size
            ) ?? NSFont.systemFont(ofSize: size, weight: .bold)
        case 2:
            font = NSFontManager.shared.font(
                withFamily: "Georgia", traits: .boldFontMask, weight: 8, size: size
            ) ?? NSFont.systemFont(ofSize: size, weight: .semibold)
        case 3: font = NSFont.systemFont(ofSize: size, weight: .semibold)
        case 4: font = NSFont.systemFont(ofSize: size, weight: .semibold)
        default: font = NSFont.systemFont(ofSize: size, weight: .medium)
        }
        
        let isDark = NSApp?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        
        let paraStyle = NSMutableParagraphStyle()
        paraStyle.lineHeightMultiple = level <= 2 ? 1.3 : 1.4
        // 间距系统化 {4,8,12,16,24,32}，接近性 ≥ 3:1
        paraStyle.paragraphSpacingBefore = level == 1 ? 24 : (level == 2 ? 16 : (level == 3 ? 12 : 8))
        paraStyle.paragraphSpacing = 4
        
        // 标题颜色比正文略深，H6 用次要色
        let color: NSColor
        switch level {
        case 6:
            color = NSColor.secondaryLabelColor
        default:
            color = isDark ? NSColor(white: 0.92, alpha: 1) : NSColor(white: 0.08, alpha: 1)
        }
        
        let result = NSMutableAttributedString()
        let baseAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paraStyle
        ]
        
        if node.inlineElements.isEmpty {
            let text = level == 6 ? node.content.uppercased() : node.content
            result.append(NSAttributedString(string: text, attributes: baseAttrs))
        } else {
            for element in node.inlineElements {
                var attrs = baseAttrs
                applyInlineStyle(element.style, to: &attrs, baseSize: size)
                let text = level == 6 ? element.text.uppercased() : element.text
                result.append(NSAttributedString(string: text, attributes: attrs))
            }
        }
        
        return result
    }
    
    private func buildParagraph(_ node: MarkdownNode) -> NSAttributedString {
        let paraStyle = baseParagraphStyle(spacing: Self.paragraphSpacing)
        let result = NSMutableAttributedString()
        let baseAttrs: [NSAttributedString.Key: Any] = [
            .font: bodyFont(),
            .foregroundColor: bodyColor(),
            .paragraphStyle: paraStyle
        ]
        
        for element in node.inlineElements {
            if case .image(let alt, let url) = element.style {
                result.append(buildImageAttachment(alt: alt, urlString: url))
            } else {
                var attrs = baseAttrs
                applyInlineStyle(element.style, to: &attrs, baseSize: Self.bodySize)
                result.append(NSAttributedString(string: element.text, attributes: attrs))
            }
        }
        
        return result
    }
    
    // Shared Highlightr instance
    private static let highlightr: Highlightr? = {
        let h = Highlightr()
        h?.setTheme(to: "atom-one-light")
        return h
    }()
    
    private func buildCodeBlock(_ node: MarkdownNode, language: String?) -> NSAttributedString {
        let codeFont = NSFont.monospacedSystemFont(ofSize: Self.bodySize - 2.5, weight: .regular)
        
        let isDark: Bool
        if let app = NSApp {
            isDark = app.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        } else {
            isDark = false
        }
        let bgColor: NSColor = isDark ? NSColor(white: 0.12, alpha: 1) : NSColor(white: 0.965, alpha: 1)
        
        // Highlightr 主题
        let themeName = isDark ? "atom-one-dark" : "atom-one-light"
        Self.highlightr?.setTheme(to: themeName)
        Self.highlightr?.theme.codeFont = codeFont
        
        let paraStyle = NSMutableParagraphStyle()
        paraStyle.headIndent = 16
        paraStyle.firstLineHeadIndent = 16
        paraStyle.tailIndent = -16
        paraStyle.lineHeightMultiple = 1.35
        paraStyle.paragraphSpacingBefore = 0
        paraStyle.paragraphSpacing = 0
        
        let result = NSMutableAttributedString()
        
        // 上 padding — 空行撑出顶部间距
        let topPadStyle = NSMutableParagraphStyle()
        topPadStyle.headIndent = 16
        topPadStyle.firstLineHeadIndent = 16
        topPadStyle.tailIndent = -16
        topPadStyle.lineHeightMultiple = 0.5
        topPadStyle.paragraphSpacing = 0
        topPadStyle.paragraphSpacingBefore = 0
        result.append(NSAttributedString(string: " ", attributes: [
            .font: NSFont.systemFont(ofSize: 8),
            .blockBackground: bgColor,
            .paragraphStyle: topPadStyle
        ]))
        result.append(NSAttributedString(string: "\n", attributes: [
            .font: NSFont.systemFont(ofSize: 2),
            .blockBackground: bgColor
        ]))
        
        // 语言标签 — 小字，柔和灰色
        if let lang = language, !lang.isEmpty {
            let langStyle = NSMutableParagraphStyle()
            langStyle.headIndent = 16
            langStyle.firstLineHeadIndent = 16
            langStyle.tailIndent = -16
            langStyle.lineHeightMultiple = 1.6
            langStyle.paragraphSpacingBefore = 0
            let langAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium),
                .foregroundColor: isDark ? NSColor(white: 0.45, alpha: 1) : NSColor(white: 0.55, alpha: 1),
                .blockBackground: bgColor,
                .paragraphStyle: langStyle
            ]
            result.append(NSAttributedString(string: "  " + lang, attributes: langAttrs))
            result.append(NSAttributedString(string: "\n", attributes: [
                .font: NSFont.systemFont(ofSize: 2),
                .blockBackground: bgColor
            ]))
        }
        
        // Highlightr 语法高亮
        let langName = language?.lowercased()
        let highlighted: NSAttributedString
        if let h = Self.highlightr, let hl = h.highlight(node.content, as: langName) {
            highlighted = hl
        } else {
            let fallbackColor: NSColor = isDark ? NSColor(white: 0.8, alpha: 1) : NSColor(white: 0.2, alpha: 1)
            highlighted = NSAttributedString(string: node.content, attributes: [
                .font: codeFont,
                .foregroundColor: fallbackColor
            ])
        }
        
        // 逐行加 padding + blockBackground
        let lines = highlighted.string.components(separatedBy: "\n")
        var charIndex = 0
        
        for (lineIdx, line) in lines.enumerated() {
            let lineRange = NSRange(location: charIndex, length: line.utf16.count)
            let lineAttr: NSAttributedString
            if lineRange.location + lineRange.length <= highlighted.length {
                lineAttr = highlighted.attributedSubstring(from: lineRange)
            } else {
                lineAttr = NSAttributedString(string: line, attributes: [.font: codeFont])
            }
            
            // 左 padding
            result.append(NSAttributedString(string: "  ", attributes: [
                .font: codeFont, .blockBackground: bgColor, .paragraphStyle: paraStyle
            ]))
            
            // 高亮内容
            let lineMut = NSMutableAttributedString(attributedString: lineAttr)
            let fullRange = NSRange(location: 0, length: lineMut.length)
            lineMut.addAttribute(.blockBackground, value: bgColor, range: fullRange)
            lineMut.addAttribute(.paragraphStyle, value: paraStyle, range: fullRange)
            result.append(lineMut)
            
            // 右 padding
            result.append(NSAttributedString(string: "  ", attributes: [
                .font: codeFont, .blockBackground: bgColor, .paragraphStyle: paraStyle
            ]))
            
            if lineIdx < lines.count - 1 {
                result.append(NSAttributedString(string: "\n", attributes: [
                    .font: codeFont, .blockBackground: bgColor
                ]))
            }
            
            charIndex += line.utf16.count + 1
        }
        
        // 下 padding — 空行撑出底部间距
        let bottomPadStyle = NSMutableParagraphStyle()
        bottomPadStyle.headIndent = 16
        bottomPadStyle.firstLineHeadIndent = 16
        bottomPadStyle.tailIndent = -16
        bottomPadStyle.lineHeightMultiple = 0.5
        bottomPadStyle.paragraphSpacing = 0
        bottomPadStyle.paragraphSpacingBefore = 0
        result.append(NSAttributedString(string: "\n", attributes: [
            .font: NSFont.systemFont(ofSize: 2),
            .blockBackground: bgColor
        ]))
        result.append(NSAttributedString(string: " ", attributes: [
            .font: NSFont.systemFont(ofSize: 8),
            .blockBackground: bgColor,
            .paragraphStyle: bottomPadStyle
        ]))
        
        return result
    }
    
    private func buildBlockquote(_ node: MarkdownNode) -> NSAttributedString {
        let paraStyle = NSMutableParagraphStyle()
        paraStyle.lineHeightMultiple = Self.lineHeightMultiple
        paraStyle.paragraphSpacing = 4
        paraStyle.headIndent = 24
        paraStyle.firstLineHeadIndent = 24
        
        let isDark = NSApp?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        // Craft 风格：引用文字用柔和的灰色，不刺眼
        let quoteColor: NSColor = isDark ? NSColor(white: 0.55, alpha: 1) : NSColor(white: 0.35, alpha: 1)
        let barColor: NSColor = isDark ? NSColor(white: 0.28, alpha: 1) : NSColor(white: 0.82, alpha: 1)
        
        let result = NSMutableAttributedString()
        
        // 粗竖线 — 用 Unicode block character
        let barAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: Self.bodySize),
            .foregroundColor: barColor,
            .paragraphStyle: paraStyle
        ]
        result.append(NSAttributedString(string: "▎ ", attributes: barAttrs))
        
        let baseAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: Self.bodySize, weight: .regular),
            .foregroundColor: quoteColor,
            .paragraphStyle: paraStyle
        ]
        
        for element in node.inlineElements {
            var attrs = baseAttrs
            applyInlineStyle(element.style, to: &attrs, baseSize: Self.bodySize)
            attrs[.foregroundColor] = quoteColor
            result.append(NSAttributedString(string: element.text, attributes: attrs))
        }
        
        return result
    }
    
    private func buildListItem(_ node: MarkdownNode, ordered: Bool, index: Int) -> NSAttributedString {
        let paraStyle = NSMutableParagraphStyle()
        paraStyle.lineHeightMultiple = Self.lineHeightMultiple
        paraStyle.paragraphSpacing = 4
        paraStyle.headIndent = 24
        paraStyle.firstLineHeadIndent = 8
        
        let tabStop = NSTextTab(textAlignment: .left, location: 24)
        paraStyle.tabStops = [tabStop]
        
        let bullet = ordered ? "\(index).\t" : "•\t"
        
        let result = NSMutableAttributedString()
        
        let isDark = NSApp?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let bulletColor: NSColor = isDark ? NSColor(white: 0.4, alpha: 1) : NSColor(white: 0.5, alpha: 1)
        
        let bulletAttrs: [NSAttributedString.Key: Any] = [
            .font: bodyFont(),
            .foregroundColor: bulletColor,
            .paragraphStyle: paraStyle
        ]
        result.append(NSAttributedString(string: bullet, attributes: bulletAttrs))
        
        let baseAttrs: [NSAttributedString.Key: Any] = [
            .font: bodyFont(),
            .foregroundColor: bodyColor(),
            .paragraphStyle: paraStyle
        ]
        
        for element in node.inlineElements {
            var attrs = baseAttrs
            applyInlineStyle(element.style, to: &attrs, baseSize: Self.bodySize)
            result.append(NSAttributedString(string: element.text, attributes: attrs))
        }
        
        return result
    }
    
    private func buildHorizontalRule() -> NSAttributedString {
        let paraStyle = NSMutableParagraphStyle()
        paraStyle.lineHeightMultiple = 0.5
        paraStyle.paragraphSpacingBefore = 12
        paraStyle.paragraphSpacing = 12
        paraStyle.alignment = .center
        
        let isDark = NSApp?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let ruleColor: NSColor = isDark ? NSColor(white: 0.25, alpha: 1) : NSColor(white: 0.85, alpha: 1)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 8),
            .foregroundColor: ruleColor,
            .paragraphStyle: paraStyle
        ]
        
        return NSAttributedString(string: "─────────────────────────────────────────", attributes: attrs)
    }
    
    private func buildTable(_ node: MarkdownNode) -> NSAttributedString {
        let lines = node.content.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !lines.isEmpty else { return NSAttributedString() }
        
        var rows: [[String]] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let stripped = trimmed.replacingOccurrences(of: "|", with: "").replacingOccurrences(of: "-", with: "").replacingOccurrences(of: ":", with: "").trimmingCharacters(in: .whitespaces)
            if stripped.isEmpty { continue }
            
            let cells = trimmed
                .trimmingCharacters(in: CharacterSet(charactersIn: "|"))
                .components(separatedBy: "|")
                .map { $0.trimmingCharacters(in: .whitespaces) }
            rows.append(cells)
        }
        
        guard !rows.isEmpty else { return NSAttributedString() }
        
        let isDark: Bool
        if let app = NSApp {
            isDark = app.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        } else {
            isDark = false
        }
        
        let headerBg: NSColor = isDark ? NSColor(white: 0.16, alpha: 1) : NSColor(white: 0.96, alpha: 1)
        let evenRowBg: NSColor = isDark ? NSColor(white: 0.12, alpha: 1) : NSColor(white: 0.985, alpha: 1)
        let oddRowBg: NSColor = isDark ? NSColor(white: 0.10, alpha: 1) : NSColor(white: 1.0, alpha: 1)
        let borderColor: NSColor = isDark ? NSColor(white: 0.22, alpha: 1) : NSColor(white: 0.88, alpha: 1)
        
        let colCount = rows.map { $0.count }.max() ?? 1
        
        let table = NSTextTable()
        table.numberOfColumns = colCount
        table.setContentWidth(100, type: .percentageValueType)
        table.hidesEmptyCells = false
        table.layoutAlgorithm = NSTextTable.LayoutAlgorithm(rawValue: 0)!
        
        let result = NSMutableAttributedString()
        
        for (rowIdx, row) in rows.enumerated() {
            let isHeader = rowIdx == 0
            
            for colIdx in 0..<colCount {
                let cellText = colIdx < row.count ? row[colIdx] : ""
                
                let block = NSTextTableBlock(table: table, startingRow: rowIdx, rowSpan: 1, startingColumn: colIdx, columnSpan: 1)
                
                // 只有底部细分隔线（Craft/Notion 风格）
                block.setBorderColor(.clear)
                block.setWidth(0, type: .absoluteValueType, for: .border)
                block.setBorderColor(borderColor, for: .maxY)
                block.setWidth(0.5, type: .absoluteValueType, for: .border, edge: .maxY)
                
                // 内边距
                block.setWidth(12, type: .absoluteValueType, for: .padding)
                block.setWidth(8, type: .absoluteValueType, for: .padding, edge: .minY)
                block.setWidth(8, type: .absoluteValueType, for: .padding, edge: .maxY)
                
                // 交替行色
                if isHeader {
                    block.backgroundColor = headerBg
                } else {
                    block.backgroundColor = rowIdx % 2 == 0 ? evenRowBg : oddRowBg
                }
                
                let paraStyle = NSMutableParagraphStyle()
                paraStyle.textBlocks = [block]
                paraStyle.lineHeightMultiple = 1.3
                paraStyle.alignment = .left
                
                let font: NSFont = isHeader
                    ? NSFont.systemFont(ofSize: Self.bodySize - 1, weight: .semibold)
                    : NSFont.systemFont(ofSize: Self.bodySize - 1, weight: .regular)
                
                let textColor: NSColor = isHeader
                    ? (isDark ? NSColor(white: 0.9, alpha: 1) : NSColor(white: 0.15, alpha: 1))
                    : bodyColor()
                
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: textColor,
                    .paragraphStyle: paraStyle
                ]
                
                result.append(NSAttributedString(string: cellText + "\n", attributes: attrs))
            }
        }
        
        return result
    }
    
    // MARK: - Inline Style Application
    
    private func applyInlineStyle(_ style: InlineStyle, to attrs: inout [NSAttributedString.Key: Any], baseSize: CGFloat) {
        switch style {
        case .bold:
            attrs[.font] = NSFont.boldSystemFont(ofSize: baseSize)
        case .italic:
            attrs[.font] = NSFont.systemFont(ofSize: baseSize).withTraits(.italicFontMask)
        case .boldItalic:
            attrs[.font] = NSFont.boldSystemFont(ofSize: baseSize).withTraits(.italicFontMask)
        case .code:
            attrs[.font] = NSFont.monospacedSystemFont(ofSize: baseSize - 1, weight: .regular)
            attrs[.backgroundColor] = NSColor.gray.withAlphaComponent(0.12)
        case .link(let url):
            attrs[.foregroundColor] = NSColor.linkColor
            attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
            if let linkURL = URL(string: url) {
                attrs[.link] = linkURL
            }
        case .image, .plain:
            break
        }
    }
    
    // MARK: - Image Loading
    
    private func buildImageAttachment(alt: String, urlString: String) -> NSAttributedString {
        var imageURL: URL?
        
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            imageURL = URL(string: urlString)
        } else if let dir = currentFileDirectory {
            // 相对路径
            imageURL = dir.appendingPathComponent(urlString)
        }
        
        if let url = imageURL, let image = loadImage(from: url) {
            let attachment = NSTextAttachment()
            
            // 限制图片最大宽度
            let maxWidth = Self.maxContentWidth - 32
            let scale = image.size.width > maxWidth ? maxWidth / image.size.width : 1.0
            let size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
            
            attachment.image = image
            attachment.bounds = CGRect(origin: .zero, size: size)
            
            let result = NSMutableAttributedString()
            result.append(NSAttributedString(attachment: attachment))
            
            // Alt text caption
            if !alt.isEmpty {
                let captionStyle = NSMutableParagraphStyle()
                captionStyle.alignment = .center
                captionStyle.lineHeightMultiple = 1.4
                let captionAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: Self.bodySize - 2),
                    .foregroundColor: NSColor.secondaryLabelColor,
                    .paragraphStyle: captionStyle
                ]
                result.append(NSAttributedString(string: "\n" + alt, attributes: captionAttrs))
            }
            
            return result
        }
        
        // 图片加载失败，显示占位符
        let placeholder = alt.isEmpty ? "🖼 [Image]" : "🖼 \(alt)"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: Self.bodySize),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        return NSAttributedString(string: placeholder, attributes: attrs)
    }
    
    // 图片缓存
    private var imageCache = [String: NSImage]()
    
    private func loadImage(from url: URL) -> NSImage? {
        let key = url.absoluteString
        if let cached = imageCache[key] { return cached }
        
        if url.isFileURL {
            if let img = NSImage(contentsOf: url) {
                imageCache[key] = img
                return img
            }
            return nil
        }
        // 网络图片：异步加载，先返回 nil（占位符）
        // 避免阻塞主线程
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            if let data = try? Data(contentsOf: url), let img = NSImage(data: data) {
                DispatchQueue.main.async {
                    self?.imageCache[key] = img
                    // 网络图片加载完后不自动刷新，避免闪烁
                    // 用户切换文件再回来就能看到
                }
            }
        }
        return nil
    }
}

// MARK: - NSFont Extension

extension NSFont {
    func withTraits(_ traits: NSFontTraitMask) -> NSFont {
        let descriptor = fontDescriptor
        let newDescriptor = descriptor.withSymbolicTraits(NSFontDescriptor.SymbolicTraits(rawValue: UInt32(traits.rawValue)))
        return NSFont(descriptor: newDescriptor, size: pointSize) ?? self
    }
}
