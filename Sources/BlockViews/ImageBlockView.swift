import AppKit

/// Renders an image block with optional alt text caption.
class ImageBlockView: NSView {
    private let imageLayer = CALayer()
    private let captionField = NSTextField(wrappingLabelWithString: "")
    private var currentFileDirectory: URL?
    private var displayHeight: CGFloat = 24  // minimum height for placeholder
    private var displayWidth: CGFloat = 200
    
    init(alt: String, urlString: String, currentFileDirectory: URL?) {
        self.currentFileDirectory = currentFileDirectory
        super.init(frame: .zero)
        setupView(alt: alt, urlString: urlString)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override var intrinsicContentSize: NSSize {
        let captionH = captionField.isHidden ? 0 : captionField.intrinsicContentSize.height + 4
        return NSSize(width: NSView.noIntrinsicMetric, height: displayHeight + captionH)
    }
    
    private func setupView(alt: String, urlString: String) {
        wantsLayer = true
        
        // Caption
        captionField.isEditable = false
        captionField.isSelectable = true
        captionField.drawsBackground = false
        captionField.isBordered = false
        captionField.alignment = .center
        captionField.font = NSFont.systemFont(ofSize: DesignTokens.bodySize - 2)
        captionField.textColor = NSColor.secondaryLabelColor
        captionField.lineBreakMode = .byWordWrapping
        captionField.cell?.wraps = true
        captionField.cell?.isScrollable = false
        captionField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        if alt.isEmpty {
            captionField.isHidden = true
        } else {
            captionField.stringValue = alt
        }
        
        addSubview(captionField)
        captionField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            captionField.leadingAnchor.constraint(equalTo: leadingAnchor),
            captionField.trailingAnchor.constraint(equalTo: trailingAnchor),
            captionField.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        
        loadImage(alt: alt, urlString: urlString)
    }
    
    private func loadImage(alt: String, urlString: String) {
        var imageURL: URL?
        
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            imageURL = URL(string: urlString)
        } else if let dir = currentFileDirectory {
            imageURL = dir.appendingPathComponent(urlString)
        }
        
        guard let url = imageURL else {
            showPlaceholder(alt: alt)
            return
        }
        
        if url.isFileURL {
            if let image = NSImage(contentsOf: url) {
                applyImage(image)
            } else {
                showPlaceholder(alt: alt)
            }
        } else {
            showPlaceholder(alt: "⏳ Loading...")
            let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 15)
            URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
                guard let self = self, let data = data, error == nil,
                      let image = NSImage(data: data) else {
                    DispatchQueue.main.async { self?.showPlaceholder(alt: alt) }
                    return
                }
                DispatchQueue.main.async { self.applyImage(image) }
            }.resume()
        }
    }
    
    private func applyImage(_ image: NSImage) {
        // Use pixel dimensions for accurate sizing
        let pixelSize: NSSize
        if let rep = image.representations.first, rep.pixelsWide > 0 {
            pixelSize = NSSize(width: rep.pixelsWide, height: rep.pixelsHigh)
        } else {
            pixelSize = image.size
        }
        
        let maxW = min(DesignTokens.maxContentWidth - DesignTokens.sp32, bounds.width > 0 ? bounds.width : 700)
        let scale = pixelSize.width > maxW ? maxW / pixelSize.width : 1.0
        displayWidth = pixelSize.width * scale
        displayHeight = pixelSize.height * scale
        
        // Use NSImageView directly as subview (simplest approach)
        let iv = NSImageView()
        iv.image = image
        iv.imageScaling = .scaleProportionallyUpOrDown
        iv.animates = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iv)
        
        NSLayoutConstraint.activate([
            iv.topAnchor.constraint(equalTo: topAnchor),
            iv.centerXAnchor.constraint(equalTo: centerXAnchor),
            iv.widthAnchor.constraint(equalToConstant: displayWidth),
            iv.heightAnchor.constraint(equalToConstant: displayHeight),
        ])
        
        if !captionField.isHidden {
            captionField.topAnchor.constraint(equalTo: iv.bottomAnchor, constant: 4).isActive = true
        }
        
        // Update intrinsic size
        invalidateIntrinsicContentSize()
        
        // Force the stack view to re-layout
        if let stack = superview as? NSStackView {
            stack.needsLayout = true
            stack.needsUpdateConstraints = true
        }
    }
    
    private func showPlaceholder(alt: String) {
        let text = alt.isEmpty ? "🖼 [Image]" : "🖼 \(alt)"
        captionField.stringValue = text
        captionField.isHidden = false
        captionField.alignment = .center
        displayHeight = 24
        invalidateIntrinsicContentSize()
    }
}
