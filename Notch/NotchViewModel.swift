import SwiftUI

@Observable
final class NotchViewModel {
    var isExpanded = false {
        didSet { onExpandedChange?(isExpanded) }
    }
    @ObservationIgnored var onExpandedChange: ((Bool) -> Void)?
    private var collapseTask : Task<Void, Never>?
    var geometry: NotchGeometry
    
    init(geometry: NotchGeometry) {
        self.geometry = geometry
    }
    
    func expand() {
        collapseTask?.cancel()
        collapseTask = nil
        
        guard !isExpanded else {return}
        withAnimation(.snappy) {
            isExpanded = true
        }
        
    }
    
    func scheduleCollapse() {
        guard isExpanded, collapseTask == nil else {return}
        
        collapseTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else {return}
            
            withAnimation(.snappy) {
                isExpanded = false
            }
            collapseTask = nil
        }
    }
}
