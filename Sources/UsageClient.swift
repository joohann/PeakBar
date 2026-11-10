import Foundation

/// One usage window, e.g. the 5-hour session or the 7-day limit.
struct UsageWindow: Equatable {
    let percent: Double      // 0…100
    let resetsAt: Date?
}

/// Value object with the subscription usage, as shown by /usage in Claude Code.
struct Usage: Equatable {
    let session: UsageWindow?
    let week: UsageWindow?
    let plan: String?
    let fetchedAt: Date
}

enum UsageError: Error, Equatable {
    case notSignedIn
    case keychainDenied
    case expired
    case rateLimited
    case unavailable
}

protocol UsageProviding {
    func fetch() async throws -> Usage
}

/// Calls Anthropic's internal (undocumented) OAuth usage endpoint. May change without notice.
struct OAuthUsageClient: UsageProviding {
    private struct Response: Decodable {
        struct Window: Decodable {
            let utilization: Double?
            let resets_at: String?
        }
        let five_hour: Window?
        let seven_day: Window?
    }

    let url: URL
    let betaHeader: String
    let userAgent: String
    let tokens: AccessTokenProviding
    let refresher: TokenRefreshing
    let session: URLSession

    init(url: URL, betaHeader: String, userAgent: String, tokens: AccessTokenProviding,
         refresher: TokenRefreshing, session: URLSession = .shared) {
        self.refresher = refresher
        self.url = url
        self.betaHeader = betaHeader
        self.userAgent = userAgent
        self.tokens = tokens
        self.session = session
    }

    func fetch() async throws -> Usage {
        guard url.scheme == "https" else { throw UsageError.unavailable }
        do {
            return try await fetchOnce()
        } catch UsageError.expired {
            // Let Claude Code renew its token, then try exactly once more.
            guard await refresher.refresh() else { throw UsageError.expired }
            return try await fetchOnce()
        }
    }

    private func fetchOnce() async throws -> Usage {
        let token = try await readToken()
        guard !token.isExpired else { throw UsageError.expired }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("Bearer \(token.value)", forHTTPHeaderField: "Authorization")
        request.setValue(betaHeader, forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        Log.usage.info("usage endpoint HTTP \(code, privacy: .public)")
        switch code {
        case 200: break
        case 401, 403: throw UsageError.expired
        case 429: throw UsageError.rateLimited
        default: throw UsageError.unavailable
        }
        guard let body = try? JSONDecoder().decode(Response.self, from: data) else { throw UsageError.unavailable }
        return Usage(session: Self.window(body.five_hour), week: Self.window(body.seven_day),
                     plan: token.plan, fetchedAt: Date())
    }

    /// Keychain access can show a system prompt, so keep it off the main thread.
    private func readToken() async throws -> AccessToken {
        let tokens = self.tokens
        return try await Task.detached(priority: .utility) {
            do { return try tokens.token() }
            catch CredentialError.notFound { throw UsageError.notSignedIn }
            catch CredentialError.accessDenied { throw UsageError.keychainDenied }
            catch { throw UsageError.unavailable }
        }.value
    }

    private static func window(_ w: Response.Window?) -> UsageWindow? {
        guard let w, let percent = w.utilization else { return nil }
        return UsageWindow(percent: min(max(percent, 0), 100), resetsAt: w.resets_at.flatMap(parseDate))
    }

    private static func parseDate(_ s: String) -> Date? {
        // Drop fractional seconds (the API sends microseconds, which ISO8601DateFormatter rejects).
        let trimmed = s.replacingOccurrences(of: #"\.\d+"#, with: "", options: .regularExpression)
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: trimmed)
    }
}
