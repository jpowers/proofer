import SwiftUI

struct SettingsView: View {
    @AppStorage("provider") private var providerRaw = Provider.anthropic.rawValue
    @State private var apiKey = ""
    @State private var savedKey = ""
    @State private var model = ""
    @State private var fetchedModels: [String] = []
    @State private var fetchError: String?
    @State private var isFetching = false

    private var provider: Provider { Provider(rawValue: providerRaw) ?? .anthropic }

    var body: some View {
        Form {
            Picker("Provider", selection: $providerRaw) {
                ForEach(Provider.allCases) { Text($0.displayName).tag($0.rawValue) }
            }

            HStack {
                SecureField("API key", text: $apiKey)
                    .onSubmit { saveKey(for: provider) }
                Button(apiKey == savedKey ? "Saved" : "Save") { saveKey(for: provider) }
                    .disabled(apiKey == savedKey)
            }
            Link("Get a \(provider.displayName) key", destination: provider.keyURL)
                .font(.caption)

            HStack {
                TextField("Model", text: $model, prompt: Text(provider.defaultModel))
                    .onChange(of: model) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: provider.modelDefaultsKey)
                    }
                Menu {
                    ForEach(fetchedModels.isEmpty ? provider.suggestedModels : fetchedModels, id: \.self) { id in
                        Button(id) { model = id }
                    }
                } label: {
                    Image(systemName: "chevron.up.chevron.down")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                Button(isFetching ? "Fetching…" : "Fetch models") { fetchModels() }
                    .disabled(isFetching || apiKey.isEmpty)
            }
            if let fetchError {
                Text(fetchError).font(.caption).foregroundStyle(.red)
            }

            LabeledContent("Global hotkey", value: "⌃⌥⌘P — proofread the clipboard")
            Text("Keys are saved in ~/Library/Application Support/Proofer/keys.json, readable only by your user account. Falls back to \(provider.envVar) if unset.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 520)
        .onAppear(perform: loadProviderSettings)
        .onDisappear { saveKey(for: provider) }
        .onChange(of: providerRaw) { oldValue, _ in
            saveKey(for: Provider(rawValue: oldValue) ?? .anthropic)
            loadProviderSettings()
        }
    }

    private func loadProviderSettings() {
        apiKey = KeyStore.load(provider.keyName) ?? ""
        savedKey = apiKey
        model = UserDefaults.standard.string(forKey: provider.modelDefaultsKey) ?? ""
        fetchedModels = []
        fetchError = nil
    }

    /// Writes the key only when it has changed, rather than on every keystroke.
    private func saveKey(for provider: Provider) {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key != savedKey else { return }
        KeyStore.save(key, for: provider.keyName)
        apiKey = key
        savedKey = key
    }

    private func fetchModels() {
        let provider = provider, key = apiKey
        isFetching = true
        fetchError = nil
        Task {
            do {
                fetchedModels = try await AIClient.listModels(provider: provider, apiKey: key)
                if fetchedModels.isEmpty { fetchError = "No models returned." }
            } catch {
                fetchError = error.localizedDescription
            }
            isFetching = false
        }
    }
}
