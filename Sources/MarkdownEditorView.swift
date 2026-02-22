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
        
        // Flip the document view so stack grows top-down
        let flippedView = FlippedView()
        flippedView.translatesAutoresizingMaskIntoConstraints = false
        
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        flippedView.addSubview(stackView)
        scrollView.documentView = flippedView
        
        context.coordinator.scrollView = scrollView
        context.coordinator.stackView = stackView
        context.coordinator.flippedView = flippedView
        
        // Initial layout constraints
        updateLayoutConstraints(scrollView: scrollView, flippedView: flippedView, stackView: stackView)
        
        // Load content
        if !markdownText.isEmpty {
            let nodes = MarkdownParser.parse(markdownText)
            let fileDir = currentFileURL?.deletingLastPathComponent()
            BlockRenderer.render(nodes: nodes, into: stackView, currentFileDirectory: fileDir)
            context.coordinator.lastLoadedMarkdown = markdownText
        }
        
        // Monitor frame changes for responsive centering
        scrollView.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.frameDidChange(_:)),
            name: NSView.frameDidChangeNotification,
            object: scrollView
        )
        
        // Delay one frame to ensure correct initial sizing
        DispatchQueue.main.async {
            self.updateLayoutConstraints(scrollView: scrollView, flippedView: flippedView, stackView: stackView)
        }
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let stackView = context.coordinator.stackView,
              let flippedView = context.coordinator.flippedView else { return }
        
        // Re-render on content change
        if context.coordinator.lastLoadedMarkdown != markdownText {
            context.coordinator.lastLoadedMarkdown = markdownText
            let nodes = MarkdownParser.parse(markdownText)
            let fileDir = currentFileURL?.deletingLastPathComponent()
            BlockRenderer.render(nodes: nodes, into: stackView, currentFileDirectory: fileDir)
        }
        
        updateLayoutConstraints(scrollView: scrollView, flippedView: flippedView, stackView: stackView)
    }
    
    private func updateLayoutConstraints(scrollView: NSScrollView, flippedView: FlippedView, stackView: NSStackView) {
        let scrollWidth = scrollView.contentSize.width
        guard scrollWidth > 0 else { return }
        
        let contentWidth = min(DesignTokens.maxContentWidth, scrollWidth - 80)
        let effectiveWidth = max(contentWidth, 300)
        let insetX = max(40, (scrollWidth - effectiveWidth) / 2)
        
        // Remove old constraints
        flippedView.removeConstraints(flippedView.constraints.filter { c in
            c.identifier == "stack.leading" || c.identifier == "stack.trailing" ||
            c.identifier == "stack.top" || c.identifier == "stack.bottom" ||
            c.identifier == "flipped.width"
        })
        
        // Flipped view must be at least as wide as scroll view
        let widthC = flippedView.widthAnchor.constraint(greaterThanOrEqualToConstant: scrollWidth)
        widthC.identifier = "flipped.width"
        widthC.isActive = true
        
        let leading = stackView.leadingAnchor.constraint(equalTo: flippedView.leadingAnchor, constant: insetX)
        leading.identifier = "stack.leading"
        let trailing = stackView.trailingAnchor.constraint(equalTo: flippedView.trailingAnchor, constant: -insetX)
        trailing.identifier = "stack.trailing"
        let top = stackView.topAnchor.constraint(equalTo: flippedView.topAnchor, constant: 28)
        top.identifier = "stack.top"
        let bottom = stackView.bottomAnchor.constraint(equalTo: flippedView.bottomAnchor, constant: -40)
        bottom.identifier = "stack.bottom"
        bottom.priority = .defaultHigh
        
        NSLayoutConstraint.activate([leading, trailing, top, bottom])
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject {
        var parent: MarkdownEditorView
        weak var scrollView: NSScrollView?
        weak var stackView: NSStackView?
        weak var flippedView: FlippedView?
        var lastLoadedMarkdown: String = ""
        
        init(_ parent: MarkdownEditorView) {
            self.parent = parent
        }
        
        @objc func frameDidChange(_ notification: Notification) {
            guard let scrollView = scrollView,
                  let flippedView = flippedView,
                  let stackView = stackView else { return }
            
            let scrollWidth = scrollView.contentSize.width
            guard scrollWidth > 0 else { return }
            
            let contentWidth = min(DesignTokens.maxContentWidth, scrollWidth - 80)
            let effectiveWidth = max(contentWidth, 300)
            let insetX = max(40, (scrollWidth - effectiveWidth) / 2)
            
            // Update constraints
            for c in flippedView.constraints {
                if c.identifier == "flipped.width" {
                    c.constant = scrollWidth
                }
            }
            for c in flippedView.constraints + stackView.superview!.constraints {
                if c.identifier == "stack.leading" { c.constant = insetX }
                if c.identifier == "stack.trailing" { c.constant = -insetX }
            }
        }
    }
}

// MARK: - Flipped NSView (for top-down layout in scroll view)

class FlippedView: NSView {
    override var isFlipped: Bool { true }
}
