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
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Folder…") {
                    NotificationCenter.default.post(name: .openFolder, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
                
                Divider()
                
                Button("Save") {
                    NotificationCenter.default.post(name: .saveFile, object: nil)
                }
                .keyboardShortcut("s", modifiers: .command)
            }
            
            CommandMenu("View") {
                Menu("Theme") {
                    ForEach(AppTheme.allCases, id: \.rawValue) { theme in
                        Toggle(theme.label, isOn: Binding(
                            get: { appSettings.theme == theme },
                            set: { if $0 { appSettings.theme = theme } }
                        ))
                    }
                }
                
                Divider()
                
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
}

extension Notification.Name {
    static let openFolder = Notification.Name("BrainDown.openFolder")
    static let saveFile = Notification.Name("BrainDown.saveFile")
}
