import Foundation

/// Checks for and installs new versions of the app. The UI only talks to this protocol.
@MainActor
protocol UpdateManaging: AnyObject {
    /// Background checks on the interval from config.json.
    var automaticallyChecks: Bool { get set }
    /// Called when a background check finds a version the user has not looked at yet.
    var onUpdateFound: ((String) -> Void)? { get set }
    /// Called when the user has seen the update (dialog opened, installed or dismissed).
    var onUpdateHandled: (() -> Void)? { get set }
    /// Checks now and shows the update dialog (also for "you are up to date").
    func checkNow()
}

/// Used where updates do not apply, such as the README previews.
@MainActor
final class NoUpdates: UpdateManaging {
    var automaticallyChecks = false
    var onUpdateFound: ((String) -> Void)?
    var onUpdateHandled: (() -> Void)?
    func checkNow() {}
}
