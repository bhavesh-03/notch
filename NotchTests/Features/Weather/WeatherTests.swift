import Foundation
import Testing
@testable import Notch

@MainActor
struct WeatherTests {
    @Test func readsCurrentConditionsAndDailyRange() throws {
        let json = #"{"current":{"temperature_2m":18.3,"weather_code":0,"is_day":0},"daily":{"temperature_2m_max":[21.4],"temperature_2m_min":[12.1]}}"#
        let forecast = try JSONDecoder().decode(WeatherConditions.self, from: Data(json.utf8))
        #expect(forecast.current.temperature == 18.3)
        #expect(forecast.current.condition.symbol == "moon.stars.fill")
        #expect(forecast.daily.highs == [21.4])
        #expect(forecast.daily.lows == [12.1])
    }

    @Test func cityChoiceSurvivesRelaunchAndCanBeCleared() throws {
        let defaults = try #require(UserDefaults(suiteName: "WeatherTests.\(UUID().uuidString)"))
        let place = WeatherLocation(id: 1, name: "Lisbon", admin1: nil, country: "Portugal",
                                    latitude: 38.72, longitude: -9.13)
        let settings = NotchSettings(defaults: defaults)
        settings.weatherLocation = place
        #expect(NotchSettings(defaults: defaults).weatherLocation == place)
        settings.weatherLocation = nil
        #expect(NotchSettings(defaults: defaults).weatherLocation == nil)
    }
}
