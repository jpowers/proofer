import AppKit
import SwiftUI

enum Tone: String, CaseIterable, Identifiable {
    case original, casual, friendly, professional, concise

    var id: String { rawValue }

    var label: String {
        switch self {
        case .original: return "Keep my tone"
        case .casual: return "Casual"
        case .friendly: return "Friendly"
        case .professional: return "Professional"
        case .concise: return "Concise"
        }
    }

    var instruction: String {
        switch self {
        case .original: return "Keep the author's voice, tone, and meaning; don't make it longer or more formal than needed."
        case .casual: return "Make the tone relaxed and conversational, like a message to a colleague you know well."
        case .friendly: return "Make the tone warm and approachable while staying clear."
        case .professional: return "Make the tone polished and professional, suitable for a client or manager."
        case .concise: return "Tighten it: cut filler and redundancy while keeping every important point."
        }
    }
}

/// Shared proofreading state used by the main window, the menu bar, and the global hotkey.
@MainActor
final class ProofreadModel: ObservableObject {
    static let shared = ProofreadModel()

    @Published var input = ""
    @Published var output = ""
    @Published var error: String?
    @Published var isRunning = false
    /// Bumped when something outside a view (the hotkey) wants the main window shown.
    @Published var showWindowRequest = 0

    private var task: Task<Void, Never>?

    var canProofread: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func proofread() {
        task?.cancel()
        output = ""; error = nil
        let provider = Provider.current
        guard let key = provider.apiKey else {
            error = AIError.missingKey(provider).localizedDescription
            return
        }
        let client = AIClient(
            provider: provider,
            apiKey: key,
            model: provider.model,
            tone: Tone(rawValue: UserDefaults.standard.string(forKey: "tone") ?? "") ?? .original
        )
        let text = input
        isRunning = true
        task = Task {
            do {
                for try await chunk in client.proofread(text) {
                    output += chunk
                }
            } catch is CancellationError {
            } catch let urlError as URLError where urlError.code == .cancelled {
            } catch {
                self.error = error.localizedDescription
            }
            isRunning = false
        }
    }

    func cancel() { task?.cancel() }

    func clear() {
        task?.cancel()
        input = ""; output = ""; error = nil
    }

    /// Hotkey entry point: proofread whatever is on the clipboard and bring the window forward.
    func proofreadClipboard() {
        guard let text = NSPasteboard.general.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            NSSound.beep()
            return
        }
        input = text
        showWindowRequest += 1
        proofread()
    }

    var rendered: AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: output, options: options)) ?? AttributedString(output)
    }

    /// Copies just the "Corrected version" section, falling back to the whole output.
    func copyCorrected() {
        var corrected = output
        if let start = output.range(of: "**Corrected version**") {
            let rest = output[start.upperBound...]
            let end = rest.range(of: "**Suggestions**")?.lowerBound ?? rest.endIndex
            corrected = String(rest[..<end])
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(corrected.trimmingCharacters(in: .whitespacesAndNewlines), forType: .string)
    }
}
