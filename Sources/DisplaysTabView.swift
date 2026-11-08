import SwiftUI
import AppKit

// MARK: - TAB 0: Displays View

struct DisplaysTabView: View {
    @ObservedObject var displayManager: DisplayManager
    @ObservedObject var permissionsManager: PermissionsManager = PermissionsManager.shared
    @ObservedObject var virtualDisplayManager: VirtualDisplayManager = VirtualDisplayManager.shared
    @ObservedObject var launchAtLoginManager: LaunchAtLoginManager = LaunchAtLoginManager.shared

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
                    // Centralized Permissions Card Hub
                    PermissionsCardView(permissionsManager: permissionsManager)

                    // Virtual Display (Dummy Screen for Remote Desktop / Headless)
                    VirtualDisplayCardView(virtualDisplayManager: virtualDisplayManager)

                    // F1/F2 cursor-based brightness setting
                    HStack(spacing: 8) {
                        Image(systemName: "keyboard")
                            .font(.system(size: FS.body))
                            .foregroundStyle(Color.accentColor)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(tr("F1 / F2 chỉnh màn hình theo con trỏ chuột", "F1 / F2 controls brightness at mouse cursor"))
                                .font(.system(size: FS.label, weight: .medium))
                            Text(tr("Bật để chỉnh cả màn ngoài theo chuột; Tắt để dùng mặc định của macOS", "On: adjust display under cursor; Off: revert to native macOS controls"))
                                .font(.system(size: FS.caption))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Toggle("", isOn: Binding<Bool>(
                            get: { displayManager.isCursorBased },
                            set: { displayManager.isCursorBased = $0 }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .labelsHidden()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .cardBackground()

                    // Display List
                    VStack(spacing: 8) {
                        if displayManager.monitors.isEmpty {
                            EmptyStateView()
                        } else {
                            ForEach(displayManager.monitors) { monitor in
                                DisplayCardView(
                                    monitor: monitor,
                                    displayManager: displayManager,
                                    isSelected: displayManager.selectedID == monitor.id
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }

            // Quick Actions Bar (Soft disconnect)
            QuickActionsBar(displayManager: displayManager)
        }
    }
}

// MARK: - Menu Bar Drawer (Ngăn kéo gom ứng dụng Status Bar) Card View

// Hallmark · native settings component · existing Theme tokens
struct MenuBarHiderCardView: View {
    @AppStorage("menubar_drawer_details_expanded") private var showDetails = false
    @ObservedObject var manager = MenuBarHiderManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "menubar.rectangle")
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 3) {
                    Text(tr("Ngăn kéo Menu Bar", "Menu Bar Drawer"))
                        .font(.system(size: FS.label, weight: .semibold))
                    Text(tr("Truy cập các mục Menu Bar trong một bảng riêng.", "Access menu bar items in a separate panel."))
                        .font(.system(size: FS.caption))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { showDetails.toggle() }
                } label: {
                    Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                        .font(.system(size: FS.body, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .background(Circle().fill(Color.primary.opacity(0.04)))
                }
                .buttonStyle(.plain)
                .help(showDetails ? tr("Ẩn chi tiết", "Hide details") : tr("Hiện chi tiết", "Show details"))
                .accessibilityLabel(showDetails ? tr("Ẩn chi tiết", "Hide details") : tr("Hiện chi tiết", "Show details"))
                Toggle(tr("Bật ngăn kéo", "Enable drawer"), isOn: $manager.isEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
            }
            if showDetails {
                Divider()
                HStack {
                    Button { manager.toggle() } label: {
                        Label(manager.isExpanded ? tr("Đóng ngăn kéo", "Close drawer") : tr("Mở ngăn kéo", "Open drawer"), systemImage: "tray")
                    }
                    .controlSize(.small)
                    .disabled(!manager.isEnabled)
                    Spacer()
                    Text("⌘⌥B")
                        .font(.system(size: FS.caption, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Text(tr("Nhấn ⌥⌘B để mở bảng ứng dụng Menu Bar. Bấm ứng dụng để mở menu thật; kéo ☰ để đổi thứ tự icon trên thanh bar.", "Press ⌥⌘B to open menu bar apps. Click an app for its real menu; drag ☰ to reorder icons on the menu bar."))
                    .font(.system(size: FS.caption))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .cardBackground()
    }
}

// MARK: - Caffeinate (Anti-Sleep) Card View

struct CaffeinateCardView: View {
    @AppStorage("caffeinate_details_expanded") private var showDetails = false
    @ObservedObject var caffeinateManager: CaffeinateManager

    var body: some View {
        VStack(spacing: 8) {
            // Main Row: Icon, Title, Badge, and Switch
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: Rad.sm)
                        .fill(Color.primary.opacity(0.06))
                        .frame(width: 28, height: 28)

                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: FS.title, weight: .semibold))
                        .foregroundStyle(caffeinateManager.isActive ? Color.accentColor : Color.secondary)
                }

                VStack(alignment: .leading, spacing: 1.5) {
                    HStack(spacing: 6) {
                        Text(tr("Chống sleep màn", "Keep Screen Awake"))
                            .font(.system(size: FS.body, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        if caffeinateManager.isActive {
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(Color.accentColor)
                                    .frame(width: 5, height: 5)
                                Text(caffeinateManager.remainingFormatted)
                                    .font(.system(size: FS.caption, weight: .medium, design: .monospaced))
                                    .lineLimit(1)
                                    .fixedSize()
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1.5)
                            .background(Capsule().fill(Color.primary.opacity(0.06)))
                            .foregroundStyle(.secondary)
                        }
                    }

                    Text(tr("Giữ màn hình luôn sáng như 'caffeinate -d' trong Terminal", "Prevents display sleep, similar to 'caffeinate -d' in Terminal"))
                        .font(.system(size: FS.caption))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { showDetails.toggle() }
                } label: {
                    Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                        .font(.system(size: FS.body, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .background(Circle().fill(Color.primary.opacity(0.04)))
                }
                .buttonStyle(.plain)
                .help(showDetails ? tr("Ẩn chi tiết", "Hide details") : tr("Hiện chi tiết", "Show details"))
                .accessibilityLabel(showDetails ? tr("Ẩn chi tiết", "Hide details") : tr("Hiện chi tiết", "Show details"))
                Toggle("", isOn: Binding<Bool>(
                    get: { caffeinateManager.isActive },
                    set: { _ in caffeinateManager.toggle() }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
            }

            // Collapsing details leaves the active assertion and timer unchanged.
            if showDetails {
            HStack(spacing: 6) {
                ForEach(CaffeinateDuration.allCases) { duration in
                    Button {
                        caffeinateManager.setDuration(duration)
                    } label: {
                        Text(duration.title)
                            .font(.system(size: FS.caption, weight: caffeinateManager.selectedDuration == duration ? .semibold : .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3.5)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: Rad.sm)
                                    .fill(caffeinateManager.selectedDuration == duration
                                          ? Color.accentColor
                                          : Color.primary.opacity(0.05))
                            )
                            .foregroundStyle(
                                caffeinateManager.selectedDuration == duration
                                ? Color.white
                                : Color.primary
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            }
        }
        .padding(10)
        .cardBackground()
    }
}

// MARK: - Virtual Display (Dummy Screen) Card View

struct VirtualDisplayCardView: View {
    @ObservedObject var virtualDisplayManager: VirtualDisplayManager = VirtualDisplayManager.shared
    @ObservedObject var launchAtLoginManager: LaunchAtLoginManager = LaunchAtLoginManager.shared

    var body: some View {
        VStack(spacing: 8) {
            // Main Row: Icon, Title, Badge, Settings button, and Switch
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: Rad.sm)
                        .fill(virtualDisplayManager.isVirtualDisplayActive ? Color.accentColor.opacity(0.10) : Color.primary.opacity(0.06))
                        .frame(width: 28, height: 28)

                    Image(systemName: "display.2")
                        .font(.system(size: FS.title, weight: .semibold))
                        .foregroundStyle(virtualDisplayManager.isVirtualDisplayActive ? Color.accentColor : Color.secondary)
                }

                VStack(alignment: .leading, spacing: 1.5) {
                    HStack(spacing: 6) {
                        Text(tr("Màn hình ảo (Dummy Display)", "Virtual Display (Dummy Display)"))
                            .font(.system(size: FS.body, weight: .semibold))

                        if virtualDisplayManager.isVirtualDisplayActive {
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(Color.accentColor)
                                    .frame(width: 5, height: 5)
                                Text("\(virtualDisplayManager.currentResolution.width)×\(virtualDisplayManager.currentResolution.height)")
                                    .font(.system(size: FS.caption, weight: .semibold, design: .monospaced))
                            }
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Capsule().fill(Color.accentColor.opacity(0.10)))
                            .foregroundStyle(Color.accentColor)
                        }
                    }

                    Text(virtualDisplayManager.isVirtualDisplayActive
                         ? tr("Đang phát ảo · Tăng tốc GPU cho Parsec / TeamViewer", "Virtual screen active · GPU accelerated for Parsec / TeamViewer")
                         : tr("Tạo màn hình ảo cho máy gập, Mac mini headless", "Create dummy display for clamshell mode or headless Mac mini"))
                        .font(.system(size: FS.caption))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Expand / Collapse Settings Toggle Button
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        virtualDisplayManager.isCardExpanded.toggle()
                    }
                } label: {
                    Image(systemName: virtualDisplayManager.isCardExpanded ? "chevron.up.circle.fill" : "gearshape")
                        .font(.system(size: FS.body))
                        .foregroundStyle(virtualDisplayManager.isCardExpanded ? Color.accentColor : Color.secondary)
                        .padding(4)
                        .background(Circle().fill(Color.primary.opacity(0.04)))
                }
                .buttonStyle(.plain)
                .help(virtualDisplayManager.isCardExpanded ? tr("Thu gọn tùy chọn", "Collapse options") : tr("Tùy chỉnh độ phân giải, HiDPI, Bảo mật", "Customize resolution, HiDPI, Privacy"))

                Toggle("", isOn: Binding<Bool>(
                    get: { virtualDisplayManager.isVirtualDisplayActive },
                    set: { _ in
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            virtualDisplayManager.toggleVirtualDisplay()
                        }
                    }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
            }

            // Expanded Settings Panel
            if virtualDisplayManager.isCardExpanded || virtualDisplayManager.isVirtualDisplayActive {
                VStack(spacing: 7) {
                    Divider().opacity(0.4)

                    // Resolution Preset Header
                    HStack {
                        Text(tr("ĐỘ PHÂN GIẢI MÀN HÌNH ẢO", "VIRTUAL DISPLAY RESOLUTION"))
                            .font(.system(size: FS.caption, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(virtualDisplayManager.currentResolution.width)×\(virtualDisplayManager.currentResolution.height) @ \(Int(virtualDisplayManager.currentResolution.refreshRate))Hz")
                            .font(.system(size: FS.caption, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.accentColor)
                    }

                    // Resolution Preset Grid (2 columns)
                    resolutionGrid

                    // Bottom Quick Options: HiDPI toggle & Blackout Screen (Privacy)
                    quickOptionsRow
                }
            }
        }
        .padding(10)
        .cardBackground()
    }

    private var resolutionGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 5), GridItem(.flexible(), spacing: 5)], spacing: 5) {
            ForEach(Array(virtualDisplayManager.resolutions.enumerated()), id: \.offset) { index, res in
                Button {
                    virtualDisplayManager.selectedResolutionIndex = index
                } label: {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(virtualDisplayManager.selectedResolutionIndex == index ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 4.5, height: 4.5)

                        Text(res.name)
                            .font(.system(size: FS.caption, weight: virtualDisplayManager.selectedResolutionIndex == index ? .semibold : .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4.5)
                    .background(
                        RoundedRectangle(cornerRadius: Rad.sm)
                            .fill(virtualDisplayManager.selectedResolutionIndex == index
                                  ? Color.accentColor.opacity(0.10)
                                  : Color.primary.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Rad.sm)
                            .stroke(virtualDisplayManager.selectedResolutionIndex == index
                                    ? Color.accentColor.opacity(0.5)
                                    : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var quickOptionsRow: some View {
        HStack(spacing: 6) {
            // HiDPI toggle
            Button {
                virtualDisplayManager.isHiDPIEnabled.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: virtualDisplayManager.isHiDPIEnabled ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: FS.caption))
                        .foregroundStyle(virtualDisplayManager.isHiDPIEnabled ? Color.accentColor : Color.secondary)
                    Text("Retina (HiDPI)")
                        .font(.system(size: FS.caption, weight: .medium))
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3.5)
                .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.primary.opacity(0.04)))
            }
            .buttonStyle(.plain)
            .help(tr("HiDPI giúp hiển thị văn bản và icon siêu mịn chuẩn Retina", "HiDPI renders razor-sharp Retina text and icons"))

            Spacer()

            // Blackout Primary Display for Remote Privacy
            Button {
                virtualDisplayManager.toggleBlackoutPrimaryScreen()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: virtualDisplayManager.isBlackoutPrimaryActive ? "eye.slash.fill" : "eye.slash")
                        .font(.system(size: FS.caption))
                        .foregroundStyle(virtualDisplayManager.isBlackoutPrimaryActive ? Color.orange : Color.secondary)
                    Text(virtualDisplayManager.isBlackoutPrimaryActive ? tr("Đang tắt màn thật", "Primary Screen Off") : tr("Tắt tối màn thật", "Blackout Primary"))
                        .font(.system(size: FS.caption, weight: .medium))
                        .foregroundStyle(virtualDisplayManager.isBlackoutPrimaryActive ? Color.orange : Color.primary)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3.5)
                .background(
                    RoundedRectangle(cornerRadius: Rad.sm)
                        .fill(virtualDisplayManager.isBlackoutPrimaryActive ? Color.orange.opacity(0.10) : Color.primary.opacity(0.04))
                )
            }
            .buttonStyle(.plain)
            .help(tr("Tắt tối đen màn hình máy thật để chống nhìn trộm khi bạn điều khiển từ xa qua Parsec / TeamViewer", "Turn primary screen pitch black to prevent shoulder-surfing during remote sessions"))
        }
        .padding(.top, 2)
    }
}

// MARK: - Display Card View

struct DisplayCardView: View {
    var monitor: DisplayInfo
    @ObservedObject var displayManager: DisplayManager
    var isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header Row
            HStack(spacing: 6) {
                Image(systemName: monitor.isBuiltIn ? "laptopcomputer" : "display")
                    .font(.system(size: FS.body))
                    .foregroundStyle(monitor.isConnected ? Color.accentColor : Color.secondary)

                VStack(alignment: .leading, spacing: 1) {
                    Text(monitor.name)
                        .font(.system(size: FS.label, weight: .semibold))
                        .lineLimit(1)
                    Text("\(monitor.resolution) • \(monitor.isBuiltIn ? tr("Màn hình chính", "Built-in Display") : tr("Màn hình ngoài", "External Display"))")
                        .font(.system(size: FS.caption))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(Int(round(monitor.brightness * 100)))%")
                    .font(.system(size: FS.body, weight: .semibold, design: .rounded))
                    .foregroundStyle(monitor.isConnected ? Color.primary : Color.secondary)
            }

            if monitor.isConnected {
                // Brightness Slider
                Slider(
                    value: Binding<Double>(
                        get: { monitor.brightness },
                        set: { displayManager.setBrightness($0, for: monitor) }
                    ),
                    in: 0...1
                )
                .controlSize(.small)

                // Presets
                HStack(spacing: 4) {
                    ForEach([0.25, 0.50, 0.75, 1.0], id: \.self) { val in
                        Button("\(Int(val * 100))%") {
                            displayManager.setBrightness(val, for: monitor)
                        }
                        .font(.system(size: FS.caption, weight: .medium))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.primary.opacity(0.05)))
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    // Disconnect toggle
                    Button {
                        displayManager.toggleConnection(for: monitor)
                    } label: {
                        Text(monitor.isBuiltIn ? tr("Tắt màn", "Turn Off") : tr("Ngắt mềm", "Disconnect"))
                            .font(.system(size: FS.caption, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(monitor.isBuiltIn && !displayManager.canDisconnect(monitor))
                }
            } else {
                HStack {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color.orange.opacity(0.8))
                            .frame(width: 5, height: 5)
                        Text(tr("Đang ngắt mềm (Đã tắt)", "Disconnected (Turned Off)"))
                            .font(.system(size: FS.caption, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        displayManager.toggleConnection(for: monitor)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "power")
                                .font(.system(size: FS.caption, weight: .semibold))
                            Text(tr("Bật lại", "Turn On"))
                                .font(.system(size: FS.caption, weight: .semibold))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3.5)
                        .background(Capsule().fill(Color.accentColor))
                        .foregroundStyle(Color.white)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 2)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: Rad.sm)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: Rad.sm)
                        .stroke(isSelected ? Color.accentColor.opacity(0.6) : Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

// MARK: - Quick Actions Bar

struct QuickActionsBar: View {
    @ObservedObject var displayManager: DisplayManager

    var body: some View {
        HStack(spacing: 8) {
            if let ext = displayManager.monitors.first(where: { !$0.isBuiltIn }) {
                Button {
                    displayManager.toggleConnection(for: ext)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: ext.isConnected ? "display.slash" : "display")
                            .font(.system(size: FS.caption))
                        Text(ext.isConnected ? tr("Ngắt màn ngoài", "Disconnect External") : tr("Bật màn ngoài", "Connect External"))
                            .font(.system(size: FS.caption, weight: ext.isConnected ? .regular : .bold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color(nsColor: .controlBackgroundColor)))
                    .foregroundStyle(ext.isConnected ? Color.primary : Color.accentColor)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            if displayManager.monitors.contains(where: { !$0.isConnected }) {
                Button {
                    displayManager.connectAllDisplays()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: FS.caption))
                        Text(tr("Bật tất cả màn hình", "Turn On All Displays"))
                            .font(.system(size: FS.caption, weight: .semibold))
                    }
                    .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "display.trianglebadge.exclamationmark")
                .font(.system(size: FS.display))
                .foregroundStyle(.tertiary)
            Text(tr("Không tìm thấy màn hình nào", "No displays detected"))
                .font(.system(size: FS.label))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

