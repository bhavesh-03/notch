import SwiftUI

extension NotesStore: NotchModule {
    var feature: NotchFeature { .notes }
    var earPriority: Int? { nil }

    var tab: NotchTab? { NotchTab(title: "Notes", symbol: "note.text") }

    /// The list and the editor need the room.
    var wantsTallPage: Bool { true }

    @ViewBuilder
    func content(for placement: NotchPlacement) -> some View {
        if placement == .page {
            NotesPage(store: self)
        }
    }
}

/// The notes list on the left, the selected note's editor on the right.
struct NotesPage: View {
    let store: NotesStore

    @State private var selectedID: UUID?
    @FocusState private var editorFocused: Bool
    @Environment(\.textEditing) private var textEditing
    @Environment(\.notchAccent) private var accent

    private var selected: Note? { selectedID.flatMap { store.note($0) } }

    var body: some View {
        HStack(spacing: 12) {
            list
                .frame(width: 170)
            Divider().overlay(.white.opacity(0.15))
            editor
        }
        .onAppear { selectedID = selectedID ?? store.notes.first?.id }
        .onChange(of: editorFocused) { textEditing(editorFocused) }
        .onDisappear {
            textEditing(false)
            if let selectedID { store.removeIfEmpty(selectedID) }
        }
    }

    // MARK: - List

    private var list: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Notes")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button(action: startNote) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 26, height: 26)
                        .glassControl(in: Circle())
                }
                .buttonStyle(.plain)
                .help("New note")
            }
            if store.notes.isEmpty {
                Text("No notes yet")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 2) {
                        ForEach(store.notes) { note in
                            row(note)
                        }
                    }
                }
            }
        }
    }

    private func row(_ note: Note) -> some View {
        let isSelected = note.id == selectedID
        return VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(accent)
                }
                Text(note.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            Text(Self.dateText(note.modified) + (note.preview.isEmpty ? "" : "  " + note.preview))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? .white.opacity(0.12) : .clear, in: .rect(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { select(note.id) }
    }

    // MARK: - Editor

    @ViewBuilder
    private var editor: some View {
        if let note = selected {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(note.modified.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.4))
                    Spacer()
                    iconButton(note.isPinned ? "pin.slash" : "pin", help: note.isPinned ? "Unpin" : "Pin") {
                        store.togglePin(note.id)
                    }
                    iconButton("trash", help: "Delete") {
                        let next = store.notes.first { $0.id != note.id }?.id
                        store.delete(note.id)
                        selectedID = next
                    }
                }
                TextEditor(text: Binding(
                    get: { store.note(note.id)?.text ?? "" },
                    set: { store.update(note.id, text: $0) }
                ))
                .font(.callout)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.never)
                .focused($editorFocused)
                .onKeyPress(.escape) {
                    editorFocused = false
                    return .handled
                }
            }
        } else {
            // The whole empty area is a button: click anywhere and start typing.
            Button(action: startNote) {
                VStack(spacing: 8) {
                    Image(systemName: "note.text")
                        .font(.title2)
                    Text(store.notes.isEmpty ? "Click to write a note" : "Click to start a new note")
                        .font(.caption)
                }
                .foregroundStyle(.white.opacity(0.5))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func iconButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 24, height: 24)
                .glassControl(in: Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func startNote() {
        select(store.add().id)
        // Focus once the editor exists (it's created by this same change).
        Task { editorFocused = true }
    }

    /// Leaving a note that's still empty drops it.
    private func select(_ id: UUID) {
        if let selectedID, selectedID != id { store.removeIfEmpty(selectedID) }
        selectedID = id
    }

    static func dateText(_ date: Date) -> String {
        Calendar.current.isDateInToday(date)
            ? date.formatted(date: .omitted, time: .shortened)
            : date.formatted(.dateTime.day().month(.abbreviated))
    }
}

/// The latest notes on Home; tapping opens the Notes tab.
struct NotesWidget: View {
    let store: NotesStore
    let size: WidgetSize
    @Environment(\.openNotchPage) private var openPage

    var body: some View {
        NotesWidgetContent(notes: store.notes, size: size)
            .contentShape(Rectangle())
            .onTapGesture { openPage(store) }
            .help("Open Notes")
    }
}

/// The widget's layout from plain values, so it can be previewed.
struct NotesWidgetContent: View {
    let notes: [Note]
    let size: WidgetSize
    @Environment(\.notchAccent) private var accent

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let first = notes.first {
                if size == .small || size == .wide {
                    noteText(first, lines: size == .wide ? 2 : 1)
                } else {
                    ForEach(notes.prefix(3)) { note in
                        noteText(note, lines: 1)
                    }
                }
            } else {
                Label("No notes", systemImage: "note.text")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func noteText(_ note: Note, lines: Int) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 3) {
                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(accent)
                }
                Text(note.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            if !note.preview.isEmpty {
                Text(note.preview)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(lines)
            }
        }
    }
}
