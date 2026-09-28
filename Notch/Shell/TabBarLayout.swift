import AppKit

/// How much of the tab bar can be labelled, given the room left of the camera. Labels that don't
/// fit would slide under the camera housing, so the bar steps down: every tab labelled, then only
/// the selected one (the rest as icons, like iOS), then icons only.
enum TabBarLayout {
    enum Labels: Equatable {
        case all, selectedOnly, none
    }

    static let iconWidth: CGFloat = 14
    static let iconTitleGap: CGFloat = 5
    static let padding: CGFloat = 18      // 9 each side
    static let spacing: CGFloat = 4

    /// `titleWidths` in bar order; `selected` is the index of the selected tab, if it's in the bar.
    static func labels(titleWidths: [CGFloat], selected: Int?, available: CGFloat) -> Labels {
        func width(labelled: (Int) -> Bool) -> CGFloat {
            let items = titleWidths.indices.map { index in
                iconWidth + padding + (labelled(index) ? iconTitleGap + titleWidths[index] : 0)
            }
            return items.reduce(0, +) + spacing * CGFloat(max(0, items.count - 1))
        }
        if width(labelled: { _ in true }) <= available { return .all }
        if width(labelled: { $0 == selected }) <= available { return .selectedOnly }
        return .none
    }

    /// A title's width in the tab bar's font.
    static func measure(_ title: String) -> CGFloat {
        let size = NSFont.preferredFont(forTextStyle: .caption1).pointSize
        return (title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: .medium)]).width.rounded(.up)
    }
}
