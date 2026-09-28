import Foundation

/// Quick notes, kept in a JSON file in the app's Application Support folder (not in the settings:
/// notes can grow long, and a file is easy to back up or read).
@Observable
final class NotesStore {
    /// Pinned first, then the most recently edited.
    private(set) var notes: [Note] = []

    @ObservationIgnored private let fileURL: URL

    init(fileURL: URL = NotesStore.defaultFileURL) {
        self.fileURL = fileURL
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode([Note].self, from: data) {
            notes = Self.sorted(saved.filter { !$0.isEmpty })
        }
    }

    static let defaultFileURL = URL.applicationSupportDirectory
        .appendingPathComponent(Bundle.main.bundleIdentifier ?? "com.vinzi.Notch", isDirectory: true)
        .appendingPathComponent("Notes.json")

    /// A store in a throwaway file, for tests and previews.
    static func ephemeral() -> NotesStore {
        NotesStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("Notes-\(UUID().uuidString).json"))
    }

    func note(_ id: UUID) -> Note? {
        notes.first { $0.id == id }
    }

    /// Starts a new, empty note at the top and returns it.
    @discardableResult
    func add(now: Date = .now) -> Note {
        let note = Note(modified: now)
        notes.insert(note, at: notes.firstIndex { !$0.isPinned } ?? notes.endIndex)
        return note
    }

    func update(_ id: UUID, text: String, now: Date = .now) {
        guard let index = notes.firstIndex(where: { $0.id == id }), notes[index].text != text else { return }
        notes[index].text = text
        notes[index].modified = now
        notes = Self.sorted(notes)
        save()
    }

    func togglePin(_ id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].isPinned.toggle()
        notes = Self.sorted(notes)
        save()
    }

    func delete(_ id: UUID) {
        notes.removeAll { $0.id == id }
        save()
    }

    /// A note left without any text isn't worth keeping.
    func removeIfEmpty(_ id: UUID) {
        guard note(id)?.isEmpty == true else { return }
        delete(id)
    }

    static func sorted(_ notes: [Note]) -> [Note] {
        notes.sorted { ($0.isPinned ? 0 : 1, $1.modified) < ($1.isPinned ? 0 : 1, $0.modified) }
    }

    private func save() {
        let kept = notes.filter { !$0.isEmpty }
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(kept).write(to: fileURL, options: .atomic)
    }
}
