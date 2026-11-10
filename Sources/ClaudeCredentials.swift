import Foundation
import Security

/// The access token Claude Code stores. Kept in memory only, never logged or written to disk.
struct AccessToken {
    let value: String
    let expiresAt: Date?
    let plan: String?

    var isExpired: Bool { expiresAt.map { $0 <= Date() } ?? false }
}

enum CredentialError: Error, Equatable {
    case notFound
    case accessDenied
    case unreadable
}

protocol AccessTokenProviding {
    func token() throws -> AccessToken
}

/// Reads Claude Code's OAuth credentials from the login Keychain (read-only).
/// macOS asks the user once for permission; the token is never refreshed or modified here.
struct KeychainTokenProvider: AccessTokenProviding {
    private struct Stored: Decodable {
        struct OAuth: Decodable {
            let accessToken: String
            let expiresAt: Double?
            let subscriptionType: String?
        }
        let claudeAiOauth: OAuth
    }

    let service: String

    func token() throws -> AccessToken {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecReturnData: true,
        ]
        var result: CFTypeRef?
        switch SecItemCopyMatching(query as CFDictionary, &result) {
        case errSecSuccess: break
        case errSecItemNotFound: throw CredentialError.notFound
        case errSecAuthFailed, errSecUserCanceled, errSecInteractionNotAllowed: throw CredentialError.accessDenied
        default: throw CredentialError.unreadable
        }
        guard let data = result as? Data,
              let stored = try? JSONDecoder().decode(Stored.self, from: data) else {
            throw CredentialError.unreadable
        }
        let oauth = stored.claudeAiOauth
        return AccessToken(
            value: oauth.accessToken,
            expiresAt: oauth.expiresAt.map { Date(timeIntervalSince1970: $0 / 1000) },
            plan: oauth.subscriptionType
        )
    }
}
