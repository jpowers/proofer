import SwiftUI

/// Compact proofreader shown from the menu bar icon.
struct MenuBarView: View {
    @EnvironmentObject private var model: ProofreadModel
    @Environment(\.openWindow) private var openWindow
    @AppStorage("tone") private var tone = Tone.original.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TonePicker(tone: $tone)
                Spacer()
                if model.isRunning { ProgressView().controlSize(.small) }
                ProofreadButton()
            }

            InputEditor(text: $model.input)
                .frame(height: 110)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))

            ResultView()
                .frame(height: 220)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.5), in: RoundedRectangle(cornerRadius: 6))

            HStack {
                Button("Paste & Proofread") { model.proofreadClipboard() }
                Button("Copy Corrected") { model.copyCorrected() }
                    .disabled(model.output.isEmpty)
                Spacer()
                Button("Open Window") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
                OpenSettingsButton()
                Button { NSApp.terminate(nil) } label: { Image(systemName: "power") }
                    .help("Quit Proofer")
            }
            .controlSize(.small)
        }
        .padding(12)
        .frame(width: 420)
    }
}

/// The menu bar icon. It's always alive, so it also listens for hotkey requests to show the main window.
struct MenuBarLabel: View {
    @EnvironmentObject private var model: ProofreadModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(systemName: "checkmark.seal")
            .onChange(of: model.showWindowRequest) {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
    }
}

struct OpenSettingsButton: View {
    @Environment(\.openWindow) private var openWindow
    var title = "Settings"

    var body: some View {
        Button(title, systemImage: "gearshape") {
            openWindow(id: "settings")
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
