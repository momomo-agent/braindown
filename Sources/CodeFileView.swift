import SwiftUI
import AppKit
import Highlightr

/// Renders a non-markdown file as a syntax-highlighted code view (read-only).
struct CodeFileView: NSViewRepresentable {
    @Binding var text: String
    var language: String
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.isRichText = true
        textView.font = DesignTokens.codeFont
        textView.textContainerInset = NSSize(width: 40, height: 28)
        textView.isAutomaticLinkDetectionEnabled = false
        
        // Key: allow NSTextView to resize vertically, wrap horizontally
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        
        scrollView.documentView = textView
        context.coordinator.textView = textView
        
        applyHighlighting(to: textView)
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }
        if context.coordinator.lastText != text {
            context.coordinator.lastText = text
            applyHighlighting(to: textView)
        }
    }
    
    func makeCoordinator() -> Coordinator { Coordinator() }
    
    class Coordinator {
        weak var textView: NSTextView?
        var lastText: String = ""
    }
    
    private func applyHighlighting(to textView: NSTextView) {
        let isDark = DesignTokens.isDark
        let themeName = isDark ? "atom-one-dark" : "atom-one-light"
        let codeFont = DesignTokens.codeFont
        
        let h = Highlightr()
        h?.setTheme(to: themeName)
        h?.theme.codeFont = codeFont
        
        if let h = h, let highlighted = h.highlight(text, as: language.lowercased()) {
            let m = NSMutableAttributedString(attributedString: highlighted)
            m.removeAttribute(.backgroundColor, range: NSRange(location: 0, length: m.length))
            
            let paraStyle = NSMutableParagraphStyle()
            paraStyle.lineHeightMultiple = DesignTokens.codeLineHeight
            m.addAttribute(.paragraphStyle, value: paraStyle, range: NSRange(location: 0, length: m.length))
            
            textView.textStorage?.setAttributedString(m)
        } else {
            let fallback: NSColor = isDark ? NSColor(white: 0.8, alpha: 1) : NSColor(white: 0.2, alpha: 1)
            let attr = NSAttributedString(string: text, attributes: [
                .font: codeFont, .foregroundColor: fallback
            ])
            textView.textStorage?.setAttributedString(attr)
        }
    }
}
