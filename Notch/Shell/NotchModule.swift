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
}

extension NotchModule {
    /// Most modules do; one that only lives in the ears overrides this.
    var hasExpandedSection: Bool { true }

    /// Only a module with something big to show (like a media player) claims the headline.
    var hasHeadline: Bool { false }
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
