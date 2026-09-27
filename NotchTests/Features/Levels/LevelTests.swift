import Foundation
import Testing
@testable import Notch

@MainActor
struct MediaKeyTests {
    private func data1(key: Int, down: Bool, repeating: Bool = false) -> Int {
        (key << 16) | ((down ? 0x0A : 0x0B) << 8) | (repeating ? 1 : 0)
    }

    @Test(arguments: [(0, MediaKey.volumeUp), (1, .volumeDown), (7, .mute), (2, .brightnessUp), (3, .brightnessDown)])
    func decodesTheKeys(code: Int, key: MediaKey) {
        let decoded = MediaKey.decode(subtype: 8, data1: data1(key: code, down: true))
        #expect(decoded?.key == key)
        #expect(decoded?.isDown == true)
    }

    @Test func aReleaseIsNotAPress() {
        #expect(MediaKey.decode(subtype: 8, data1: data1(key: 0, down: false))?.isDown == false)
    }

    @Test func aHeldKeyStillCountsAsPressed() {
        #expect(MediaKey.decode(subtype: 8, data1: data1(key: 1, down: true, repeating: true))?.isDown == true)
    }

    @Test func otherEventsAreIgnored() {
        #expect(MediaKey.decode(subtype: 8, data1: data1(key: 16, down: true)) == nil, "play/pause is Now Playing's")
        #expect(MediaKey.decode(subtype: 7, data1: data1(key: 0, down: true)) == nil)
    }
}

struct LevelStepTests {
    @Test func sixteenStepsFromSilentToFull() {
        var level = 0.0
        for _ in 0..<16 { level = LevelStep.next(from: level, up: true, fine: false) }
        #expect(level == 1)
    }

    @Test func stepsSnapToTheGrid() {
        // Set to 30% elsewhere (not on a sixteenth): the next press lands on a mark.
        let next = LevelStep.next(from: 0.30, up: true, fine: false)
        #expect((next * 16).rounded() == next * 16)
        #expect(next > 0.30)
    }

    @Test func fineStepsAreQuarters() {
        #expect(LevelStep.next(from: 0.5, up: true, fine: true) == 0.5 + 1.0 / 64)
    }

    @Test func staysInRange() {
        #expect(LevelStep.next(from: 1, up: true, fine: false) == 1)
        #expect(LevelStep.next(from: 0, up: false, fine: false) == 0)
    }
}

@MainActor
struct SandboxMigrationTests {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

    private func locations() -> SandboxMigration.Locations {
        SandboxMigration.Locations(
            preferences: folder.appendingPathComponent("old.plist"),
            shelf: folder.appendingPathComponent("OldShelf", isDirectory: true),
            newShelf: folder.appendingPathComponent("NewShelf", isDirectory: true)
        )
    }

    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: "SandboxMigrationTests.\(UUID().uuidString)")!
    }

    @Test func bringsSettingsAcrossWithoutOverwriting() throws {
        let places = locations()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let old: [String: Any] = ["settings.accent": "mint", "settings.width": "wide"]
        try PropertyListSerialization.data(fromPropertyList: old, format: .binary, options: 0).write(to: places.preferences)

        let defaults = defaults()
        defaults.set("compact", forKey: "settings.width")   // already set here: kept
        SandboxMigration.runIfNeeded(defaults: defaults, locations: places)

        #expect(defaults.string(forKey: "settings.accent") == "mint")
        #expect(defaults.string(forKey: "settings.width") == "compact")
    }

    @Test func movesShelfCopiesSoTheirBookmarksFollow() throws {
        let places = locations()
        try FileManager.default.createDirectory(at: places.shelf, withIntermediateDirectories: true)
        let file = places.shelf.appendingPathComponent("Shot.png")
        try Data([1, 2, 3]).write(to: file)
        let bookmark = try file.bookmarkData()

        SandboxMigration.runIfNeeded(defaults: defaults(), locations: places)

        let moved = places.newShelf.appendingPathComponent("Shot.png")
        #expect(FileManager.default.fileExists(atPath: moved.path))
        #expect(!FileManager.default.fileExists(atPath: file.path))
        var stale = false
        let resolved = try URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &stale)
        #expect(resolved.standardizedFileURL.resolvingSymlinksInPath() == moved.standardizedFileURL.resolvingSymlinksInPath())
    }

    @Test func runsOnlyOnce() throws {
        let places = locations()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let defaults = defaults()
        SandboxMigration.runIfNeeded(defaults: defaults, locations: places)
        try PropertyListSerialization.data(fromPropertyList: ["late": 1], format: .binary, options: 0).write(to: places.preferences)
        SandboxMigration.runIfNeeded(defaults: defaults, locations: places)
        #expect(defaults.object(forKey: "late") == nil)
    }

    @Test func nothingToMigrateIsFine() {
        let defaults = defaults()
        SandboxMigration.runIfNeeded(defaults: defaults, locations: locations())
        #expect(defaults.bool(forKey: SandboxMigration.doneKey))
    }
}
