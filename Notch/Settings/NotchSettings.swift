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

    /// Expanded width. Changing it resizes the panel, so it's reported through `onGeometryChanged`.
    var width: NotchWidth {
        didSet { save(width.rawValue, Keys.width); onGeometryChanged?() }
    }
    /// Corner radius of the expanded notch, in points.
    var cornerRadius: Double {
        didSet {
            let clamped = cornerRadius.clamped(to: Self.cornerRadiusRange)
            if cornerRadius != clamped { cornerRadius = clamped; return }
            save(cornerRadius, Keys.cornerRadius)
        }
    }
    var accent: NotchAccent {
        didSet { save(accent.rawValue, Keys.accent) }
    }
    var showsEars: Bool {
        didSet { save(showsEars, Keys.showsEars); onGeometryChanged?() }
    }

    static let defaultCornerRadius: Double = 24
    static let cornerRadiusRange: ClosedRange<Double> = 12...32

    /// Called when a setting changes the notch's geometry (its width, or its ears).
    @ObservationIgnored var onGeometryChanged: (() -> Void)?

    /// Called after any change to which features are shown or their order.
    @ObservationIgnored var onFeaturesChanged: (() -> Void)?

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        featureOrder = Self.normalized(order: Self.features(forKey: Keys.featureOrder, in: defaults))
        hiddenFeatures = Set(Self.features(forKey: Keys.hiddenFeatures, in: defaults))
        // `didSet` doesn't run for assignments in init, so loading doesn't write anything back.
        width = defaults.string(forKey: Keys.width).flatMap(NotchWidth.init(rawValue:)) ?? .standard
        cornerRadius = (defaults.object(forKey: Keys.cornerRadius) as? Double)?.clamped(to: Self.cornerRadiusRange) ?? Self.defaultCornerRadius
        accent = defaults.string(forKey: Keys.accent).flatMap(NotchAccent.init(rawValue:)) ?? .orange
        showsEars = defaults.object(forKey: Keys.showsEars) as? Bool ?? true
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

    // MARK: - Look

    func resetLook() {
        width = .standard
        cornerRadius = Self.defaultCornerRadius
        accent = .orange
        showsEars = true
    }

    // MARK: - Storage

    private enum Keys {
        static let featureOrder = "settings.featureOrder"
        static let hiddenFeatures = "settings.hiddenFeatures"
        static let width = "settings.width"
        static let cornerRadius = "settings.cornerRadius"
        static let accent = "settings.accent"
        static let showsEars = "settings.showsEars"
    }

    private func save(_ value: Any, _ key: String) {
        defaults.set(value, forKey: key)
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

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
