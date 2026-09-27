import SwiftUI

/// The settings window's content. Each part of the customization gets its own tab.
struct SettingsView: View {
    let settings: NotchSettings

    var body: some View {
        TabView {
            FeaturesSettings(settings: settings)
                .tabItem { Label("Features", systemImage: "square.grid.2x2") }
        }
        .frame(width: 460)
        .padding(20)
    }
}

/// Which features appear, and in what order.
struct FeaturesSettings: View {
    let settings: NotchSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            List {
                ForEach(settings.featureOrder) { feature in
                    FeatureRow(feature: feature, isOn: Binding(
                        get: { settings.isVisible(feature) },
                        set: { settings.setVisible(feature, $0) }
                    ))
                }
                .onMove { settings.moveFeatures(fromOffsets: $0, toOffset: $1) }
            }
            .listStyle(.bordered(alternatesRowBackgrounds: true))
            .frame(height: 6 * 50)

            HStack(alignment: .firstTextBaseline) {
                Text("Drag to reorder. The order sets Home's columns and the tabs above them.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Reset") { settings.resetFeatures() }
            }
        }
    }
}

private struct FeatureRow: View {
    let feature: NotchFeature
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: feature.symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(.tint, in: .rect(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                Text(feature.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle(feature.title, isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .padding(.vertical, 4)
        .opacity(isOn ? 1 : 0.55)
    }
}

#Preview {
    SettingsView(settings: .ephemeral())
}
