import SwiftUI

struct ContentView: View {

    let viewModel: NotchViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var geometry: NotchGeometry { viewModel.geometry }

    private var size: CGSize {
        switch viewModel.presentation {
        case .collapsed: geometry.collapsedRect.size
        case .expanded: NotchGeometry.expandedSize
        case .activity: geometry.activitySize
        }
    }

    private var cornerRadius: CGFloat {
        switch viewModel.presentation {
        case .collapsed: 10
        case .expanded: 24
        case .activity: 22
        }
    }

    private var notchShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            bottomLeadingRadius: cornerRadius,
            bottomTrailingRadius: cornerRadius
        )
    }

    var body: some View {
        notchShape.fill(.black)
            .frame(width: size.width, height: size.height)
            .overlay {
                switch viewModel.presentation {
                case .collapsed:
                    collapsedContent
                        .transition(NotchMotion.content(reduceMotion: reduceMotion))
                case .expanded:
                    expandedContent
                case .activity(let module):
                    activityContent(for: module)
                        .transition(NotchMotion.content(reduceMotion: reduceMotion))
                }
            }
            .foregroundStyle(.white)
            .clipShape(notchShape)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var earModule: (any NotchModule)? {
        viewModel.modules.earOwner
    }

    @ViewBuilder
    private var collapsedContent: some View {
        switch geometry.kind {
        case .hardware:
            HStack(spacing: 0) {
                ear(.leadingEar)
                    .frame(width: NotchGeometry.earWidth)
                Spacer()
                ear(.trailingEar)
                    .frame(width: NotchGeometry.earWidth)
            }
        case .virtual:
            ear(.pill)
        }
    }

    private var expandedContent: some View {
        HStack(spacing: 20) {
            ForEach(viewModel.modules.indices, id: \.self) { index in
                if index > 0 {
                    Divider()
                        .overlay(.white.opacity(0.3))
                        .frame(height: 60)
                }
                AnyView(viewModel.modules[index].content(for: .expanded))
            }
        }
        .transition(.opacity)
    }

    private func activityContent(for module: any NotchModule) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                AnyView(module.content(for: .activityLeading))
                    .frame(width: NotchGeometry.activityEarWidth)
                Spacer()
                AnyView(module.content(for: .activityTrailing))
                    .frame(width: NotchGeometry.activityEarWidth)
            }
            .frame(height: geometry.notchRect.height)

            AnyView(module.content(for: .activityDetail))
                .frame(maxHeight: .infinity)
        }
    }

    private func ear(_ placement: NotchPlacement) -> some View {
        Group {
            if let earModule {
                AnyView(earModule.content(for: placement))
            }
        }
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
    model.presentation = .expanded
    return ContentView(viewModel: model)
        .frame(width: 400, height: 150)
}

#Preview("Activity · charging") {
    ChargingBattery(status: BatteryStatus(level: 78, isCharging: true, isPluggedIn: true), startsFinished: true)
        .padding()
        .background(.black)
}
