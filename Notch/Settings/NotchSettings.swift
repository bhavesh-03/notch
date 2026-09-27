import Foundation
import SwiftUI   // for Array.move(fromOffsets:toOffset:), the same move a List reorder performs

/// The user's choices, saved in UserDefaults.
///
/// One observable object instead of scattered `@AppStorage` properties: the view model and the
/// app delegate need these values too, not just views, and injecting the UserDefaults makes every
/// setting testable without touching the real app's preferences.
@Observable
final class NotchSettings {
    /// Every feature, in the order the user arranged them.
    private(set) var featureOrder: [NotchFeature]
    private(set) var hiddenFeatures: Set<NotchFeature>

    /// Called after any change to which features are shown or their order.
    @ObservationIgnored var onFeaturesChanged: (() -> Void)?

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        featureOrder = Self.normalized(order: Self.features(forKey: Keys.featureOrder, in: defaults))
        hiddenFeatures = Set(Self.features(forKey: Keys.hiddenFeatures, in: defaults))
    }

    /// Settings kept in a throwaway domain, for tests and previews, so they never read or change the
    /// user's real preferences.
    static func ephemeral() -> NotchSettings {
        let name = "NotchSettings.ephemeral.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return NotchSettings(defaults: defaults)
    }

    // MARK: - Features

    /// The features to show, in order.
    var visibleFeatures: [NotchFeature] {
        featureOrder.filter { !hiddenFeatures.contains($0) }
    }

    func isVisible(_ feature: NotchFeature) -> Bool {
        !hiddenFeatures.contains(feature)
    }

    func setVisible(_ feature: NotchFeature, _ isVisible: Bool) {
        if isVisible {
            hiddenFeatures.remove(feature)
        } else {
            hiddenFeatures.insert(feature)
        }
        saveFeatures()
    }

    /// Same signature as `List`'s `onMove`, so the settings list can pass it straight through.
    func moveFeatures(fromOffsets source: IndexSet, toOffset destination: Int) {
        featureOrder.move(fromOffsets: source, toOffset: destination)
        saveFeatures()
    }

    func resetFeatures() {
        featureOrder = NotchFeature.allCases
        hiddenFeatures = []
        saveFeatures()
    }

    /// A saved order made trustworthy: duplicates dropped, and features the saved order doesn't know
    /// (added in a later version) appended at the end, so an update never loses a feature.
    static func normalized(order: [NotchFeature]) -> [NotchFeature] {
        var seen = Set<NotchFeature>()
        let known = order.filter { seen.insert($0).inserted }
        return known + NotchFeature.allCases.filter { !seen.contains($0) }
    }

    // MARK: - Storage

    private enum Keys {
        static let featureOrder = "settings.featureOrder"
        static let hiddenFeatures = "settings.hiddenFeatures"
    }

    private func saveFeatures() {
        defaults.set(featureOrder.map(\.rawValue), forKey: Keys.featureOrder)
        defaults.set(hiddenFeatures.map(\.rawValue).sorted(), forKey: Keys.hiddenFeatures)
        onFeaturesChanged?()
    }

    /// Unknown names (say, from a newer version's preferences) are skipped rather than failing.
    private static func features(forKey key: String, in defaults: UserDefaults) -> [NotchFeature] {
        (defaults.stringArray(forKey: key) ?? []).compactMap(NotchFeature.init(rawValue:))
    }
}
