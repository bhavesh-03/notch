import Foundation

/// Decides whether a plug-in edge deserves the charging activity.
/// A loose cable can drop and reconnect within a second; those reconnects are ignored.
struct PlugInFilter {
    var minimumUnpluggedTime: TimeInterval = 2
    private var unpluggedAt: Date?

    mutating func shouldAnnounce(_ current: BatteryStatus, after previous: BatteryStatus?, at now: Date) -> Bool {
        if let previous, previous.isPluggedIn, !current.isPluggedIn {
            unpluggedAt = now
            return false
        }

        guard current.isPlugIn(after: previous) else { return false }
        defer { unpluggedAt = nil }

        guard let unpluggedAt else { return true }
        return now.timeIntervalSince(unpluggedAt) >= minimumUnpluggedTime
    }
}
