import SwiftUI

/// Lets a module's view open a page without knowing about the view model, the way SwiftUI's own
/// `dismiss` action works: NotchView puts the action into the environment, views call it.
struct OpenNotchPageAction {
    fileprivate let open: (any NotchModule) -> Void

    init(_ open: @escaping (any NotchModule) -> Void) {
        self.open = open
    }

    func callAsFunction(_ module: any NotchModule) {
        open(module)
    }
}

extension EnvironmentValues {
    @Entry var openNotchPage = OpenNotchPageAction { _ in }
}

/// Lets a text field tell the notch someone is typing in it, so it stays open while the pointer
/// wanders off (the way a window stays put while you type in it).
struct TextEditingAction {
    fileprivate let report: (Bool) -> Void

    init(_ report: @escaping (Bool) -> Void) {
        self.report = report
    }

    func callAsFunction(_ isEditing: Bool) {
        report(isEditing)
    }
}

extension EnvironmentValues {
    @Entry var textEditing = TextEditingAction { _ in }
}
