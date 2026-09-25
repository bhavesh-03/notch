import SwiftUI

struct ContentView: View {

    let viewModel: NotchViewModel

    private var geometry: NotchGeometry { viewModel.geometry }

    private var size: CGSize {
        viewModel.isExpanded ? NotchGeometry.expandedSize : geometry.collapsedRect.size
    }

    private var notchShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            bottomLeadingRadius: viewModel.isExpanded ? 24 : 10,
            bottomTrailingRadius: viewModel.isExpanded ? 24 : 10
        )
    }

    var body: some View {
        notchShape.fill(.black)
            .frame(width: size.width, height: size.height)
            .overlay {
                if viewModel.isExpanded {
                    expandedContent
                } else {
                    collapsedContent
                }
            }
            .foregroundStyle(.white)
            .clipShape(notchShape)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var collapsedContent: some View {
        switch geometry.kind {
        case .hardware:
            HStack(spacing: 0) {
                Image(systemName: "battery.100")
                    .frame(width: NotchGeometry.earWidth)
                Spacer()
                Text("100%")
                    .font(.caption2)
                    .frame(width: NotchGeometry.earWidth)
            }
        case .virtual:
            Image(systemName: "battery.100")
        }
    }

    private var expandedContent: some View {
        HStack(spacing: 8) {
            Image(systemName: "battery.100")
            Text("Hello from inside the Notch")
        }
        .transition(.opacity)
    }
}

extension NotchGeometry {
    static let previewHardware = NotchGeometry(
        screenFrame: CGRect(x: 0, y: 0, width: 1470, height: 956),
        leftAreaWidth: 645.5,
        rightAreaWidth: 645.5,
        notchHeight: 32,
        kind: .hardware
    )

    static let previewVirtual = NotchGeometry(
        screenFrame: CGRect(x: 0, y: 0, width: 1470, height: 956),
        leftAreaWidth: 645,
        rightAreaWidth: 645,
        notchHeight: 24,
        kind: .virtual
    )
}

#Preview("Collapsed · hardware") {
    ContentView(viewModel: NotchViewModel(geometry: .previewHardware))
        .frame(width: 400, height: 150)
}

#Preview("Collapsed · virtual") {
    ContentView(viewModel: NotchViewModel(geometry: .previewVirtual))
        .frame(width: 400, height: 150)
}

#Preview("Expanded") {
    let model = NotchViewModel(geometry: .previewHardware)
    model.isExpanded = true
    return ContentView(viewModel: model)
        .frame(width: 400, height: 150)
}
