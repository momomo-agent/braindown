import AppKit

/// Manages cross-block text selection by overlaying highlight rects
/// and intercepting mouse events at the scroll view level.
class BlockSelectionManager {
    
    private weak var scrollView: NSScrollView?
    private weak var stackView: NSStackView?
    private var highlightLayer = CALayer()
    private var selectionStart: NSPoint?
    private var selectionEnd: NSPoint?
    private var selectedText: String = ""
    private var highlightLayers: [CALayer] = []
    
    init(scrollView: NSScrollView, stackView: NSStackView) {
        self.scrollView = scrollView
        self.stackView = stackView
    }
    
    // MARK: - Mouse Events
    
    func mouseDown(at point: NSPoint) {
        clearSelection()
        selectionStart = point
        selectionEnd = nil
    }
    
    func mouseDragged(to point: NSPoint) {
        selectionEnd = point
        updateSelection()
    }
    
    func mouseUp() {
        // Keep selection visible
    }
    
    func clearSelection() {
        selectionStart = nil
        selectionEnd = nil
        selectedText = ""
        for layer in highlightLayers {
            layer.removeFromSuperlayer()
        }
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
        
        // Clear old highlights
        for layer in highlightLayers { layer.removeFromSuperlayer() }
        highlightLayers.removeAll()
        
        let minY = min(start.y, end.y)
        let maxY = max(start.y, end.y)
        var texts: [String] = []
        
        for view in stackView.arrangedSubviews {
            let frame = view.convert(view.bounds, to: documentView)
            
            // Check if this block overlaps with selection range
            if frame.maxY >= minY && frame.minY <= maxY {
                // This block is in the selection range
                if let text = extractText(from: view) {
                    texts.append(text)
                }
                // Draw highlight
                addHighlight(for: frame, in: documentView)
            }
        }
        
        selectedText = texts.joined(separator: "\n")
    }
    
    private func extractText(from view: NSView) -> String? {
        // Find NSTextField in the view hierarchy
        if let tf = view as? NSTextField { return tf.stringValue }
        for sub in view.subviews {
            if let text = extractText(from: sub) { return text }
        }
        return nil
    }
    
    private func addHighlight(for frame: NSRect, in parentView: NSView) {
        let layer = CALayer()
        let isDark = DesignTokens.isDark
        layer.backgroundColor = (isDark
            ? NSColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 0.3)
            : NSColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 0.2)).cgColor
        // FlippedView uses flipped coords
        layer.frame = frame
        parentView.layer?.addSublayer(layer)
        highlightLayers.append(layer)
    }
}
