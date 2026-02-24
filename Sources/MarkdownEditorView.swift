import SwiftUI
import AppKit

struct MarkdownEditorView: NSViewRepresentable {
    @Binding var markdownText: String
    @Binding var isModified: Bool
    var currentFileURL: URL?
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
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
        textView.textContainerInset = NSSize(width: 0, height: 28)
        textView.isAutomaticLinkDetectionEnabled = true
        
        scrollView.documentView = textView
        
        let coord = context.coordinator
        coord.scrollView = scrollView
        coord.textView = textView
        
        updateTextViewWidth(scrollView: scrollView, textView: textView)
        
        if !markdownText.isEmpty {
            renderContent(into: textView)
            coord.lastLoadedMarkdown = markdownText
        }
        
        scrollView.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(coord, selector: #selector(Coordinator.frameDidChange(_:)), name: NSView.frameDidChangeNotification, object: scrollView)
        NotificationCenter.default.addObserver(coord, selector: #selector(Coordinator.themeDidChange), name: .themeChanged, object: nil)
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coord = context.coordinator
        guard let textView = coord.textView else { return }
        
        if coord.lastLoadedMarkdown != markdownText {
            coord.lastLoadedMarkdown = markdownText
            renderContent(into: textView)
        }
        updateTextViewWidth(scrollView: scrollView, textView: textView)
    }
    
    private func renderContent(into textView: NSTextView) {
        let nodes = MarkdownParser.parse(markdownText)
        let attrStr = MarkdownAttributedStringBuilder.build(from: nodes, fileDirectory: currentFileURL?.deletingLastPathComponent())
        textView.textStorage?.setAttributedString(attrStr)
    }
    
    private func updateTextViewWidth(scrollView: NSScrollView, textView: NSTextView) {
        let scrollWidth = scrollView.contentSize.width
        guard scrollWidth > 0 else { return }
        let contentWidth = min(DesignTokens.maxContentWidth, scrollWidth - 80)
        let effectiveWidth = max(contentWidth, 300)
        let insetX = max(40, (scrollWidth - effectiveWidth) / 2)
        
        textView.textContainerInset = NSSize(width: insetX, height: 28)
        textView.textContainer?.size = NSSize(width: scrollWidth - insetX * 2, height: CGFloat.greatestFiniteMagnitude)
        textView.frame.size.width = scrollWidth
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject {
        var parent: MarkdownEditorView
        weak var scrollView: NSScrollView?
        weak var textView: NSTextView?
        var lastLoadedMarkdown: String = ""
        
        init(_ parent: MarkdownEditorView) { self.parent = parent }
        
        @objc func themeDidChange() {
            guard let textView = textView else { return }
            let text = lastLoadedMarkdown
            guard !text.isEmpty else { return }
            let nodes = MarkdownParser.parse(text)
            let attrStr = MarkdownAttributedStringBuilder.build(from: nodes, fileDirectory: parent.currentFileURL?.deletingLastPathComponent())
            textView.textStorage?.setAttributedString(attrStr)
            scrollView?.window?.backgroundColor = DesignTokens.isDark ? .black : .white
        }
        
        @objc func frameDidChange(_ notification: Notification) {
            guard let scrollView = scrollView, let textView = textView else { return }
            let scrollWidth = scrollView.contentSize.width
            guard scrollWidth > 0 else { return }
            let contentWidth = min(DesignTokens.maxContentWidth, scrollWidth - 80)
            let effectiveWidth = max(contentWidth, 300)
            let insetX = max(40, (scrollWidth - effectiveWidth) / 2)
            textView.textContainerInset = NSSize(width: insetX, height: 28)
            textView.textContainer?.size = NSSize(width: scrollWidth - insetX * 2, height: CGFloat.greatestFiniteMagnitude)
            textView.frame.size.width = scrollWidth
        }
    }
}

class FlippedView: NSView {
    override var isFlipped: Bool { true }
}
