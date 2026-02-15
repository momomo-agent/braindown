import AppKit

/// Shared design constants for the block-based renderer.
/// Spacing system: {4, 8, 12, 16, 24, 32}
enum DesignTokens {
    // MARK: - Typography
    static let bodySize: CGFloat = 16
    static let lineHeightMultiple: CGFloat = 1.65
    static let codeLineHeight: CGFloat = 1.35
    static let paragraphSpacing: CGFloat = 12
    static let maxContentWidth: CGFloat = 680
    
    // MARK: - Spacing
    static let sp4: CGFloat = 4
    static let sp8: CGFloat = 8
    static let sp12: CGFloat = 12
    static let sp16: CGFloat = 16
    static let sp24: CGFloat = 24
    static let sp32: CGFloat = 32
    
    // MARK: - Colors
    static var isDark: Bool {
        NSApp?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
    
    static var bodyColor: NSColor {
        isDark ? NSColor(white: 0.85, alpha: 1) : NSColor(white: 0.15, alpha: 1)
    }
    
    static var headingColor: NSColor {
        isDark ? NSColor(white: 0.92, alpha: 1) : NSColor(white: 0.08, alpha: 1)
    }
    
    static var secondaryColor: NSColor {
        isDark ? NSColor(white: 0.55, alpha: 1) : NSColor(white: 0.45, alpha: 1)
    }
    
    static var codeBackground: NSColor {
        isDark ? NSColor(white: 0.12, alpha: 1) : NSColor(white: 0.96, alpha: 1)
    }
    
    static var codeBorder: NSColor {
        isDark ? NSColor(white: 0.18, alpha: 1) : NSColor(white: 0.90, alpha: 1)
    }
    
    static var tableHeaderBackground: NSColor {
        isDark ? NSColor(white: 0.16, alpha: 1) : NSColor(white: 0.96, alpha: 1)
    }
    
    static var tableEvenRow: NSColor {
        isDark ? NSColor(white: 0.12, alpha: 1) : NSColor(white: 0.985, alpha: 1)
    }
    
    static var tableOddRow: NSColor {
        isDark ? NSColor(white: 0.10, alpha: 1) : NSColor(white: 1.0, alpha: 1)
    }
    
    static var tableBorder: NSColor {
        isDark ? NSColor(white: 0.22, alpha: 1) : NSColor(white: 0.88, alpha: 1)
    }
    
    static var tableHoverRow: NSColor {
        isDark ? NSColor(white: 0.18, alpha: 1) : NSColor(white: 0.94, alpha: 1)
    }
    
    static var blockquoteBar: NSColor {
        isDark ? NSColor(white: 0.28, alpha: 1) : NSColor(white: 0.82, alpha: 1)
    }
    
    static var blockquoteText: NSColor {
        isDark ? NSColor(white: 0.55, alpha: 1) : NSColor(white: 0.35, alpha: 1)
    }
    
    static var ruleColor: NSColor {
        isDark ? NSColor(white: 0.25, alpha: 1) : NSColor(white: 0.85, alpha: 1)
    }
    
    static var bulletColor: NSColor {
        isDark ? NSColor(white: 0.4, alpha: 1) : NSColor(white: 0.5, alpha: 1)
    }
    
    static var inlineCodeBackground: NSColor {
        NSColor.gray.withAlphaComponent(0.12)
    }
    
    // MARK: - Fonts
    static var bodyFont: NSFont {
        NSFont.systemFont(ofSize: bodySize)
    }
    
    static var boldFont: NSFont {
        NSFont.boldSystemFont(ofSize: bodySize)
    }
    
    static var codeFont: NSFont {
        NSFont.monospacedSystemFont(ofSize: 13.5, weight: .regular)
    }
    
    static func headingFont(level: Int) -> NSFont {
        let size = headingSize(level: level)
        switch level {
        case 1:
            return NSFontManager.shared.font(
                withFamily: "Georgia", traits: .boldFontMask, weight: 9, size: size
            ) ?? NSFont.systemFont(ofSize: size, weight: .bold)
        case 2:
            return NSFontManager.shared.font(
                withFamily: "Georgia", traits: .boldFontMask, weight: 8, size: size
            ) ?? NSFont.systemFont(ofSize: size, weight: .semibold)
        case 3: return NSFont.systemFont(ofSize: size, weight: .semibold)
        case 4: return NSFont.systemFont(ofSize: size, weight: .semibold)
        default: return NSFont.systemFont(ofSize: size, weight: .medium)
        }
    }
    
    static func headingSize(level: Int) -> CGFloat {
        switch level {
        case 1: return 28
        case 2: return 22
        case 3: return 18
        case 4: return 16
        case 5: return 16
        case 6: return 13
        default: return bodySize
        }
    }
    
    // MARK: - Helpers
    
    /// Build NSAttributedString from InlineElements with proper styling
    static func attributedString(
        from elements: [InlineElement],
        font: NSFont,
        color: NSColor,
        lineHeightMultiple: CGFloat = DesignTokens.lineHeightMultiple,
        alignment: NSTextAlignment = .left
    ) -> NSAttributedString {
        let paraStyle = NSMutableParagraphStyle()
        paraStyle.lineHeightMultiple = lineHeightMultiple
        paraStyle.alignment = alignment
        
        let result = NSMutableAttributedString()
        let baseAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paraStyle
        ]
        
        for element in elements {
            var attrs = baseAttrs
            switch element.style {
            case .bold:
                attrs[.font] = NSFont.boldSystemFont(ofSize: font.pointSize)
            case .italic:
                attrs[.font] = font.withTraits(.italicFontMask)
            case .boldItalic:
                attrs[.font] = NSFont.boldSystemFont(ofSize: font.pointSize).withTraits(.italicFontMask)
            case .code:
                attrs[.font] = NSFont.monospacedSystemFont(ofSize: font.pointSize - 1, weight: .regular)
                attrs[.backgroundColor] = inlineCodeBackground
            case .link(let url):
                attrs[.foregroundColor] = NSColor.linkColor
                attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
                if let linkURL = URL(string: url) {
                    attrs[.link] = linkURL
                }
            case .image, .plain:
                break
            }
            result.append(NSAttributedString(string: element.text, attributes: attrs))
        }
        
        return result
    }
}
