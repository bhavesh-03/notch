import SwiftUI

/// System stats live only in Home widgets: nothing in the ears, no tab, no pop-ups. Being a module
/// gives the feature its place in Settings → Features like every other one.
extension SystemStatsMonitor: NotchModule {
    var feature: NotchFeature { .systemStats }
    var earPriority: Int? { nil }

    func content(for placement: NotchPlacement) -> some View {
        EmptyView()
    }
}
