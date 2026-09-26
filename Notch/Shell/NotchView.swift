import ServiceManagement
import SwiftUI

struct NotchView: View {

    let viewModel: NotchViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var geometry: NotchGeometry { viewModel.geometry }

    private var size: CGSize {
        switch viewModel.presentation {
        case .collapsed: geometry.collapsedRect.size
        case .expanded: NotchGeometry.expandedSize(withHeadline: viewModel.hasHeadline)
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
            .animation(NotchMotion.activityOpen(reduceMotion: reduceMotion), value: viewModel.hasHeadline)
            .foregroundStyle(.white)
            .clipShape(notchShape)
            .contextMenu { appMenu }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var earModule: (any NotchModule)? {
        viewModel.modules.earOwner
    }

    /// Which module owns the ears; changes to it are animated no matter which module caused them.
    private var earOwnerID: ObjectIdentifier? {
        earModule.map { ObjectIdentifier($0) }
    }

    private var collapsedContent: some View {
        Group {
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
        .animation(NotchMotion.earHandover(reduceMotion: reduceMotion), value: earOwnerID)
    }

    private var expandedContent: some View {
        VStack(spacing: 0) {
            if let headliner = viewModel.modules.headliner {
                // Clear of the camera band, then the full-width row, then the usual columns.
                Color.clear.frame(height: geometry.notchRect.height)
                AnyView(headliner.content(for: .headline))
                    .frame(height: NotchGeometry.headlineHeight - 8)
                    .padding(.horizontal, 24)
                    .transition(NotchMotion.earContent(reduceMotion: reduceMotion))
                Divider()
                    .overlay(.white.opacity(0.15))
                    .padding(.horizontal, 24)
            }
            moduleColumns
                .frame(maxHeight: .infinity)
        }
        .transition(.opacity)
    }

    private var moduleColumns: some View {
        HStack(spacing: 20) {
            let sections = viewModel.modules.filter(\.hasExpandedSection)
            ForEach(sections.indices, id: \.self) { index in
                if index > 0 {
                    Divider()
                        .overlay(.white.opacity(0.3))
                        .frame(height: 60)
                }
                AnyView(sections[index].content(for: .expanded))
            }
        }
    }

    @ViewBuilder
    private var appMenu: some View {
        let launchAtLogin = viewModel.launchAtLogin

        Toggle("Launch at Login", isOn: Binding(
            get: { launchAtLogin.isEnabled },
            set: { launchAtLogin.setEnabled($0) }
        ))
        if launchAtLogin.needsApproval {
            Button("Allow in Login Items Settings…") {
                SMAppService.openSystemSettingsLoginItems()
            }
        }
        if let error = launchAtLogin.lastError {
            Text(error)
        }
        Divider()
        Button("Quit Notch") {
            NSApplication.shared.terminate(nil)
        }
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
        ZStack {
            if let earModule {
                // A new identity per owner makes a handover a transition, not an in-place swap.
                AnyView(earModule.content(for: placement))
                    .id(earOwnerID)
                    .transition(NotchMotion.earContent(reduceMotion: reduceMotion))
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
    NotchView(viewModel: NotchViewModel(geometry: .previewHardware))
        .frame(width: 400, height: 150)
}

#Preview("Collapsed · virtual") {
    NotchView(viewModel: NotchViewModel(geometry: .previewVirtual))
        .frame(width: 400, height: 150)
}

#Preview("Expanded") {
    let model = NotchViewModel(geometry: .previewHardware)
    model.presentation = .expanded
    return NotchView(viewModel: model)
        .frame(width: 400, height: 150)
}

#Preview("Activity · charging") {
    ChargingBattery(status: BatteryStatus(level: 78, isCharging: true, isPluggedIn: true), startsFinished: true)
        .padding()
        .background(.black)
}
