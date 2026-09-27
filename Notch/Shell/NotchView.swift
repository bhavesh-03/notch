import ServiceManagement
import SwiftUI

struct NotchView: View {

    let viewModel: NotchViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var geometry: NotchGeometry { viewModel.geometry }

    private var size: CGSize {
        switch viewModel.presentation {
        case .collapsed: geometry.collapsedRect.size
        case .expanded: NotchGeometry.expandedSize(withHeadline: viewModel.isTall)
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
            // Below the clip on purpose: `.animation` only animates what's above it. Above the clip,
            // the clip would jump to the new size while the shape animated inside it, hiding a shrink.
            .animation(NotchMotion.pageResize(reduceMotion: reduceMotion), value: viewModel.isTall)
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
        ZStack(alignment: .top) {
            Group {
                if let tabModule = viewModel.selectedTabModule {
                    tabPage(for: tabModule)
                } else {
                    homePage
                }
            }
            .id(viewModel.selectedTab)
            .transition(NotchMotion.earContent(reduceMotion: reduceMotion))

            if !viewModel.tabModules.isEmpty {
                tabBar
            }
        }
        .animation(NotchMotion.earHandover(reduceMotion: reduceMotion), value: viewModel.selectedTab)
        .environment(\.openNotchPage, OpenNotchPageAction { [viewModel] module in viewModel.select(tab: module) })
        .transition(.opacity)
    }

    /// Home and the labelled tabs left of the camera; icon buttons (like the mirror) right of it.
    private var tabBar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                tabButton(title: "Home", symbol: "house.fill", module: nil)
                ForEach(tabs(.tab).indices, id: \.self) { index in
                    let module = tabs(.tab)[index]
                    if let tab = module.tab {
                        tabButton(title: tab.title, symbol: tab.symbol, module: module)
                    }
                }
            }
            .padding(.leading, 22)

            Spacer()

            HStack(spacing: 6) {
                ForEach(tabs(.button).indices, id: \.self) { index in
                    let module = tabs(.button)[index]
                    if let tab = module.tab {
                        iconButton(tab: tab, module: module)
                    }
                }
            }
            .padding(.trailing, 22)
        }
        .buttonStyle(.plain)
        .frame(height: geometry.notchRect.height)
    }

    private func tabs(_ style: NotchTab.Style) -> [any NotchModule] {
        viewModel.tabModules.filter { $0.tab?.style == style }
    }

    private func isSelected(_ module: (any NotchModule)?) -> Bool {
        viewModel.selectedTab == module.map { ObjectIdentifier($0) }
    }

    private func tabButton(title: String, symbol: String, module: (any NotchModule)?) -> some View {
        let selected = isSelected(module)
        return Button {
            viewModel.select(tab: module)
        } label: {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(selected ? .white.opacity(0.18) : .clear, in: Capsule())
                .foregroundStyle(.white.opacity(selected ? 1 : 0.55))
                .contentShape(Capsule())
        }
    }

    /// Toggles its page: opens it, or goes back to Home if it's already open.
    private func iconButton(tab: NotchTab, module: any NotchModule) -> some View {
        let selected = isSelected(module)
        return Button {
            viewModel.select(tab: selected ? nil : module)
        } label: {
            Image(systemName: tab.symbol)
                .font(.caption.weight(.medium))
                .frame(width: 24, height: 22)
                .background(selected ? .white.opacity(0.18) : .clear, in: Capsule())
                .foregroundStyle(.white.opacity(selected ? 1 : 0.55))
                .contentShape(Capsule())
        }
        .help(tab.title)
    }

    private func tabPage(for module: any NotchModule) -> some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: geometry.notchRect.height)
            AnyView(module.content(for: .page))
                .padding(.horizontal, 24)
                .padding(.top, 2)
                .padding(.bottom, 10)
                .frame(maxHeight: .infinity)
        }
    }

    private var homePage: some View {
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
            if viewModel.modules.contains(where: \.hasExpandedSection) || viewModel.showsHeadline {
                moduleColumns
                    .frame(maxHeight: .infinity)
            } else {
                Text("Nothing to show on Home. Right-click for Settings.")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxHeight: .infinity)
            }
        }
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

        Text(AppVersion.current)
        Divider()
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
        Button("Settings…") {
            viewModel.onOpenSettings?()
        }
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
