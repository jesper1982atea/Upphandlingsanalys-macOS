import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first?.makeKeyAndOrderFront(nil)
    }
}

@main
struct ProcurementRAGApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = LibraryStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Nytt upphandlingsprojekt…") {
                    store.chooseAndCreateProject()
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Button("Läs in mapp…") {
                    store.chooseAndImportFolder()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Button("Importera dokument…") {
                    store.chooseAndImportDocuments()
                }
                .keyboardShortcut("o", modifiers: [.command])

                Divider()

                Button("Exportera svarsplan…") {
                    store.exportResponsePlan()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(store.requirements.isEmpty)
            }
        }
    }
}
