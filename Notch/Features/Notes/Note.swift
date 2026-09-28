import Foundation

/// A quick note: plain text whose first line is its title, like Apple Notes.
struct Note: Codable, Equatable, Identifiable {
    let id: UUID
    var text: String
    var modified: Date
    var isPinned: Bool

    init(id: UUID = UUID(), text: String = "", modified: Date = .now, isPinned: Bool = false) {
        self.id = id
        self.text = text
        self.modified = modified
        self.isPinned = isPinned
    }

    var isEmpty: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// The first line with text in it.
    var title: String {
        lines.first ?? "New Note"
    }

    /// The text after the title, on one line, for list rows.
    var preview: String {
        lines.dropFirst().joined(separator: " ")
    }

    private var lines: [String] {
        text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
