import AppKit
import Highlightr

/// Notion-quality code block: rounded container, language label, copy button,
/// line numbers, and Highlightr syntax highlighting.
class CodeBlockView: NSView {
    
    // MARK: - Subviews
    private let containerView = NSView()
    private let topBar = NSView()
    private let languageLabel = NSTextField(labelWithString: "")
    private let copyButton = NSButton()
    private let separatorLine = NSView()
    private let lineNumberColumn = NSTextField(wrappingLabelWithString: "")
    private let codeTextView = NSTextView()
    private let codeScrollView = NSScrollView()
    
    // MARK: - State
    private var copyResetTimer: Timer?
    private var trackingArea: NSTrackingArea?
    
    // Shared Highlightr
    private static let highlightr: Highlightr? = {
        let h = Highlightr()
        return h
    }()
    
    init(node: MarkdownNode, language: String?) {
        super.init(frame: .zero)
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
        lineNumberColumn.isEditable = false
        lineNumberColumn.isSelectable = false
        lineNumberColumn.drawsBackground = false
        lineNumberColumn.isBordered = false
        lineNumberColumn.alignment = .right
        lineNumberColumn.setContentHuggingPriority(.required, for: .horizontal)
        lineNumberColumn.setContentCompressionResistancePriority(.required, for: .horizontal)
        containerView.addSubview(lineNumberColumn)
        
        // Code text view (read-only, no scroll — we let the outer stack handle scrolling)
        codeScrollView.hasVerticalScroller = false
        codeScrollView.hasHorizontalScroller = false
        codeScrollView.drawsBackground = false
        codeScrollView.borderType = .noBorder
        
        codeTextView.isEditable = false
        codeTextView.isSelectable = true
        codeTextView.drawsBackground = false
        codeTextView.isRichText = true
        codeTextView.usesFontPanel = false
        codeTextView.isVerticallyResizable = true
        codeTextView.isHorizontallyResizable = false
        codeTextView.textContainerInset = .zero
        codeTextView.textContainer?.lineFragmentPadding = 0
        codeTextView.textContainer?.widthTracksTextView = true
        containerView.addSubview(codeTextView)
        
        // Populate content
        populateCode(node.content, language: language)
        
        layoutSubviews(hasLanguage: !(language ?? "").isEmpty)
        
        // Tracking area for hover
        updateTrackingAreas()
    }
    
    // MARK: - Content
    
    private func populateCode(_ code: String, language: String?) {
        let isDark = DesignTokens.isDark
        let themeName = isDark ? "atom-one-dark" : "atom-one-light"
        let codeFont = DesignTokens.codeFont
        
        Self.highlightr?.setTheme(to: themeName)
        Self.highlightr?.theme.codeFont = codeFont
        
        let langName = language?.lowercased()
        let highlighted: NSAttributedString
        if let h = Self.highlightr, let hl = h.highlight(code, as: langName) {
            highlighted = hl
        } else {
            let fallbackColor: NSColor = isDark ? NSColor(white: 0.8, alpha: 1) : NSColor(white: 0.2, alpha: 1)
            highlighted = NSAttributedString(string: code, attributes: [
                .font: codeFont,
                .foregroundColor: fallbackColor
            ])
        }
        
        // Apply line height to highlighted text
        let mutable = NSMutableAttributedString(attributedString: highlighted)
        let paraStyle = NSMutableParagraphStyle()
        paraStyle.lineHeightMultiple = DesignTokens.codeLineHeight
        mutable.addAttribute(.paragraphStyle, value: paraStyle, range: NSRange(location: 0, length: mutable.length))
        
        codeTextView.textStorage?.setAttributedString(mutable)
        
        // Line numbers
        let lines = code.components(separatedBy: "\n")
        let lineNumbers = (1...max(lines.count, 1)).map { String($0) }.joined(separator: "\n")
        
        let lineNumStyle = NSMutableParagraphStyle()
        lineNumStyle.lineHeightMultiple = DesignTokens.codeLineHeight
        lineNumStyle.alignment = .right
        
        let lineNumAttr = NSAttributedString(string: lineNumbers, attributes: [
            .font: codeFont,
            .foregroundColor: DesignTokens.secondaryColor.withAlphaComponent(0.5),
            .paragraphStyle: lineNumStyle
        ])
        lineNumberColumn.attributedStringValue = lineNumAttr
    }
    
    // MARK: - Layout
    
    private func layoutSubviews(hasLanguage: Bool) {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        topBar.translatesAutoresizingMaskIntoConstraints = false
        languageLabel.translatesAutoresizingMaskIntoConstraints = false
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        separatorLine.translatesAutoresizingMaskIntoConstraints = false
        lineNumberColumn.translatesAutoresizingMaskIntoConstraints = false
        codeTextView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
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
                
                lineNumberColumn.topAnchor.constraint(equalTo: separatorLine.bottomAnchor, constant: DesignTokens.sp12),
                lineNumberColumn.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: DesignTokens.sp12),
                lineNumberColumn.widthAnchor.constraint(greaterThanOrEqualToConstant: 24),
                
                codeTextView.topAnchor.constraint(equalTo: separatorLine.bottomAnchor, constant: DesignTokens.sp12),
                codeTextView.leadingAnchor.constraint(equalTo: lineNumberColumn.trailingAnchor, constant: DesignTokens.sp12),
                codeTextView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -DesignTokens.sp16),
                codeTextView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -DesignTokens.sp12),
            ])
        } else {
            topBar.isHidden = true
            separatorLine.isHidden = true
            
            NSLayoutConstraint.activate([
                lineNumberColumn.topAnchor.constraint(equalTo: containerView.topAnchor, constant: DesignTokens.sp16),
                lineNumberColumn.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: DesignTokens.sp12),
                lineNumberColumn.widthAnchor.constraint(greaterThanOrEqualToConstant: 24),
                
                codeTextView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: DesignTokens.sp16),
                codeTextView.leadingAnchor.constraint(equalTo: lineNumberColumn.trailingAnchor, constant: DesignTokens.sp12),
                codeTextView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -DesignTokens.sp16),
                codeTextView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -DesignTokens.sp16),
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
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
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
        let code = codeTextView.string
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        
        // Show checkmark feedback
        copyButton.title = "✓"
        copyResetTimer?.invalidate()
        copyResetTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            self?.copyButton.title = "Copy"
        }
    }
}
