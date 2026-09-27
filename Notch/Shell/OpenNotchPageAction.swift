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
