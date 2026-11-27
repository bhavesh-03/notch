import SwiftUI

struct WeatherSettings: View {
    let settings: NotchSettings
    @State private var search = ""
    @State private var results: [WeatherLocation] = []
    @State private var status: String?

    var body: some View {
        Section {
            if let city = settings.weatherLocation {
                LabeledContent("Selected city") {
                    HStack {
                        Text(city.displayName)
                            .lineLimit(1)
                        Button("Remove") { settings.weatherLocation = nil }
                    }
                }
            }
            TextField("Search for a city", text: $search)
            ForEach(results) { city in
                Button {
                    settings.weatherLocation = city
                    search = ""
                    results = []
                } label: {
                    Label(city.displayName, systemImage: "location")
                }
                .buttonStyle(.plain)
            }
            if let status {
                Text(status).font(.caption).foregroundStyle(.secondary)
            }
        } header: {
            Text("Weather")
        } footer: {
            Link("Weather data by Open-Meteo", destination: URL(string: "https://open-meteo.com/")!)
        }
        .task(id: search) { await searchCities() }
    }

    private func searchCities() async {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        results = []
        status = nil
        guard query.count >= 2 else { return }
        do {
            try await Task.sleep(for: .milliseconds(350))
            status = "Searching…"
            let matches = try await WeatherService.search(query)
            guard !Task.isCancelled else { return }
            results = matches
            status = matches.isEmpty ? "No matching cities" : nil
        } catch {
            if !Task.isCancelled { status = "City search unavailable" }
        }
    }
}
