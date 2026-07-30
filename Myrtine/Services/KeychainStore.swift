import Foundation
import Security

enum KeychainStore {
    private static let service = "fr.myrtine.admin"
    private static let simulatorFallbackPrefix = "myrtine-simulator-keychain."

    static func set(_ value: String, for account: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            #if targetEnvironment(simulator)
            UserDefaults.standard.set(value, forKey: simulatorFallbackPrefix + account)
            return
            #else
            throw KeychainError.status(status)
            #endif
        }
        #if targetEnvironment(simulator)
        UserDefaults.standard.removeObject(forKey: simulatorFallbackPrefix + account)
        #endif
    }

    static func get(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
           let data = item as? Data {
            return String(data: data, encoding: .utf8)
        }
        #if targetEnvironment(simulator)
        return UserDefaults.standard.string(forKey: simulatorFallbackPrefix + account)
        #else
        return nil
        #endif
    }

    static func remove(_ account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        #if targetEnvironment(simulator)
        UserDefaults.standard.removeObject(forKey: simulatorFallbackPrefix + account)
        #endif
    }

    enum KeychainError: LocalizedError {
        case status(OSStatus)

        var errorDescription: String? {
            switch self {
            case let .status(status):
                let message = SecCopyErrorMessageString(status, nil) as String? ?? "Erreur inconnue"
                return "Le trousseau iOS a refusé l’enregistrement (\(status)) : \(message)."
            }
        }
    }
}
