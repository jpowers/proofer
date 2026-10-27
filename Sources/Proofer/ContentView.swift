import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: ProofreadModel
    @AppStorage("tone") private var tone = Tone.original.rawValue

    var body: some View {
        HSplitView {
            InputEditor(text: $model.input)
                .frame(minWidth: 280)

            ResultView()
                .frame(minWidth: 280)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
        }
        .toolbar {
            ToolbarItemGroup {
                if model.isRunning { ProgressView().controlSize(.small) }
                TonePicker(tone: $tone)
                Button("Clear", systemImage: "trash") { model.clear() }
                Button("Copy Corrected", systemImage: "doc.on.doc") { model.copyCorrected() }
                    .disabled(model.output.isEmpty)
                ProofreadButton()
                OpenSettingsButton()
            }
        }
    }
}

struct InputEditor: View {
    @Binding var text: String

    var body: some View {
        TextEditor(text: $text)
            .font(.system(size: 14))
            .scrollContentBackground(.hidden)
            .padding(10)
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text("Paste your message here, then press ⌘↩")
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 10)
                        .allowsHitTesting(false)
                }
            }
    }
}

struct ResultView: View {
    @EnvironmentObject private var model: ProofreadModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if let error = model.error {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
                Text(model.rendered)
                    .font(.system(size: 14))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
        }
    }
}

struct TonePicker: View {
    @Binding var tone: String

    var body: some View {
        Picker("Tone", selection: $tone) {
            ForEach(Tone.allCases) { Text($0.label).tag($0.rawValue) }
        }
        .fixedSize()
    }
}

struct ProofreadButton: View {
    @EnvironmentObject private var model: ProofreadModel

    var body: some View {
        Button(model.isRunning ? "Stop" : "Proofread",
               systemImage: model.isRunning ? "stop.fill" : "checkmark.seal") {
            model.isRunning ? model.cancel() : model.proofread()
        }
        .keyboardShortcut(.return, modifiers: .command)
        .disabled(!model.isRunning && !model.canProofread)
    }
}
