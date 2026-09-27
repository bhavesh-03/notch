import Foundation

enum TimerFormat {
    /// "16:30" under an hour, "1:30:00" from an hour up; one format everywhere so displays agree.
    static func string(seconds: Int) -> String {
        let duration = Duration.seconds(max(0, seconds))
        return seconds >= 3600
            ? duration.formatted(.time(pattern: .hourMinuteSecond))
            : duration.formatted(.time(pattern: .minuteSecond))
    }

    /// The length in words, for sentences: "25 minutes", "30 seconds", "1 hour, 30 minutes".
    static func spoken(seconds: Int) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.hour, .minute, .second]
        return formatter.string(from: TimeInterval(max(0, seconds))) ?? "\(seconds) seconds"
    }
}
