import AppKit
import Highlightr

/// Non-selectable NSTextField that won't activate field editor on click.
/// Text selection is handled by the parent CodeBlockView's CopyableBlock protocol.
private class CodeTextField: NSTextField {
    override var acceptsFirstResponder: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { false }
}

/// Notion-quality code block: rounded container, language label, copy button,
/// line numbers, and Highlightr syntax highlighting.
class CodeBlockView: NSView, CopyableBlock {
    
    // MARK: - Subviews
    private let containerView = NSView()
    private let topBar = NSView()
    private let languageLabel = NSTextField(labelWithString: "")
    private let copyButton = NSButton()
    private let separatorLine = NSView()
    private let lineNumberLabel = NSTextField(wrappingLabelWithString: "")
    private let codeLabel = CodeTextField(wrappingLabelWithString: "")
    
    // MARK: - State
    private var copyResetTimer: Timer?
    private var trackingArea: NSTrackingArea?
    private var codeContent: String = ""
    var copyableText: String { codeContent }
    
    init(node: MarkdownNode, language: String?) {
        super.init(frame: .zero)
        codeContent = node.content
        setupView(node: node, language: language)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    // MARK: - Setup
    
    private func setupView(node: MarkdownNode, language: String?) {
        wantsLayer = true
        
        // Container — rounded rect with border
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 8
        containerView.layer?.masksToBounds = true
        containerView.layer?.borderWidth = 1
        applyContainerColors()
        addSubview(containerView)
        
        // Top bar (language label + copy button)
        topBar.wantsLayer = true
        containerView.addSubview(topBar)
        
        // Language label
        languageLabel.isEditable = false
        languageLabel.isSelectable = false
        languageLabel.drawsBackground = false
        languageLabel.isBordered = false
        languageLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        languageLabel.textColor = DesignTokens.secondaryColor
        languageLabel.stringValue = language ?? ""
        languageLabel.isHidden = (language ?? "").isEmpty
        topBar.addSubview(languageLabel)
        
        // Copy button — hidden by default, shown on hover
        copyButton.bezelStyle = .inline
        copyButton.isBordered = false
        copyButton.title = "Copy"
        copyButton.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        copyButton.contentTintColor = DesignTokens.secondaryColor
        copyButton.target = self
        copyButton.action = #selector(copyCode)
        copyButton.alphaValue = 0
        topBar.addSubview(copyButton)
        
        // Separator between top bar and code
        separatorLine.wantsLayer = true
        separatorLine.layer?.backgroundColor = DesignTokens.codeBorder.cgColor
        separatorLine.isHidden = (language ?? "").isEmpty
        containerView.addSubview(separatorLine)
        
        // Line numbers
        lineNumberLabel.isEditable = false
        lineNumberLabel.isSelectable = false
        lineNumberLabel.drawsBackground = false
        lineNumberLabel.isBordered = false
        lineNumberLabel.maximumNumberOfLines = 0
        lineNumberLabel.lineBreakMode = .byClipping
        lineNumberLabel.setContentHuggingPriority(.required, for: .horizontal)
        lineNumberLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        containerView.addSubview(lineNumberLabel)
        
        // Code content — CodeTextField (no field editor, no click style change)
        codeLabel.isEditable = false
        codeLabel.isSelectable = false
        codeLabel.drawsBackground = false
        codeLabel.isBordered = false
        codeLabel.maximumNumberOfLines = 0
        codeLabel.lineBreakMode = .byClipping
        codeLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        containerView.addSubview(codeLabel)
        
        populateCode(node.content, language: language)
        layoutSubviews(hasLanguage: !(language ?? "").isEmpty)
        updateTrackingAreas()
    }
    
    // MARK: - Content
    
    private func populateCode(_ code: String, language: String?) {
        let isDark = DesignTokens.isDark
        let codeFont = DesignTokens.codeFont
        let fallbackColor: NSColor = isDark ? NSColor(white: 0.8, alpha: 1) : NSColor(white: 0.2, alpha: 1)
        
        let paraStyle = NSMutableParagraphStyle()
        paraStyle.lineHeightMultiple = DesignTokens.codeLineHeight
        codeLabel.attributedStringValue = NSAttributedString(string: code, attributes: [
            .font: codeFont, .foregroundColor: fallbackColor, .paragraphStyle: paraStyle
        ])
        
        // Async syntax highlight
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let h = Highlightr()
            let themeName = isDark ? "atom-one-dark" : "atom-one-light"
            h?.setTheme(to: themeName)
            h?.theme.codeFont = codeFont
            let langName = language?.lowercased()
            guard let hl = h?.highlight(code, as: langName) else { return }
            let mutable = NSMutableAttributedString(attributedString: hl)
            mutable.removeAttribute(.backgroundColor, range: NSRange(location: 0, length: mutable.length))
            mutable.addAttribute(.paragraphStyle, value: paraStyle, range: NSRange(location: 0, length: mutable.length))
            DispatchQueue.main.async {
                self?.codeLabel.attributedStringValue = mutable
            }
        }
        
        // Line numbers
        let lines = code.components(separatedBy: "\n")
        let lineNumbers = (1...max(lines.count, 1)).map { String($0) }.joined(separator: "\n")
        let lineNumStyle = NSMutableParagraphStyle()
        lineNumStyle.lineHeightMultiple = DesignTokens.codeLineHeight
        lineNumStyle.alignment = .right
        lineNumberLabel.attributedStringValue = NSAttributedString(string: lineNumbers, attributes: [
            .font: codeFont,
            .foregroundColor: DesignTokens.secondaryColor.withAlphaComponent(0.5),
            .paragraphStyle: lineNumStyle
        ])
    }
    
    // MARK: - Layout
    
    private func layoutSubviews(hasLanguage: Bool) {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        topBar.translatesAutoresizingMaskIntoConstraints = false
        languageLabel.translatesAutoresizingMaskIntoConstraints = false
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        separatorLine.translatesAutoresizingMaskIntoConstraints = false
        lineNumberLabel.translatesAutoresizingMaskIntoConstraints = false
        codeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor, constant: DesignTokens.sp4),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -DesignTokens.sp4),
        ])
        
        if hasLanguage {
            NSLayoutConstraint.activate([
                topBar.topAnchor.constraint(equalTo: containerView.topAnchor),
                topBar.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                topBar.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                topBar.heightAnchor.constraint(equalToConstant: 32),
                
                languageLabel.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: DesignTokens.sp16),
                languageLabel.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
                
                copyButton.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -DesignTokens.sp12),
                copyButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
                
                separatorLine.topAnchor.constraint(equalTo: topBar.bottomAnchor),
                separatorLine.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                separatorLine.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                separatorLine.heightAnchor.constraint(equalToConstant: 0.5),
                
                lineNumberLabel.topAnchor.constraint(equalTo: separatorLine.bottomAnchor, constant: DesignTokens.sp12),
                lineNumberLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: DesignTokens.sp12),
                lineNumberLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 24),
                
                codeLabel.topAnchor.constraint(equalTo: separatorLine.bottomAnchor, constant: DesignTokens.sp12),
                codeLabel.leadingAnchor.constraint(equalTo: lineNumberLabel.trailingAnchor, constant: DesignTokens.sp12),
                codeLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -DesignTokens.sp16),
                codeLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -DesignTokens.sp12),
            ])
        } else {
            topBar.isHidden = true
            separatorLine.isHidden = true
            
            NSLayoutConstraint.activate([
                lineNumberLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: DesignTokens.sp16),
                lineNumberLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: DesignTokens.sp12),
                lineNumberLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 24),
                
                codeLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: DesignTokens.sp16),
                codeLabel.leadingAnchor.constraint(equalTo: lineNumberLabel.trailingAnchor, constant: DesignTokens.sp12),
                codeLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -DesignTokens.sp16),
                codeLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -DesignTokens.sp16),
            ])
        }
    }
    
    // MARK: - Colors
    
    private func applyContainerColors() {
        containerView.layer?.backgroundColor = DesignTokens.codeBackground.cgColor
        containerView.layer?.borderColor = DesignTokens.codeBorder.cgColor
    }
    
    override func updateLayer() {
        super.updateLayer()
        applyContainerColors()
        separatorLine.layer?.backgroundColor = DesignTokens.codeBorder.cgColor
    }
    
    // MARK: - Hover (copy button)
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea { removeTrackingArea(existing) }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self, userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }
    
    override func mouseEntered(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            copyButton.animator().alphaValue = 1
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            copyButton.animator().alphaValue = 0
        }
    }
    
    // MARK: - Copy
    
    @objc private func copyCode() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(codeContent, forType: .string)
        copyButton.title = "✓"
        copyResetTimer?.invalidate()
        copyResetTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            self?.copyButton.title = "Copy"
        }
    }
}