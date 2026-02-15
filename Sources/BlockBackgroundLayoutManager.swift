import AppKit

// 自定义 attribute key，标记代码块/表格的背景范围
extension NSAttributedString.Key {
    static let blockBackground = NSAttributedString.Key("BrainDown.blockBackground")
}

/// 自定义 LayoutManager：为代码块和表格画完整的圆角矩形背景
class BlockBackgroundLayoutManager: NSLayoutManager {
    
    override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        super.drawBackground(forGlyphRange: glyphsToShow, at: origin)
        
        guard let textStorage = textStorage, let context = NSGraphicsContext.current?.cgContext else { return }
        
        let charRange = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
        
        // 找到所有带 blockBackground 的连续范围
        var blockRanges: [(range: NSRange, color: NSColor)] = []
        textStorage.enumerateAttribute(.blockBackground, in: charRange, options: []) { value, range, _ in
            if let color = value as? NSColor {
                // 合并相邻的同色块
                if let last = blockRanges.last, last.color == color,
                   NSMaxRange(last.range) == range.location {
                    blockRanges[blockRanges.count - 1].range.length += range.length
                } else {
                    blockRanges.append((range: range, color: color))
                }
            }
        }
        
        let cornerRadius: CGFloat = 8
        let hPadding: CGFloat = 8  // 左右额外扩展
        
        for block in blockRanges {
            let glyphRange = self.glyphRange(forCharacterRange: block.range, actualCharacterRange: nil)
            guard let textContainer = textContainer(forGlyphAt: glyphRange.location, effectiveRange: nil) else { continue }
            
            // 收集所有行的 rect，合并成一个大矩形
            var unionRect = NSRect.zero
            enumerateLineFragments(forGlyphRange: glyphRange) { lineRect, usedRect, _, _, _ in
                let r = NSRect(
                    x: lineRect.origin.x + origin.x - hPadding,
                    y: lineRect.origin.y + origin.y,
                    width: textContainer.containerSize.width + hPadding * 2,
                    height: lineRect.height
                )
                if unionRect == .zero {
                    unionRect = r
                } else {
                    unionRect = unionRect.union(r)
                }
            }
            
            guard unionRect != .zero else { continue }
            
            // 画圆角矩形背景
            context.saveGState()
            let path = NSBezierPath(roundedRect: unionRect, xRadius: cornerRadius, yRadius: cornerRadius)
            block.color.setFill()
            path.fill()
            context.restoreGState()
        }
    }
}
