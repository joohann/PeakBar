import Foundation

protocol TokenRefreshing {
    /// Asks the owner of the credentials to renew them. Returns false when that was not possible.
    func refresh() async -> Bool
}

/// Lets Claude Code renew its own token by running `claude auth status`.
/// This app never uses or rotates the refresh token itself, so Claude Code stays the only writer.
struct ClaudeCLIRefresher: TokenRefreshing {
    let candidatePaths: [String]
    let timeout: TimeInterval

    init(candidatePaths: [String], timeout: TimeInterval = 20) {
        self.candidatePaths = candidatePaths
        self.timeout = timeout
    }

    func refresh() async -> Bool {
        guard let path = executable else {
            Log.usage.info("claude CLI not found")
            return false
        }
        let timeout = self.timeout
        return await Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = ["auth", "status"]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            do { try process.run() } catch { return false }
            let deadline = Date().addingTimeInterval(timeout)
            while process.isRunning && Date() < deadline { usleep(100_000) }
            if process.isRunning { process.terminate(); return false }
            Log.usage.info("claude auth status exit \(process.terminationStatus, privacy: .public)")
            return process.terminationStatus == 0
        }.value
    }

    private var executable: String? {
        candidatePaths
            .map { NSString(string: $0).expandingTildeInPath }
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}
