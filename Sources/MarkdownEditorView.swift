import SwiftUI
import AppKit

struct MarkdownEditorView: NSViewRepresentable {
    @Binding var markdownText: String
    @Binding var isModified: Bool
    var currentFileURL: URL?
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        
        let textStorage = MarkdownTextStorage()
        let layoutManager = BlockBackgroundLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        
        let textContainer = NSTextContainer()
        textContainer.widthTracksTextView = false
        textContainer.heightTracksTextView = false
        textContainer.containerSize = NSSize(width: MarkdownTextStorage.maxContentWidth, height: .greatestFiniteMagnitude)
        layoutManager.addTextContainer(textContainer)
        
        let textView = NSTextView(frame: scrollView.contentView.bounds, textContainer: textContainer)
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = true
        textView.usesFontPanel = false
        textView.usesRuler = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.drawsBackground = false
        
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0, height: 0)
        
        textView.textContainerInset = NSSize(width: 0, height: 40)
        
        textView.typingAttributes = [
            .font: NSFont.systemFont(ofSize: MarkdownTextStorage.bodySize),
            .foregroundColor: NSColor.textColor
        ]
        
        textView.delegate = context.coordinator
        context.coordinator.textView = textView
        context.coordinator.textStorage = textStorage
        context.coordinator.scrollView = scrollView
        
        scrollView.documentView = textView
        
        if !markdownText.isEmpty {
            textStorage.currentFileDirectory = currentFileURL?.deletingLastPathComponent()
            textStorage.loadMarkdown(markdownText)
        }
        
        // 初始布局
        updateLayout(scrollView: scrollView, textView: textView, textContainer: textContainer)
        
        // 监听窗口 resize 和 scrollView frame 变化，实时更新居中
        scrollView.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.frameDidChange(_:)),
            name: NSView.frameDidChangeNotification,
            object: scrollView
        )
        
        // 延迟一帧再 layout，确保首次打开时 scrollView 已有正确尺寸
        DispatchQueue.main.async {
            self.updateLayout(scrollView: scrollView, textView: textView, textContainer: textContainer)
        }
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView,
              let textStorage = context.coordinator.textStorage,
              let textContainer = textView.textContainer else { return }
        
        // 文件切换时重新加载
        if context.coordinator.lastLoadedMarkdown != markdownText && !context.coordinator.isEditing {
            context.coordinator.lastLoadedMarkdown = markdownText
            textStorage.currentFileDirectory = currentFileURL?.deletingLastPathComponent()
            textStorage.loadMarkdown(markdownText)
        }
        
        // 窗口大小变化时更新布局
        updateLayout(scrollView: scrollView, textView: textView, textContainer: textContainer)
    }
    
    private func updateLayout(scrollView: NSScrollView, textView: NSTextView, textContainer: NSTextContainer) {
        let scrollWidth = scrollView.contentSize.width
        guard scrollWidth > 0 else { return }
        
        let contentWidth = min(MarkdownTextStorage.maxContentWidth, scrollWidth - 80)
        let effectiveWidth = max(contentWidth, 300) // 最小 300，防止太窄看不见
        let insetX = max(40, (scrollWidth - effectiveWidth) / 2)
        
        textView.textContainerInset = NSSize(width: insetX, height: 40)
        textContainer.containerSize = NSSize(width: effectiveWidth, height: .greatestFiniteMagnitude)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownEditorView
        weak var textView: NSTextView?
        weak var scrollView: NSScrollView?
        var textStorage: MarkdownTextStorage?
        var lastLoadedMarkdown: String = ""
        var isEditing = false
        
        init(_ parent: MarkdownEditorView) {
            self.parent = parent
        }
        
        @objc func frameDidChange(_ notification: Notification) {
            guard let scrollView = scrollView,
                  let textView = scrollView.documentView as? NSTextView,
                  let textContainer = textView.textContainer else { return }
            
            let scrollWidth = scrollView.contentSize.width
            guard scrollWidth > 0 else { return }
            
            let contentWidth = min(MarkdownTextStorage.maxContentWidth, scrollWidth - 80)
            let effectiveWidth = max(contentWidth, 300)
            let insetX = max(40, (scrollWidth - effectiveWidth) / 2)
            
            textView.textContainerInset = NSSize(width: insetX, height: 40)
            textContainer.containerSize = NSSize(width: effectiveWidth, height: .greatestFiniteMagnitude)
        }
        
        func textDidChange(_ notification: Notification) {
            isEditing = true
            if !parent.isModified {
                DispatchQueue.main.async {
                    self.parent.isModified = true
                }
            }
            isEditing = false
        }
        
        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            if let url = link as? URL {
                NSWorkspace.shared.open(url)
                return true
            }
            return false
        }
    }
}
