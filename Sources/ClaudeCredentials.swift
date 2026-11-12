import Foundation

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

/// Reads Claude Code's OAuth credentials from the login Keychain (read-only) through
/// `/usr/bin/security`, the tool Claude Code itself uses to store them. macOS already trusts it
/// for this item, so there is no password prompt, also not after Claude Code rewrites the item
/// or after this app is rebuilt. The token is never refreshed, modified, logged or stored here.
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
    var tool = "/usr/bin/security"
    var timeout: TimeInterval = 10

    func token() throws -> AccessToken {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = ["find-generic-password", "-s", service, "-w"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { throw CredentialError.unreadable }

        // Never hang on an unexpected prompt.
        let watchdog = DispatchWorkItem { if process.isRunning { process.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: watchdog)
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        watchdog.cancel()

        switch process.terminationStatus {
        case 0: break
        case 44: throw CredentialError.notFound            // errSecItemNotFound
        case 51, 128, 15: throw CredentialError.accessDenied // denied, cancelled or timed out
        default: throw CredentialError.unreadable
        }
        guard let stored = try? JSONDecoder().decode(Stored.self, from: data) else {
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
