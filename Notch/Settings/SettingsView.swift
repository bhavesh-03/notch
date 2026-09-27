import SwiftUI

/// The settings window's content. Each part of the customization gets its own tab.
struct SettingsView: View {
    let settings: NotchSettings

    var body: some View {
        TabView {
            FeaturesSettings(settings: settings)
                .tabItem { Label("Features", systemImage: "square.grid.2x2") }
            LookSettings(settings: settings)
                .tabItem { Label("Look", systemImage: "paintbrush") }
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

/// Size, corners, accent color and ears, with a live preview of the expanded notch.
struct LookSettings: View {
    @Bindable var settings: NotchSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            NotchLookPreview(settings: settings)

            Form {
                Picker("Width", selection: $settings.width) {
                    ForEach(NotchWidth.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)

                LabeledContent("Corners") {
                    HStack {
                        Slider(value: $settings.cornerRadius, in: NotchSettings.cornerRadiusRange, step: 1)
                        Text("\(Int(settings.cornerRadius)) pt")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 42, alignment: .trailing)
                    }
                }

                LabeledContent("Accent") {
                    HStack(spacing: 8) {
                        ForEach(NotchAccent.allCases) { accent in
                            AccentSwatch(accent: accent, isSelected: settings.accent == accent) {
                                settings.accent = accent
                            }
                        }
                    }
                }

                Toggle("Show ears when collapsed", isOn: $settings.showsEars)
                Text("The ears are the small areas beside the camera that show the battery, a running timer or what's playing. Pop-ups still appear when they're off.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Button("Reset") { settings.resetLook() }
            }
        }
    }
}

/// A scaled-down expanded notch that follows the settings as they change.
private struct NotchLookPreview: View {
    let settings: NotchSettings
    private let scale: CGFloat = 0.62

    var body: some View {
        let size = CGSize(width: settings.width.points * scale, height: NotchGeometry.expandedHeight * scale)
        let radius = settings.cornerRadius * scale
        ZStack(alignment: .top) {
            UnevenRoundedRectangle(bottomLeadingRadius: radius, bottomTrailingRadius: radius)
                .fill(.black)
                .frame(width: size.width, height: size.height)
                .overlay(alignment: .bottom) {
                    // A stand-in for accented content, like playback progress.
                    Capsule()
                        .fill(.white.opacity(0.25))
                        .overlay(alignment: .leading) {
                            Capsule().fill(settings.accent.color).frame(width: size.width * 0.35)
                        }
                        .frame(width: size.width * 0.6, height: 3)
                        .padding(.bottom, 22)
                }
            // The camera housing, for scale.
            UnevenRoundedRectangle(bottomLeadingRadius: 6, bottomTrailingRadius: 6)
                .fill(Color(white: 0.12))
                .frame(width: 180 * scale, height: 32 * scale)
        }
        .frame(maxWidth: .infinity)
        .frame(height: NotchGeometry.expandedHeight * scale)
        .padding(.vertical, 12)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 10))
        .animation(.spring(duration: 0.5, bounce: 0.3), value: settings.width)
        .animation(.spring(duration: 0.5, bounce: 0.3), value: settings.cornerRadius)
    }
}

private struct AccentSwatch: View {
    let accent: NotchAccent
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            Circle()
                .fill(accent.color)
                .frame(width: 20, height: 20)
                .overlay {
                    if isSelected {
                        Circle().fill(.white).frame(width: 7, height: 7)
                    }
                }
                .overlay(Circle().strokeBorder(.black.opacity(0.15)))
        }
        .buttonStyle(.plain)
        .help(accent.title)
        .accessibilityLabel(accent.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
