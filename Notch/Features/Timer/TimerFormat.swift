import Foundation

enum TimerFormat {
    /// "16:30" under an hour, "1:30:00" from an hour up; one format everywhere so displays agree.
    static func string(seconds: Int) -> String {
        let duration = Duration.seconds(max(0, seconds))
        return seconds >= 3600
            ? duration.formatted(.time(pattern: .hourMinuteSecond))
            : duration.formatted(.time(pattern: .minuteSecond))
    }
}
