// KeychainHelper.swift — Shared (macOS + iOS)

import Foundation
import Security

enum KeychainHelper {

    private static let service = "com.pg13.promptgenerator"

    // MARK: - Save (insert or update)

    @discardableResult
    static func save(_ value: String, key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]

        // Attempt update first
        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            [kSecValueData: data] as CFDictionary
        )

        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData] = data
            // Only readable while the device is unlocked; never migrates to
            // another device via backup restore.
            addQuery[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
        }

        return updateStatus == errSecSuccess
    }

    // MARK: - Load

    static func load(key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:        kSecClassGenericPassword,
            kSecAttrService:  service,
            kSecAttrAccount:  key,
            kSecReturnData:   true,
            kSecMatchLimit:   kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Delete

    @discardableResult
    static func delete(key: String) -> Bool {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Migration helper

    /// Call once at launch: moves a UserDefaults key into Keychain and removes it.
    static func migrateFromUserDefaults(udKey: String, keychainKey: String) {
        guard KeychainHelper.load(key: keychainKey) == nil else { return } // already migrated
        if let existing = UserDefaults.standard.string(forKey: udKey), !existing.isEmpty {
            KeychainHelper.save(existing, key: keychainKey)
            UserDefaults.standard.removeObject(forKey: udKey)
        }
    }
}
