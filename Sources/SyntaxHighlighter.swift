import AppKit

// 简单的语法高亮：基于关键字匹配
class SyntaxHighlighter {
    
    struct Theme {
        let keyword: NSColor
        let string: NSColor
        let comment: NSColor
        let number: NSColor
        let type: NSColor
        let function: NSColor
        let plain: NSColor
        let background: NSColor
        
        static var dark: Theme {
            Theme(
                keyword: NSColor(red: 0.78, green: 0.46, blue: 0.82, alpha: 1),   // purple
                string: NSColor(red: 0.64, green: 0.83, blue: 0.45, alpha: 1),    // green
                comment: NSColor(red: 0.45, green: 0.50, blue: 0.55, alpha: 1),   // gray
                number: NSColor(red: 0.82, green: 0.68, blue: 0.40, alpha: 1),    // yellow
                type: NSColor(red: 0.40, green: 0.78, blue: 0.82, alpha: 1),      // cyan
                function: NSColor(red: 0.38, green: 0.65, blue: 0.92, alpha: 1),  // blue
                plain: NSColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1),
                background: NSColor(white: 0.15, alpha: 1)
            )
        }
        
        static var light: Theme {
            Theme(
                keyword: NSColor(red: 0.61, green: 0.10, blue: 0.66, alpha: 1),
                string: NSColor(red: 0.20, green: 0.55, blue: 0.17, alpha: 1),
                comment: NSColor(red: 0.50, green: 0.55, blue: 0.58, alpha: 1),
                number: NSColor(red: 0.75, green: 0.49, blue: 0.07, alpha: 1),
                type: NSColor(red: 0.07, green: 0.49, blue: 0.56, alpha: 1),
                function: NSColor(red: 0.16, green: 0.38, blue: 0.73, alpha: 1),
                plain: NSColor(red: 0.20, green: 0.20, blue: 0.20, alpha: 1),
                background: NSColor(white: 0.95, alpha: 1)
            )
        }
        
        static var current: Theme {
            if NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return .dark
            }
            return .light
        }
    }
    
    // 各语言关键字
    private static let keywords: [String: Set<String>] = [
        "swift": ["import", "func", "var", "let", "class", "struct", "enum", "protocol", "extension",
                  "if", "else", "guard", "switch", "case", "default", "for", "while", "repeat",
                  "return", "throw", "throws", "try", "catch", "do", "in", "where", "as", "is",
                  "self", "Self", "super", "init", "deinit", "nil", "true", "false",
                  "public", "private", "internal", "fileprivate", "open", "static", "override",
                  "mutating", "nonmutating", "lazy", "weak", "unowned", "async", "await",
                  "some", "any", "typealias", "associatedtype", "inout", "convenience", "required",
                  "@State", "@Binding", "@Published", "@ObservedObject", "@StateObject",
                  "@Environment", "@EnvironmentObject", "@MainActor", "@Observable"],
        "python": ["def", "class", "import", "from", "as", "if", "elif", "else", "for", "while",
                   "return", "yield", "try", "except", "finally", "raise", "with", "pass", "break",
                   "continue", "and", "or", "not", "in", "is", "None", "True", "False", "lambda",
                   "global", "nonlocal", "del", "assert", "async", "await", "self", "print"],
        "javascript": ["function", "const", "let", "var", "if", "else", "for", "while", "do",
                       "return", "throw", "try", "catch", "finally", "class", "extends", "new",
                       "this", "super", "import", "export", "default", "from", "of", "in",
                       "typeof", "instanceof", "null", "undefined", "true", "false", "async",
                       "await", "yield", "switch", "case", "break", "continue", "delete", "void"],
        "typescript": ["function", "const", "let", "var", "if", "else", "for", "while", "do",
                       "return", "throw", "try", "catch", "finally", "class", "extends", "new",
                       "this", "super", "import", "export", "default", "from", "of", "in",
                       "typeof", "instanceof", "null", "undefined", "true", "false", "async",
                       "await", "yield", "switch", "case", "break", "continue", "type", "interface",
                       "enum", "implements", "abstract", "readonly", "private", "public", "protected"],
        "rust": ["fn", "let", "mut", "const", "if", "else", "match", "for", "while", "loop",
                 "return", "break", "continue", "struct", "enum", "impl", "trait", "type", "use",
                 "mod", "pub", "crate", "self", "super", "where", "as", "in", "ref", "move",
                 "async", "await", "dyn", "static", "unsafe", "extern", "true", "false", "None", "Some"],
        "go": ["func", "var", "const", "type", "struct", "interface", "map", "chan", "if", "else",
               "for", "range", "switch", "case", "default", "return", "break", "continue", "go",
               "defer", "select", "package", "import", "nil", "true", "false", "make", "new",
               "append", "len", "cap", "delete", "copy", "close"],
    ]
    
    // 通用关键字（用于未知语言）
    private static let genericKeywords: Set<String> = [
        "if", "else", "for", "while", "return", "function", "class", "import", "var", "let",
        "const", "def", "fn", "struct", "enum", "true", "false", "null", "nil", "None",
        "try", "catch", "throw", "new", "this", "self", "super", "public", "private", "static"
    ]
    
    static func highlight(_ code: String, language: String?, font: NSFont) -> NSAttributedString {
        let theme = Theme.current
        let lang = language?.lowercased() ?? ""
        let kws = keywords[lang] ?? genericKeywords
        
        let result = NSMutableAttributedString()
        let lines = code.components(separatedBy: "\n")
        
        for (lineIdx, line) in lines.enumerated() {
            highlightLine(line, keywords: kws, theme: theme, font: font, into: result)
            if lineIdx < lines.count - 1 {
                result.append(NSAttributedString(string: "\n", attributes: [.font: font, .foregroundColor: theme.plain]))
            }
        }
        
        return result
    }
    
    private static func highlightLine(_ line: String, keywords: Set<String>, theme: Theme, font: NSFont, into result: NSMutableAttributedString) {
        let chars = Array(line)
        var i = 0
        
        while i < chars.count {
            // 行注释 // 或 #
            if i + 1 < chars.count && chars[i] == "/" && chars[i+1] == "/" {
                let rest = String(chars[i...])
                result.append(NSAttributedString(string: rest, attributes: [.font: font, .foregroundColor: theme.comment]))
                return
            }
            if chars[i] == "#" && (i == 0 || chars[i-1] == " ") {
                // Python 注释（排除 Swift 的 # 开头属性）
                let rest = String(chars[i...])
                if !rest.hasPrefix("#[") && !rest.hasPrefix("#!") {
                    result.append(NSAttributedString(string: rest, attributes: [.font: font, .foregroundColor: theme.comment]))
                    return
                }
            }
            
            // 字符串 "..." 或 '...'
            if chars[i] == "\"" || chars[i] == "'" {
                let quote = chars[i]
                var str = String(quote)
                i += 1
                while i < chars.count && chars[i] != quote {
                    if chars[i] == "\\" && i + 1 < chars.count {
                        str.append(chars[i])
                        i += 1
                    }
                    str.append(chars[i])
                    i += 1
                }
                if i < chars.count {
                    str.append(chars[i])
                    i += 1
                }
                result.append(NSAttributedString(string: str, attributes: [.font: font, .foregroundColor: theme.string]))
                continue
            }
            
            // 数字
            if chars[i].isNumber && (i == 0 || !chars[i-1].isLetter) {
                var num = ""
                while i < chars.count && (chars[i].isNumber || chars[i] == "." || chars[i] == "x" || chars[i] == "X") {
                    num.append(chars[i])
                    i += 1
                }
                result.append(NSAttributedString(string: num, attributes: [.font: font, .foregroundColor: theme.number]))
                continue
            }
            
            // 标识符/关键字
            if chars[i].isLetter || chars[i] == "_" || chars[i] == "@" {
                var word = ""
                while i < chars.count && (chars[i].isLetter || chars[i].isNumber || chars[i] == "_" || chars[i] == "@") {
                    word.append(chars[i])
                    i += 1
                }
                
                let color: NSColor
                if keywords.contains(word) {
                    color = theme.keyword
                } else if word.first?.isUppercase == true {
                    color = theme.type
                } else if i < chars.count && chars[i] == "(" {
                    color = theme.function
                } else {
                    color = theme.plain
                }
                result.append(NSAttributedString(string: word, attributes: [.font: font, .foregroundColor: color]))
                continue
            }
            
            // 其他字符
            result.append(NSAttributedString(string: String(chars[i]), attributes: [.font: font, .foregroundColor: theme.plain]))
            i += 1
        }
    }
}
