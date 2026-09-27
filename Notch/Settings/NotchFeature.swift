import Foundation

/// A feature the user can show, hide and reorder in Settings.
///
/// The raw values are what gets saved, so renaming a case would lose the user's choices for it.
enum NotchFeature: String, CaseIterable, Codable, Identifiable {
    case battery
    case timer
    case calendar
    case files
    case nowPlaying
    case mirror

    var id: String { rawValue }

    var title: String {
        switch self {
        case .battery: "Battery"
        case .timer: "Timer"
        case .calendar: "Calendar"
        case .files: "Files"
        case .nowPlaying: "Now Playing"
        case .mirror: "Mirror"
        }
    }

    var symbol: String {
        switch self {
        case .battery: "battery.75percent"
        case .timer: "timer"
        case .calendar: "calendar"
        case .files: "tray.full.fill"
        case .nowPlaying: "play.fill"
        case .mirror: "web.camera"
        }
    }

    var summary: String {
        switch self {
        case .battery: "Level and charging in the ears, and the charging animation"
        case .timer: "A countdown with a ruler to pick its length"
        case .calendar: "Your next event, and a countdown before meetings"
        case .files: "A shelf for files dropped onto the notch"
        case .nowPlaying: "What's playing in any app, with controls"
        case .mirror: "A live camera view, from a button beside the camera"
        }
    }
}
