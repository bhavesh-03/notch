import Foundation

struct WeatherLocation: Codable, Equatable, Identifiable {
    let id: Int
    let name: String
    let admin1: String?
    let country: String?
    let latitude: Double
    let longitude: Double

    var displayName: String {
        [name, admin1, country].compactMap { $0 }.joined(separator: ", ")
    }
}

struct WeatherConditions: Decodable {
    struct Current: Decodable {
        let temperature: Double
        let code: Int
        let isDay: Int

        enum CodingKeys: String, CodingKey {
            case temperature = "temperature_2m"
            case code = "weather_code"
            case isDay = "is_day"
        }

        var condition: (label: String, symbol: String) {
            switch code {
            case 0: isDay == 1 ? ("Clear", "sun.max.fill") : ("Clear", "moon.stars.fill")
            case 1, 2: isDay == 1 ? ("Partly cloudy", "cloud.sun.fill") : ("Partly cloudy", "cloud.moon.fill")
            case 3: ("Cloudy", "cloud.fill")
            case 45, 48: ("Fog", "cloud.fog.fill")
            case 51...57: ("Drizzle", "cloud.drizzle.fill")
            case 61...67, 80...82: ("Rain", "cloud.rain.fill")
            case 71...77, 85, 86: ("Snow", "cloud.snow.fill")
            case 95, 96, 99: ("Thunderstorms", "cloud.bolt.rain.fill")
            default: ("Weather", "cloud.sun")
            }
        }
    }

    struct Daily: Decodable {
        let highs: [Double?]
        let lows: [Double?]

        enum CodingKeys: String, CodingKey {
            case highs = "temperature_2m_max"
            case lows = "temperature_2m_min"
        }
    }

    let current: Current
    let daily: Daily
}

enum WeatherService {
    private struct SearchResponse: Decodable {
        let results: [WeatherLocation]?
    }

    static func search(_ name: String) async throws -> [WeatherLocation] {
        let response: SearchResponse = try await request(
            "geocoding-api.open-meteo.com", path: "/v1/search",
            query: ["name": name, "count": "5"]
        )
        return response.results ?? []
    }

    static func forecast(for place: WeatherLocation) async throws -> WeatherConditions {
        try await request(
            "api.open-meteo.com", path: "/v1/forecast",
            query: [
                "latitude": String(place.latitude), "longitude": String(place.longitude),
                "current": "temperature_2m,weather_code,is_day",
                "daily": "temperature_2m_max,temperature_2m_min",
                "timezone": "auto", "forecast_days": "1"
            ]
        )
    }

    private static func request<Response: Decodable>(
        _ host: String, path: String, query: [String: String]
    ) async throws -> Response {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path
        components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url else { throw URLError(.badURL) }
        let (data, response) = try await URLSession.shared.data(for: URLRequest(url: url, timeoutInterval: 12))
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(Response.self, from: data)
    }
}

@Observable
final class WeatherMonitor {
    private(set) var location: WeatherLocation?
    private(set) var conditions: WeatherConditions?
    private(set) var failed = false
    @ObservationIgnored private var nextRefresh = Date.distantPast

    func watch(_ place: WeatherLocation?) async {
        if place != location {
            location = place
            conditions = nil
            failed = false
            nextRefresh = .distantPast
        }
        guard let place else { return }

        // Reopening Home reuses the last result. Closing Home cancels the refresh task.
        while !Task.isCancelled {
            let delay = nextRefresh.timeIntervalSinceNow
            if delay > 0 {
                do { try await Task.sleep(for: .seconds(delay)) }
                catch { return }
            }
            do {
                let forecast = try await WeatherService.forecast(for: place)
                guard !Task.isCancelled, location == place else { return }
                conditions = forecast
                failed = false
                nextRefresh = .now.addingTimeInterval(15 * 60)
            } catch {
                guard !Task.isCancelled, location == place else { return }
                failed = true
                nextRefresh = .now.addingTimeInterval(60)
            }
        }
    }
}
