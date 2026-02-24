import AppKit

/// Manages cross-block text selection by overlaying highlight rects
/// and intercepting mouse events at the scroll view level.
class BlockSelectionManager {
    
    private weak var scrollView: NSScrollView?
    private weak var stackView: NSStackView?
    private var selectionStart: NSPoint?
    private var selectionEnd: NSPoint?
    private var selectedText: String = ""
    private var highlightLayers: [CALayer] = []
    
    init(scrollView: NSScrollView, stackView: NSStackView) {
        self.scrollView = scrollView
        self.stackView = stackView
    }
    
    // MARK: - Mouse Events
    
    func mouseDown(at pointInDoc: NSPoint) {
        clearSelection()
        selectionStart = pointInDoc
        selectionEnd = nil
    }
    
    func mouseDragged(to pointInDoc: NSPoint) {
        selectionEnd = pointInDoc
        updateSelection()
    }
    
    func mouseUp() {}
    
    func clearSelection() {
        selectionStart = nil
        selectionEnd = nil
        selectedText = ""
        for layer in highlightLayers { layer.removeFromSuperlayer() }
        highlightLayers.removeAll()
    }
    
    // MARK: - Copy
    
    func copySelection() {
        guard !selectedText.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(selectedText, forType: .string)
    }
    
    var hasSelection: Bool { !selectedText.isEmpty }
    
    // MARK: - Selection Logic
    
    private func updateSelection() {
        guard let stackView = stackView,
              let documentView = scrollView?.documentView,
              let start = selectionStart,
              let end = selectionEnd else { return }
        
        for layer in highlightLayers { layer.removeFromSuperlayer() }
        highlightLayers.removeAll()
        
        // Both start/end are in documentView (FlippedView) coords
        let minY = min(start.y, end.y)
        let maxY = max(start.y, end.y)
        var texts: [String] = []
        
        for view in stackView.arrangedSubviews {
            // Convert block frame to documentView coords
            let frameInDoc = view.convert(view.bounds, to: documentView)
            
            // Block overlaps selection range?
            guard frameInDoc.maxY >= minY && frameInDoc.minY <= maxY else { continue }
            
            if let block = view as? CopyableBlock, !block.copyableText.isEmpty {
                texts.append(block.copyableText)
            }
            addHighlight(for: frameInDoc, in: documentView)
        }
        
        selectedText = texts.joined(separator: "\n\n")
    }
    
    private func addHighlight(for frame: NSRect, in parentView: NSView) {
        let layer = CALayer()
        let isDark = DesignTokens.isDark
        layer.backgroundColor = (isDark
            ? NSColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 0.3)
            : NSColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 0.2)).cgColor
        layer.frame = frame
        parentView.layer?.addSublayer(layer)
        highlightLayers.append(layer)
    }
}
