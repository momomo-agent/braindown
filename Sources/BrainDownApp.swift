import SwiftUI

@main
struct BrainDownApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var fileTypeSettings = FileTypeSettings.shared
    @ObservedObject private var appSettings = AppSettings.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Folder…") {
                    NotificationCenter.default.post(name: .openFolder, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
                
                Button("Open File…") {
                    NotificationCenter.default.post(name: .openSingleFile, object: nil)
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
                
                Divider()
                
                Button("Save") {
                    NotificationCenter.default.post(name: .saveFile, object: nil)
                }
                .keyboardShortcut("s", modifiers: .command)
            }
            
            CommandMenu("View") {
                // Read/Write toggle
                Button(appSettings.editorMode == .read ? "Switch to Edit Mode" : "Switch to Read Mode") {
                    appSettings.editorMode = appSettings.editorMode == .read ? .write : .read
                }
                .keyboardShortcut("e", modifiers: .command)
                
                Divider()
                
                // Font
                Toggle("Serif Font", isOn: $appSettings.useSerifFont)
                    .keyboardShortcut("f", modifiers: [.command, .shift])
                
                Divider()
                
                // Theme
                Menu("Theme") {
                    ForEach(AppTheme.allCases, id: \.rawValue) { theme in
                        Toggle(theme.label, isOn: Binding(
                            get: { appSettings.theme == theme },
                            set: { if $0 { appSettings.theme = theme } }
                        ))
                    }
                }
                
                // File types
                Menu("Visible File Types") {
                    ForEach(FileTypeSettings.allTypes, id: \.ext) { type in
                        Toggle(type.label, isOn: Binding(
                            get: { fileTypeSettings.enabledExtensions.contains(type.ext) },
                            set: { _ in fileTypeSettings.toggle(type.ext) }
                        ))
                    }
                }
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure all windows for clean titlebar
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            for window in NSApp.windows {
                window.isMovableByWindowBackground = true
                window.backgroundColor = DesignTokens.isDark ? .black : .white
            }
        }
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        
        if isDir.boolValue {
            NotificationCenter.default.post(name: .openFolderURL, object: url)
        } else {
            NotificationCenter.default.post(name: .openSingleFile, object: url)
        }
    }
}

extension Notification.Name {
    static let openFolder = Notification.Name("BrainDown.openFolder")
    static let openFolderURL = Notification.Name("BrainDown.openFolderURL")
    static let saveFile = Notification.Name("BrainDown.saveFile")
    static let fsChanged = Notification.Name("BrainDown.fsChanged")
    static let openSingleFile = Notification.Name("BrainDown.openSingleFile")
    static let themeChanged = Notification.Name("BrainDown.themeChanged")
}
