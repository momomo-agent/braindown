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
        
        let flippedView = FlippedView()
        flippedView.translatesAutoresizingMaskIntoConstraints = false
        flippedView.wantsLayer = true
        
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        flippedView.addSubview(stackView)
        scrollView.documentView = flippedView
        
        let coord = context.coordinator
        coord.scrollView = scrollView
        coord.stackView = stackView
        coord.flippedView = flippedView
        
        let selMgr = BlockSelectionManager(scrollView: scrollView, stackView: stackView)
        coord.selectionManager = selMgr
        flippedView.selectionManager = selMgr
        
        setupConstraints(scrollView: scrollView, flippedView: flippedView, stackView: stackView, coord: coord)
        
        if !markdownText.isEmpty {
            let nodes = MarkdownParser.parse(markdownText)
            BlockRenderer.render(nodes: nodes, into: stackView, currentFileDirectory: currentFileURL?.deletingLastPathComponent())
            coord.lastLoadedMarkdown = markdownText
        }
        
        scrollView.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(coord, selector: #selector(Coordinator.frameDidChange(_:)), name: NSView.frameDidChangeNotification, object: scrollView)
        NotificationCenter.default.addObserver(coord, selector: #selector(Coordinator.themeDidChange), name: .themeChanged, object: nil)
        
        DispatchQueue.main.async { self.updateInsets(scrollView: scrollView, coord: coord) }
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coord = context.coordinator
        guard let stackView = coord.stackView else { return }
        
        if coord.lastLoadedMarkdown != markdownText {
            coord.lastLoadedMarkdown = markdownText
            let nodes = MarkdownParser.parse(markdownText)
            BlockRenderer.render(nodes: nodes, into: stackView, currentFileDirectory: currentFileURL?.deletingLastPathComponent())
        }
        updateInsets(scrollView: scrollView, coord: coord)
    }
    
    private func setupConstraints(scrollView: NSScrollView, flippedView: FlippedView, stackView: NSStackView, coord: Coordinator) {
        let scrollWidth = max(scrollView.contentSize.width, 400)
        let insetX = calcInsetX(scrollWidth)
        
        let widthC = flippedView.widthAnchor.constraint(greaterThanOrEqualToConstant: scrollWidth)
        let leading = stackView.leadingAnchor.constraint(equalTo: flippedView.leadingAnchor, constant: insetX)
        let trailing = stackView.trailingAnchor.constraint(equalTo: flippedView.trailingAnchor, constant: -insetX)
        let top = stackView.topAnchor.constraint(equalTo: flippedView.topAnchor, constant: 28)
        let bottom = stackView.bottomAnchor.constraint(equalTo: flippedView.bottomAnchor, constant: -40)
        bottom.priority = .defaultHigh
        NSLayoutConstraint.activate([widthC, leading, trailing, top, bottom])
        
        coord.widthC = widthC
        coord.leadingC = leading
        coord.trailingC = trailing
    }
    
    private func updateInsets(scrollView: NSScrollView, coord: Coordinator) {
        let scrollWidth = scrollView.contentSize.width
        guard scrollWidth > 0 else { return }
        let insetX = calcInsetX(scrollWidth)
        coord.widthC?.constant = scrollWidth
        coord.leadingC?.constant = insetX
        coord.trailingC?.constant = -insetX
    }
    
    private func calcInsetX(_ scrollWidth: CGFloat) -> CGFloat {
        let contentWidth = min(DesignTokens.maxContentWidth, scrollWidth - 80)
        let effectiveWidth = max(contentWidth, 300)
        return max(40, (scrollWidth - effectiveWidth) / 2)
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject {
        var parent: MarkdownEditorView
        weak var scrollView: NSScrollView?
        weak var stackView: NSStackView?
        weak var flippedView: FlippedView?
        var lastLoadedMarkdown: String = ""
        var leadingC: NSLayoutConstraint?
        var trailingC: NSLayoutConstraint?
        var widthC: NSLayoutConstraint?
        var selectionManager: BlockSelectionManager?
        
        init(_ parent: MarkdownEditorView) { self.parent = parent }
        
        @objc func themeDidChange() {
            guard let stackView = stackView else { return }
            // Force re-render with new colors
            let text = lastLoadedMarkdown
            guard !text.isEmpty else { return }
            let nodes = MarkdownParser.parse(text)
            BlockRenderer.render(nodes: nodes, into: stackView, currentFileDirectory: parent.currentFileURL?.deletingLastPathComponent())
            // Update window background
            scrollView?.window?.backgroundColor = DesignTokens.isDark ? .black : .white
        }
        
        @objc func frameDidChange(_ notification: Notification) {
            guard let scrollView = scrollView else { return }
            let scrollWidth = scrollView.contentSize.width
            guard scrollWidth > 0 else { return }
            let contentWidth = min(DesignTokens.maxContentWidth, scrollWidth - 80)
            let effectiveWidth = max(contentWidth, 300)
            let insetX = max(40, (scrollWidth - effectiveWidth) / 2)
            widthC?.constant = scrollWidth
            leadingC?.constant = insetX
            trailingC?.constant = -insetX
        }
    }
}

class FlippedView: NSView {
    override var isFlipped: Bool { true }
    var selectionManager: BlockSelectionManager?
    
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        selectionManager?.mouseDown(at: point)
        // Don't call super — it starts window drag or other default behavior
        // that prevents mouseDragged from being called
    }
    
    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        selectionManager?.mouseDragged(to: point)
    }
    
    override func mouseUp(with event: NSEvent) {
        selectionManager?.mouseUp()
        super.mouseUp(with: event)
    }
    
    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "c" {
            selectionManager?.copySelection()
        } else if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "a" {
            // Select all - not implemented yet
            super.keyDown(with: event)
        } else {
            super.keyDown(with: event)
        }
    }
    
    override var acceptsFirstResponder: Bool { true }
}
