import Foundation

/// Value object for the central config.json, which is bundled into the app.
struct AppConfig: Decodable {
    struct Peak: Decodable {
        let timeZone: String
        let weekdays: [Int]   // Calendar weekdays: 1 = Sunday … 7 = Saturday
        let start: String     // "HH:mm" in timeZone
        let end: String
    }
    struct Usage: Decodable {
        let url: URL
        let betaHeader: String
        let keychainService: String
        let cliPaths: [String]
        let pollSeconds: Double
    }
    struct Status: Decodable {
        let url: URL
        let pageUrl: URL
        let pollSeconds: Double
    }
    let appName: String
    let peak: Peak
    let status: Status
    let usage: Usage
    let version: String
}

protocol ConfigLoading {
    func load() throws -> AppConfig
}

struct BundleConfigLoader: ConfigLoading {
    let bundle: Bundle
    init(bundle: Bundle = .main) { self.bundle = bundle }

    func load() throws -> AppConfig {
        guard let url = bundle.url(forResource: "config", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(AppConfig.self, from: Data(contentsOf: url))
    }
}
