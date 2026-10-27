import Foundation

/// Stores API keys in ~/Library/Application Support/Proofer/keys.json, readable only by the current user.
///
/// We avoid the macOS Keychain because Proofer is built from source and ad-hoc signed: every rebuild
/// has a new signature, so the Keychain would ask the user for their password after each build.
enum KeyStore {
    static let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Proofer", isDirectory: true)
    static let file = directory.appendingPathComponent("keys.json")

    static func load(_ name: String) -> String? {
        readAll()[name]
    }

    static func save(_ value: String, for name: String) {
        var keys = readAll()
        keys[name] = value.isEmpty ? nil : value
        do {
            let fm = FileManager.default
            try fm.createDirectory(at: directory, withIntermediateDirectories: true,
                                   attributes: [.posixPermissions: 0o700])
            try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
            let data = try JSONSerialization.data(withJSONObject: keys, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: file, options: .atomic)
            try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        } catch {
            NSLog("Proofer: could not save API key: \(error)")
        }
    }

    private static func readAll() -> [String: String] {
        guard let data = try? Data(contentsOf: file),
              let keys = try? JSONSerialization.jsonObject(with: data) as? [String: String] else { return [:] }
        return keys
    }
}
