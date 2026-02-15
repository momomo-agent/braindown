import AppKit

/// Renders a horizontal rule — a subtle divider line.
class HorizontalRuleView: NSView {
    private let line = NSView()
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupView() {
        wantsLayer = true
        
        line.wantsLayer = true
        line.layer?.backgroundColor = DesignTokens.ruleColor.cgColor
        addSubview(line)
        
        line.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            line.centerYAnchor.constraint(equalTo: centerYAnchor),
            line.leadingAnchor.constraint(equalTo: leadingAnchor),
            line.trailingAnchor.constraint(equalTo: trailingAnchor),
            line.heightAnchor.constraint(equalToConstant: 1),
            
            heightAnchor.constraint(equalToConstant: DesignTokens.sp24),
        ])
    }
    
    override func updateLayer() {
        super.updateLayer()
        line.layer?.backgroundColor = DesignTokens.ruleColor.cgColor
    }
}
