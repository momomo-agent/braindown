// BrainDown 验证工具：用真实的 MarkdownTextStorage 离屏渲染 → PNG
// 用法: bd-verify <input.md> <output.png> [width]

import AppKit
import Foundation

@main
struct BDVerify {
    static func main() {
        let args = CommandLine.arguments
        guard args.count >= 3 else {
            print("Usage: bd-verify <input.md> <output.png> [width]")
            exit(1)
        }
        
        let inputPath = args[1]
        let outputPath = args[2]
        let width: CGFloat = args.count >= 4 ? CGFloat(Double(args[3]) ?? 680) : 680
        
        guard let markdown = try? String(contentsOfFile: inputPath, encoding: .utf8) else {
            print("Error: Cannot read \(inputPath)")
            exit(1)
        }
        
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        
        let textStorage = MarkdownTextStorage()
        textStorage.currentFileDirectory = URL(fileURLWithPath: inputPath).deletingLastPathComponent()
        
        let layoutManager = BlockBackgroundLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        
        let textContainer = NSTextContainer(size: NSSize(width: width, height: .greatestFiniteMagnitude))
        textContainer.widthTracksTextView = false
        layoutManager.addTextContainer(textContainer)
        
        let totalWidth = width + 80
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: totalWidth, height: 800), textContainer: textContainer)
        textView.textContainerInset = NSSize(width: 40, height: 40)
        textView.isEditable = false
        textView.drawsBackground = true
        textView.backgroundColor = .white
        
        textStorage.loadMarkdown(markdown)
        
        layoutManager.ensureLayout(for: textContainer)
        let usedRect = layoutManager.usedRect(for: textContainer)
        let totalHeight = usedRect.height + 80
        textView.frame = NSRect(x: 0, y: 0, width: totalWidth, height: totalHeight)
        
        guard let bitmapRep = textView.bitmapImageRepForCachingDisplay(in: textView.bounds) else {
            print("Error: bitmapImageRepForCachingDisplay failed")
            exit(1)
        }
        textView.cacheDisplay(in: textView.bounds, to: bitmapRep)
        
        let image = NSImage(size: textView.bounds.size)
        image.addRepresentation(bitmapRep)
        
        guard let tiffData = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiffData),
              let pngData = rep.representation(using: .png, properties: [:]) else {
            print("Error: PNG conversion failed")
            exit(1)
        }
        
        do {
            try pngData.write(to: URL(fileURLWithPath: outputPath))
            print("OK: \(outputPath) (\(Int(totalWidth))x\(Int(totalHeight)))")
        } catch {
            print("Error: \(error)")
            exit(1)
        }
    }
}
