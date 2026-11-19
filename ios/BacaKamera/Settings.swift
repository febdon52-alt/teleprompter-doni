import Foundation
import Security
import Combine

/// Menyimpan API key di Keychain (bukan UserDefaults).
enum Keychain {
    private static func base(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "com.bacakamera.app",
         kSecAttrAccount as String: account]
    }

    static func set(_ value: String, for account: String) {
        SecItemDelete(base(account) as CFDictionary)
        guard !value.isEmpty, let data = value.data(using: .utf8) else { return }
        var add = base(account)
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }

    static func get(_ account: String) -> String {
        var query = base(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data,
              let s = String(data: data, encoding: .utf8) else { return "" }
        return s
    }
}

final class AppSettings: ObservableObject {
    @Published var speed: Double { didSet { UserDefaults.standard.set(speed, forKey: "speed") } }
    @Published var fontSize: Double { didSet { UserDefaults.standard.set(fontSize, forKey: "fontSize") } }
    @Published var countdown: Int { didSet { UserDefaults.standard.set(countdown, forKey: "countdown") } }
    @Published var mirrorText: Bool { didSet { UserDefaults.standard.set(mirrorText, forKey: "mirrorText") } }
    @Published var centerText: Bool { didSet { UserDefaults.standard.set(centerText, forKey: "centerText") } }
    @Published var ratio: VideoRatio { didSet { UserDefaults.standard.set(ratio.rawValue, forKey: "ratio") } }
    @Published var mirrorRecording: Bool { didSet { UserDefaults.standard.set(mirrorRecording, forKey: "mirrorRecording") } }
    @Published var model: String { didSet { UserDefaults.standard.set(model, forKey: "model") } }
    @Published var useAI: Bool { didSet { UserDefaults.standard.set(useAI, forKey: "useAI") } }
    @Published var apiKey: String { didSet { Keychain.set(apiKey, for: "apiKey") } }

    static let models: [(String, String)] = [
        ("claude-opus-5-5", "Claude Opus 5.5 (paling bagus)"),
        ("claude-sonnet-5-5", "Claude Sonnet 5.5 (cepat)"),
        ("claude-haiku-5-5", "Claude Haiku 5.5 (hemat)")
    ]

    init() {
        let d = UserDefaults.standard
        speed = d.object(forKey: "speed") as? Double ?? 5
        fontSize = d.object(forKey: "fontSize") as? Double ?? 40
        countdown = d.object(forKey: "countdown") as? Int ?? 3
        mirrorText = d.object(forKey: "mirrorText") as? Bool ?? false
        centerText = d.object(forKey: "centerText") as? Bool ?? false
        ratio = VideoRatio(rawValue: d.string(forKey: "ratio") ?? "") ?? .r916
        mirrorRecording = d.object(forKey: "mirrorRecording") as? Bool ?? false
        model = d.string(forKey: "model") ?? "claude-opus-5-5"
        useAI = d.object(forKey: "useAI") as? Bool ?? true
        apiKey = Keychain.get("apiKey")
    }

    var aiReady: Bool { useAI && !apiKey.trimmingCharacters(in: .whitespaces).isEmpty }
}
