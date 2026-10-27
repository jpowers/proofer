import AppKit
import Carbon.HIToolbox
import SwiftUI

@main
struct ProoferApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @StateObject private var model = ProofreadModel.shared

    var body: some Scene {
        Window("Proofer", id: "main") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 640, minHeight: 400)
        }
        .defaultSize(width: 900, height: 560)

        MenuBarExtra {
            MenuBarView()
                .environmentObject(model)
        } label: {
            MenuBarLabel()
                .environmentObject(model)
        }
        .menuBarExtraStyle(.window)

        // A plain window rather than SwiftUI's Settings scene, which can't be opened reliably from a MenuBarExtra.
        Window("Proofer Settings", id: "settings") {
            SettingsView()
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appSettings) {
                OpenSettingsButton(title: "Settings…")
                    .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotKey: HotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Needed when launched as a bare SwiftPM binary (swift run) so the window takes focus.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // ⌃⌥⌘P: proofread the clipboard from anywhere.
        hotKey = HotKey(keyCode: kVK_ANSI_P, modifiers: controlKey | optionKey | cmdKey) {
            MainActor.assumeIsolated { ProofreadModel.shared.proofreadClipboard() }
        }
    }

    // Keep running in the menu bar after the window closes.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
