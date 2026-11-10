import Foundation

/// Value object for the live service status.
struct ServiceStatus: Equatable {
    enum Level: Equatable { case operational, degraded }
    let level: Level
    let description: String
    let incidents: [String]
    let fetchedAt: Date
}

protocol ServiceStatusProviding {
    func fetch() async throws -> ServiceStatus
}

/// Reads an Atlassian Statuspage summary.json (status.claude.com).
struct StatuspageClient: ServiceStatusProviding {
    private struct Summary: Decodable {
        struct Status: Decodable { let indicator: String; let description: String }
        struct Incident: Decodable { let name: String; let status: String }
        let status: Status
        let incidents: [Incident]
    }

    let url: URL
    let session: URLSession

    init(url: URL, session: URLSession = .shared) {
        self.url = url
        self.session = session
    }

    func fetch() async throws -> ServiceStatus {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        let summary = try JSONDecoder().decode(Summary.self, from: data)
        let open = summary.incidents.filter { $0.status != "resolved" && $0.status != "postmortem" }
        let ok = summary.status.indicator == "none" && open.isEmpty
        return ServiceStatus(
            level: ok ? .operational : .degraded,
            description: summary.status.description,
            incidents: open.map(\.name),
            fetchedAt: Date()
        )
    }
}
