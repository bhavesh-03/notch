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
    case activityLeading
    case activityTrailing
    case activityDetail
}

protocol NotchModule: AnyObject {
    associatedtype Content: View

    var earPriority: Int? { get }

    @ViewBuilder
    func content(for placement: NotchPlacement) -> Content
}
extension Array where Element == any NotchModule {
    /// The module that should occupy the collapsed ears: the highest `earPriority`, ignoring modules that return nil.
    var earOwner: (any NotchModule)? {
        compactMap { module in module.earPriority.map { (module, $0) } }
            .max { $0.1 < $1.1 }?
            .0
    }
}
