import SwiftUI

extension WeatherMonitor: NotchModule {
    var feature: NotchFeature { .weather }
    var earPriority: Int? { nil }

    func content(for placement: NotchPlacement) -> some View { EmptyView() }
}

struct WeatherWidget: View {
    let monitor: WeatherMonitor
    let location: WeatherLocation?
    let size: WidgetSize

    var body: some View {
        Group {
            if let location, location == monitor.location, let conditions = monitor.conditions {
                WeatherCard(location: location, conditions: conditions, size: size)
                    .help(monitor.failed ? "Showing the last forecast · Open-Meteo" : "Weather data by Open-Meteo")
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    Label("Weather", systemImage: "cloud.sun")
                        .font(.caption.weight(.semibold))
                    Text(location == nil ? "Set city"
                         : monitor.failed && monitor.location == location ? "Weather unavailable"
                         : "Loading…")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(2)
                }
                .help(location == nil ? "Choose a city in Settings → Home" : "Weather data by Open-Meteo")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .task(id: location) { await monitor.watch(location) }
    }
}

struct WeatherCard: View {
    let location: WeatherLocation
    let conditions: WeatherConditions
    let size: WidgetSize

    var body: some View {
        let condition = conditions.current.condition
        VStack(alignment: .leading, spacing: 3) {
            Text(location.name)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1)
            HStack(spacing: 4) {
                Image(systemName: condition.symbol)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.cyan)
                Text(temperature(conditions.current.temperature))
                    .font(.system(size: size.rows == 2 ? 24 : 17, weight: .semibold, design: .rounded).monospacedDigit())
                if size.columns == 2 {
                    Text(condition.label)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            if size.rows == 2, let high = conditions.daily.highs.first ?? nil, let low = conditions.daily.lows.first ?? nil {
                Text("H \(temperature(high))  L \(temperature(low))")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(condition.label)
    }

    private func temperature(_ celsius: Double) -> String {
        let unit: UnitTemperature = Locale.current.measurementSystem == .us ? .fahrenheit : .celsius
        let temperature = Measurement(value: celsius, unit: UnitTemperature.celsius).converted(to: unit).value
        return "\(temperature.formatted(.number.precision(.fractionLength(0))))°"
    }
}
