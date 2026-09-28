import Foundation
import Testing
@testable import Notch

struct NoteTests {
    @Test func theFirstLineIsTheTitle() {
        let note = Note(text: "\n  Groceries  \nmilk\n\neggs")
        #expect(note.title == "Groceries")
        #expect(note.preview == "milk eggs")
    }

    @Test func anEmptyNoteHasAPlaceholderTitle() {
        #expect(Note(text: "  \n ").title == "New Note")
        #expect(Note(text: "  \n ").isEmpty)
    }
}

@MainActor
struct NotesStoreTests {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent("NotesStoreTests-\(UUID().uuidString).json")

    private func date(_ minutes: Double) -> Date { Date(timeIntervalSince1970: 1_000_000 + minutes * 60) }

    @Test func newNotesGoOnTopBelowPinned() {
        let store = NotesStore(fileURL: file)
        let pinned = store.add(now: date(0))
        store.update(pinned.id, text: "Pinned", now: date(1))
        store.togglePin(pinned.id)
        let fresh = store.add(now: date(2))
        #expect(store.notes.map(\.id) == [pinned.id, fresh.id])
    }

    @Test func editingMovesANoteUp() {
        let store = NotesStore(fileURL: file)
        let a = store.add(now: date(0)); store.update(a.id, text: "A", now: date(0))
        let b = store.add(now: date(1)); store.update(b.id, text: "B", now: date(1))
        store.update(a.id, text: "A, edited", now: date(2))
        #expect(store.notes.map(\.text) == ["A, edited", "B"])
    }

    @Test func notesSurviveARelaunchButEmptyOnesDont() {
        let store = NotesStore(fileURL: file)
        let kept = store.add(now: date(0))
        store.update(kept.id, text: "Remember this", now: date(0))
        store.togglePin(kept.id)
        let blank = store.add(now: date(1))
        store.update(blank.id, text: "   ", now: date(1))

        let relaunched = NotesStore(fileURL: file)
        #expect(relaunched.notes.map(\.text) == ["Remember this"])
        #expect(relaunched.notes.first?.isPinned == true)
    }

    @Test func leavingAnEmptyNoteRemovesIt() {
        let store = NotesStore(fileURL: file)
        let note = store.add()
        store.removeIfEmpty(note.id)
        #expect(store.notes.isEmpty)

        let written = store.add()
        store.update(written.id, text: "Keep")
        store.removeIfEmpty(written.id)
        #expect(store.notes.count == 1)
    }

    @Test func deleting() {
        let store = NotesStore(fileURL: file)
        let note = store.add()
        store.update(note.id, text: "Temp")
        store.delete(note.id)
        #expect(NotesStore(fileURL: file).notes.isEmpty)
    }
}

@MainActor
struct NotesTabTests {
    @Test func notesIsATallTabNextToFiles() {
        let model = NotchViewModel(geometry: .previewHardware, settings: .ephemeral())
        #expect(model.notes.tab?.style == .tab)
        model.expand()
        model.select(tab: model.notes)
        #expect(model.isTall)
    }

    @Test func typingKeepsTheNotchOpen() async throws {
        let model = NotchViewModel(geometry: .previewHardware, settings: .ephemeral())
        model.expand()
        model.setEditingText(true)
        model.scheduleCollapse()
        try await Task.sleep(for: .milliseconds(500))
        #expect(model.isExpanded)

        model.setEditingText(false)
        model.scheduleCollapse()
        #expect(await eventually { !model.isExpanded })
    }
}
