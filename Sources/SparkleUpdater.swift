import AppKit
import Sparkle

/// Updates through Sparkle. Feed URL, public key and check interval come from Info.plist,
/// which scripts/build.sh fills from config.json. Every update must carry a valid EdDSA signature.
///
/// Background checks use Sparkle's "gentle reminders": instead of a window popping up,
/// the app posts a notification and shows an update row on the card.
@MainActor
final class SparkleUpdater: NSObject, UpdateManaging, SPUStandardUserDriverDelegate {
    var onUpdateFound: ((String) -> Void)?
    var onUpdateHandled: (() -> Void)?
    private var controller: SPUStandardUpdaterController!

    override init() {
        super.init()
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil,
                                                  userDriverDelegate: self)
    }

    var automaticallyChecks: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    func checkNow() {
        // A menu bar app is never frontmost by itself; bring Sparkle's window to the front.
        NSApp.activate(ignoringOtherApps: true)
        controller.checkForUpdates(nil)
    }

    // MARK: SPUStandardUserDriverDelegate

    nonisolated var supportsGentleScheduledUpdateReminders: Bool { true }

    nonisolated func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool) -> Bool {
        immediateFocus
    }

    nonisolated func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        guard !handleShowingUpdate else { return }
        let version = update.displayVersionString
        Task { @MainActor in self.onUpdateFound?(version) }
    }

    nonisolated func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        Task { @MainActor in self.onUpdateHandled?() }
    }

    nonisolated func standardUserDriverWillFinishUpdateSession() {
        Task { @MainActor in self.onUpdateHandled?() }
    }
}
