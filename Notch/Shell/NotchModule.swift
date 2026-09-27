//
//  NotchModule.swift
//  Notch
//
//  Created by Vineet Parmar on 26/09/26.
//


import SwiftUI

enum NotchPlacement {
    case leadingEar
    case trailingEar
    case pill
    case expanded
    /// A full-width row above the module columns in the expanded notch.
    case headline
    /// The module's full-width page, opened from the tab bar or from the module's own UI.
    case page
    case activityLeading
    case activityTrailing
    case activityDetail
}

protocol NotchModule: AnyObject {
    associatedtype Content: View

    var earPriority: Int? { get }

    @ViewBuilder
    func content(for placement: NotchPlacement) -> Content

    /// Whether the module gets a column in the expanded notch.
    var hasExpandedSection: Bool { get }

    /// Whether the module wants the full-width headline row right now.
    var hasHeadline: Bool { get }

    /// A module with a tab gets its own page in the expanded notch (its `.expanded` content)
    /// instead of a column on Home.
    var tab: NotchTab? { get }

    /// Whether files dragged onto the notch should go to this module's tab.
    var acceptsFileDrops: Bool { get }

    /// Whether this module's page needs the tall expanded notch (e.g. a camera preview).
    var wantsTallPage: Bool { get }
}

/// A page a module adds to the expanded notch, opened from the bar beside the camera.
struct NotchTab: Equatable {
    enum Style {
        /// A labelled tab, left of the camera (e.g. Files).
        case tab
        /// An icon-only button, right of the camera (e.g. the mirror).
        case button
        /// No button at all; opened from the module's own UI (e.g. tapping the timer on Home).
        case page
    }

    let title: String
    let symbol: String
    var style: Style = .tab
}

extension NotchModule {
    /// Most modules do; one that only lives in the ears overrides this.
    var hasExpandedSection: Bool { true }

    /// Only a module with something big to show (like a media player) claims the headline.
    var hasHeadline: Bool { false }

    var tab: NotchTab? { nil }

    var acceptsFileDrops: Bool { false }

    var wantsTallPage: Bool { false }
}
extension Array where Element == any NotchModule {
    /// The module that should occupy the collapsed ears: the highest `earPriority`, ignoring modules that return nil.
    var earOwner: (any NotchModule)? {
        compactMap { module in module.earPriority.map { (module, $0) } }
            .max { $0.1 < $1.1 }?
            .0
    }
}

extension Array where Element == any NotchModule {
    /// The module shown in the headline row, if any wants it.
    var headliner: (any NotchModule)? {
        first { $0.hasHeadline }
    }
}
