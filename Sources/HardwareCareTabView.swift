import SwiftUI
import AppKit

// MARK: - TAB 1: Hardware Care, Battery & Thermal View

struct HardwareCareTabView: View {
    @ObservedObject var batteryManager: BatteryManager
    @ObservedObject var thermalManager: ThermalManager = ThermalManager.shared

    var body: some View {
        VStack(spacing: 6) {
            // Segment Switcher: Pin & Nguồn vs Tản nhiệt & Quạt
            HStack(spacing: 4) {
                sectionButton(
                    index: 0,
                    title: tr("Pin & Nguồn SMC", "Battery & Power SMC"),
                    icon: "bolt.shield.fill"
                )
                sectionButton(
                    index: 1,
                    title: tr("Nhiệt độ & Cảm biến", "Thermals & Sensors"),
                    icon: "thermometer.sun.fill",
                    badge: thermalManager.cpuAvgTemp > 0 ? String(format: "%.0f°C", thermalManager.cpuPeakTemp > 0 ? thermalManager.cpuPeakTemp : thermalManager.cpuAvgTemp) : nil
                )
            }
            .padding(3)
            .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.primary.opacity(0.04)))
            .padding(.horizontal, 12)
            .padding(.top, 4)

            // Tốc độ truyền file (ổ vật lý + LAN/NAS) — luôn hiển thị
            FileTransferSpeedCard()
                .padding(.horizontal, 12)
                .padding(.top, 4)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
                    if thermalManager.selectedSection == 0 {
                        BatteryCardView(batteryManager: batteryManager, onSelectThermalSection: {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                thermalManager.selectedSection = 1
                            }
                        })
                    } else {
                        ThermalAndFanCardView(thermalManager: thermalManager)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }
        }
    }

    private func sectionButton(index: Int, title: String, icon: String, badge: String? = nil) -> some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                thermalManager.selectedSection = index
            }
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: FS.caption, weight: thermalManager.selectedSection == index ? .semibold : .medium))

                if let badge = badge, !badge.isEmpty {
                    Text(badge)
                        .font(.system(size: FS.caption, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(thermalManager.selectedSection == index ? Color.white.opacity(0.25) : Color.primary.opacity(0.08)))
                }
            }
            .padding(.vertical, 4.5)
            .frame(maxWidth: .infinity)
            .contentShape(RoundedRectangle(cornerRadius: Rad.sm))
            .background(
                RoundedRectangle(cornerRadius: Rad.sm)
                    .fill(thermalManager.selectedSection == index ? Color.accentColor : Color.clear)
            )
            .foregroundStyle(thermalManager.selectedSection == index ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - File Transfer Speed Card (ổ vật lý + LAN/NAS)

/* Hallmark · pre-emit critique: P5 H5 E5 S5 R5 V5 */
struct FileTransferSpeedCard: View {
    @ObservedObject var diskSpeed: DiskSpeedManager = DiskSpeedManager.shared

    private var isActive: Bool {
        diskSpeed.totalReadMBps >= 0.05 || diskSpeed.totalWriteMBps >= 0.05 ||
        diskSpeed.networkReadMBps >= 0.05 || diskSpeed.networkWriteMBps >= 0.05
    }

    private var busiestDisk: DiskSpeedInfo? {
        diskSpeed.disks.filter(\.isActive).max { $0.totalMBps < $1.totalMBps }
    }

    /// Nguồn → đích của phiên chép đang chạy (ví dụ "U280-Pro → SSD nội bộ").
    /// Khi chỉ có một ổ vừa đọc vừa ghi thì hiện tên ổ đó.
    private var transferPath: String? {
        let reader = diskSpeed.disks
            .filter { $0.readMBps >= 1 }
            .max { $0.readMBps < $1.readMBps }
        let writer = diskSpeed.disks
            .filter { $0.writeMBps >= 1 }
            .max { $0.writeMBps < $1.writeMBps }

        switch (reader, writer) {
        case let (source?, destination?) where source.bsdName != destination.bsdName:
            return "\(source.displayName) → \(destination.displayName)"
        case let (_, destination?):
            return destination.displayName
        case let (source?, nil):
            return "\(tr("Đọc từ", "Reading from")) \(source.displayName)"
        default:
            return busiestDisk?.displayName
        }
    }

    private var networkActive: Bool {
        diskSpeed.networkReadMBps >= 0.05 || diskSpeed.networkWriteMBps >= 0.05
    }

    private var detailText: String? {
        var parts: [String] = []
        if let path = transferPath {
            parts.append(path)
        }
        if networkActive, let label = diskSpeed.networkLabel {
            parts.append("\(label) (NAS)")
        }
        if let process = diskSpeed.topProcessName {
            parts.append("\(process) \(speedText(max(diskSpeed.topProcessWriteMBps, diskSpeed.topProcessReadMBps)))")
        }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " · ")
    }

    private var tooltip: String {
        var lines = [tr("Tổng hợp mọi ổ vật lý đang đọc/ghi", "Aggregated active physical drives read/write")]
        for disk in diskSpeed.disks where disk.isActive {
            lines.append("\(disk.displayName): ↓\(speedText(disk.readMBps)) ↑\(speedText(disk.writeMBps))")
        }
        if let label = diskSpeed.networkLabel {
            lines.append("\(label): ↓\(speedText(diskSpeed.networkReadMBps)) ↑\(speedText(diskSpeed.networkWriteMBps))")
        }
        return lines.joined(separator: "\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: "arrow.up.arrow.down.circle.fill")
                    .font(.system(size: FS.caption))
                    .foregroundStyle(diskSpeed.isEnabled && isActive ? Color.accentColor : Color.secondary)

                Text(diskSpeed.isEnabled ? tr("Chép file", "File Transfer") : tr("Đo tốc độ chép file", "Transfer Speed"))
                    .font(.system(size: FS.caption, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                Spacer()

                if diskSpeed.isEnabled {
                    speedChip(icon: "arrow.down", value: diskSpeed.totalReadMBps, color: .accentColor)
                    speedChip(icon: "arrow.up", value: diskSpeed.totalWriteMBps, color: .secondary)

                    if diskSpeed.networkLabel != nil {
                        Divider().frame(height: 9)
                        speedChip(icon: "network", value: max(diskSpeed.networkReadMBps, diskSpeed.networkWriteMBps), color: .secondary)
                    }
                }

                Toggle("", isOn: Binding(
                    get: { diskSpeed.isEnabled },
                    set: { diskSpeed.setEnabled($0) }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
                .help(diskSpeed.isEnabled
                      ? "Đang đo khi bảng này mở. Tắt để HyperMac ngừng quét hoàn toàn."
                      : "Bật để đo tốc độ chép file (ổ cứng, thẻ nhớ, NAS qua LAN).")
            }

            if diskSpeed.isEnabled, let detail = detailText {
                Text(detail)
                    .font(.system(size: FS.caption))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .cardBackground()
        .help(diskSpeed.isEnabled ? tooltip : "Đo tốc độ chép file đang tắt")
        .animation(.easeOut(duration: 0.2), value: detailText)
    }

    private func speedChip(icon: String, value: Double, color: Color) -> some View {
        let active = value >= 0.05
        return HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: FS.caption, weight: .semibold))
            Text(Self.speedText(value))
                .font(.system(size: FS.caption, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(active ? color : Color.secondary.opacity(0.7))
    }

    static func speedText(_ mbps: Double) -> String {
        if mbps >= 1024 { return String(format: "%.1f GB/s", mbps / 1024) }
        if mbps >= 10 { return String(format: "%.0f MB/s", mbps) }
        if mbps >= 0.1 { return String(format: "%.1f MB/s", mbps) }
        if mbps >= 0.01 { return String(format: "%.0f KB/s", mbps * 1024) }
        return "0 MB/s"
    }

    private func speedText(_ mbps: Double) -> String { Self.speedText(mbps) }
}

// MARK: - Battery Protection Card View (Hallmark-Disciplined & Un-Clipped)

struct BatteryCardView: View {
    @ObservedObject var batteryManager: BatteryManager
    @ObservedObject var energyManager: ProcessEnergyManager = ProcessEnergyManager.shared
    var onSelectThermalSection: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Main Battery Level Bar + Target Limit Notch + Live Wattage
            VStack(spacing: 4) {
                HStack(alignment: .lastTextBaseline) {
                    HStack(spacing: 2) {
                        Text("\(batteryManager.currentLevel)")
                            .font(.system(size: FS.hero, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        Text("%")
                            .font(.system(size: FS.body, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Live Wattage
                    if batteryManager.isProtectionEnabled && batteryManager.isBypassActive && batteryManager.isPluggedIn {
                        Text("0.0W (" + tr("Nguồn AC trực tiếp", "Direct AC Power") + ")")
                            .font(.system(size: FS.label, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                    } else if batteryManager.isCharging || (batteryManager.isPluggedIn && batteryManager.wattage > 0.05 && batteryManager.amperage > 0) {
                        Text(String(format: "+%.1fW (" + tr("Đang sạc", "Charging") + ")", batteryManager.wattage))
                            .font(.system(size: FS.label, weight: .semibold))
                            .foregroundStyle(Tone.good)
                    } else if batteryManager.isPluggedIn {
                        if batteryManager.isFullyCharged || batteryManager.currentLevel >= 100 {
                            Text(tr("Đã sạc đầy 100%", "Fully Charged"))
                                .font(.system(size: FS.label, weight: .semibold))
                                .foregroundStyle(Tone.good)
                        } else if batteryManager.adapterWatts > 0 {
                            Text(String(format: "0.0W (" + tr("Củ sạc %dW", "Charger %dW") + ")", batteryManager.adapterWatts))
                                .font(.system(size: FS.label, weight: .semibold))
                                .foregroundStyle(.secondary)
                        } else {
                            Text("0.0W (" + tr("Đã cắm sạc", "Plugged in") + ")")
                                .font(.system(size: FS.label, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        let mins = batteryManager.timeRemaining
                        let timeStr = mins > 0 ? " • " + tr("Còn ~\(mins / 60)h\(mins % 60)m", "~\(mins / 60)h\(mins % 60)m left") : ""
                        Text(String(format: "-%.1fW%@", batteryManager.wattage, timeStr))
                            .font(.system(size: FS.caption, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                // Custom Progress Bar with Lock Notch
                GeometryReader { geo in
                    let width = geo.size.width
                    let levelFraction = min(1.0, max(0.0, Double(batteryManager.currentLevel) / 100.0))
                    let limitFraction = min(1.0, max(0.0, Double(batteryManager.chargeLimit) / 100.0))

                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: Rad.sm)
                            .fill(Color.primary.opacity(0.08))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: Rad.sm)
                            .fill(
                                LinearGradient(
                                    colors: (batteryManager.isProtectionEnabled && batteryManager.isBypassActive && batteryManager.isPluggedIn)
                                        ? [Color.accentColor, Color.accentColor]
                                        : [Tone.good, Color.accentColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(8, width * levelFraction), height: 8)

                        if batteryManager.isProtectionEnabled {
                            Rectangle()
                                .fill(Color.orange)
                                .frame(width: 2.5, height: 12)
                                .offset(x: max(0, width * limitFraction - 1.25), y: 0)
                        }
                    }
                }
                .frame(height: 12)

                if batteryManager.isProtectionEnabled {
                    HStack {
                        Spacer()
                        Text(tr("Ngưỡng khóa: \(batteryManager.chargeLimit)%", "Charge limit: \(batteryManager.chargeLimit)%"))
                            .font(.system(size: FS.caption, weight: .medium))
                            .foregroundStyle(.orange)
                    }
                }
            }

            // 4 Hardware Health & Telemetry Metrics (Clean 4-column row)
            HStack(spacing: 5) {
                metricChip(
                    icon: "heart.fill",
                    iconColor: .secondary,
                    title: tr("Độ khỏe cell", "Cell Health"),
                    val: String(format: "%.1f%%", batteryManager.exactHealthPercent),
                    sub: "\(batteryManager.nominalCapacity)/\(batteryManager.designCapacity)"
                )
                metricChip(
                    icon: "arrow.triangle.2.circlepath",
                    iconColor: .secondary,
                    title: tr("Chu kỳ sạc", "Cycle Count"),
                    val: "\(batteryManager.cycleCount) " + tr("lần", "cycles"),
                    sub: tr("Thiết kế: 1000", "Design: 1000")
                )
                Button {
                    onSelectThermalSection?()
                } label: {
                    metricChip(
                        icon: "thermometer.medium",
                        iconColor: tempBadgeColor,
                        title: tr("Nhiệt độ pin", "Battery Temp"),
                        val: String(format: "%.1f°C", batteryManager.temperature),
                        sub: tempStatusText + " ›",
                        valColor: tempBadgeColor
                    )
                }
                .buttonStyle(.plain)
                .help(tr("Bấm để mở kiểm soát nhiệt độ & quạt", "Click to open thermals & fans control"))

                metricChip(
                    icon: (batteryManager.isPluggedIn && batteryManager.adapterWatts > 0) ? "bolt.fill" : "battery.100",
                    iconColor: (batteryManager.isPluggedIn && batteryManager.adapterWatts > 0) ? .secondary : .secondary,
                    title: tr("Củ sạc", "Adapter"),
                    val: (batteryManager.isPluggedIn && batteryManager.adapterWatts > 0) ? "\(batteryManager.adapterWatts)W" : tr("Dùng Pin", "On Battery"),
                    sub: (batteryManager.isPluggedIn && batteryManager.adapterWatts > 0) ? (batteryManager.adapterDescription.isEmpty ? "USB-C PD" : batteryManager.adapterDescription) : tr("Không cắm sạc", "Unplugged")
                )
            }

            // High-Temperature Alert Banner
            if batteryManager.temperature >= batteryManager.tempAlertThreshold {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill").font(.system(size: FS.body)).foregroundStyle(.red)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(tr("Cảnh báo: Pin đang ấm (\(String(format: "%.1f°C", batteryManager.temperature)))!", "Warning: Battery is warm (\(String(format: "%.1f°C", batteryManager.temperature)))!"))
                            .font(.system(size: FS.caption, weight: .semibold)).foregroundStyle(.red)
                        Text(tr("MacBook Air không quạt. Hãy chuyển sang tab 'Đóng băng' để tạm dừng tiến trình nặng.", "Fanless MacBook. Switch to 'Freeze' tab to suspend heavy processes."))
                            .font(.system(size: FS.caption)).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(6)
                .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.red.opacity(0.1)))
            }

            // Sub-Navigation Pills (4 Tabs: Nguồn SMC, Sleep Guard, Đóng băng CPU, Lịch hiệu chuẩn)
            HStack(spacing: 3) {
                subTabButton(index: 0, title: tr("Nguồn SMC", "SMC Power"), icon: "bolt.shield")
                subTabButton(index: 1, title: "Sleep Guard", icon: "moon.stars")
                subTabButton(index: 2, title: tr("Đóng băng", "Freeze"), icon: "snowflake")
                subTabButton(index: 3, title: tr("Hiệu chuẩn", "Calibrate"), icon: "calendar.badge.clock")
            }
            .padding(2)
            .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.primary.opacity(0.05)))

            // Sub-Tab Content
            switch batteryManager.selectedHardwareTab {
            case 0:
                powerOverviewSubTab
            case 1:
                sleepGuardSubTab
            case 2:
                processFreezeSubTab
            case 3:
                autoScheduledCalibrationSubTab
            default:
                powerOverviewSubTab
            }
        }
        .padding(10)
        .cardBackground()
    }

    private func metricChip(icon: String, iconColor: Color, title: String, val: String, sub: String, valColor: Color = .primary) -> some View {
        VStack(spacing: 1.5) {
            HStack(spacing: 2.5) {
                Text(title).font(.system(size: FS.caption, weight: .medium)).foregroundStyle(.secondary)
                    .lineLimit(1).minimumScaleFactor(0.75)
            }
            Text(val).font(.system(size: FS.body, weight: .semibold, design: .rounded)).foregroundStyle(valColor)
                .lineLimit(1).minimumScaleFactor(0.75)
            Text(sub).font(.system(size: FS.caption)).foregroundStyle(.tertiary)
                .lineLimit(1).minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, minHeight: 58)
        .padding(.vertical, 4.5)
        .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.primary.opacity(0.04)))
    }

    private func subTabButton(index: Int, title: String, icon: String) -> some View {
        Button {
            batteryManager.selectedHardwareTab = index
            if index == 2 {
                energyManager.refreshProcesses()
            }
        } label: {
            HStack(spacing: 2.5) {
                Text(title).font(.system(size: FS.caption, weight: batteryManager.selectedHardwareTab == index ? .semibold : .medium))
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 3.5)
            .frame(maxWidth: .infinity)
            .contentShape(RoundedRectangle(cornerRadius: Rad.sm))
            .background(
                RoundedRectangle(cornerRadius: Rad.sm)
                    .fill(batteryManager.selectedHardwareTab == index ? Color.accentColor : Color.clear)
            )
            .foregroundStyle(batteryManager.selectedHardwareTab == index ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }

    // SUB-TAB 0: NGUỒN SMC
    private var powerOverviewSubTab: some View {
        VStack(spacing: 7) {
            if !batteryManager.isHelperInstalled {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.system(size: FS.body))
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 1) {
                        let isOldHelper = batteryManager.helperVersion > 0 && batteryManager.helperVersion < 2
                        Text(isOldHelper
                             ? tr("Cần cập nhật Helper SMC lên bản mới (v2)", "SMC Helper update required (v2)")
                             : tr("Chưa cấp quyền SMC (hoặc bạn đã bấm Bỏ qua)", "SMC Helper not installed (or skipped)"))
                            .font(.system(size: FS.caption, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text(tr("Cần xác nhận Touch ID / Mật khẩu máy để khóa sạc 80% & chỉnh quạt", "Confirm with Touch ID / password to lock 80% & control fans"))
                            .font(.system(size: FS.caption))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        batteryManager.installHelper()
                    } label: {
                        HStack(spacing: 4) {
                            if batteryManager.isInstallingHelper {
                                ProgressView().controlSize(.mini)
                            }
                            let isOldHelper = batteryManager.helperVersion > 0 && batteryManager.helperVersion < 2
                            Text(batteryManager.isInstallingHelper
                                 ? tr("Đang cài...", "Installing...")
                                 : (isOldHelper ? tr("Cập nhật ngay", "Update Now") : tr("Cấp quyền ngay", "Grant Now")))
                                .font(.system(size: FS.caption, weight: .semibold))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(Color.orange.opacity(0.12))
                        .foregroundStyle(.orange)
                        .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .disabled(batteryManager.isInstallingHelper)
                }
                .padding(7)
                .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.orange.opacity(0.08)))
            }

            HStack(spacing: 8) {
                Image(systemName: "lock.shield")
                    .font(.system(size: FS.label))
                    .foregroundStyle(batteryManager.isProtectionEnabled ? Color.accentColor : Color.secondary)
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("Khóa sạc ở \(batteryManager.chargeLimit)% (Chạy điện trực tiếp)", "Charge limit at \(batteryManager.chargeLimit)% (Bypass Mode)"))
                        .font(.system(size: FS.label, weight: .semibold))
                    Text(tr("Cắm sạc liên tục không chai pin (SMC Bypass)", "Plug in continuously without battery wear (SMC Bypass)"))
                        .font(.system(size: FS.caption)).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: Binding<Bool>(
                    get: { batteryManager.isProtectionEnabled },
                    set: { newVal in
                        if newVal {
                            if !batteryManager.isHelperInstalled {
                                batteryManager.isProtectionEnabled = true
                                batteryManager.installHelper { success in
                                    if !success {
                                        batteryManager.isProtectionEnabled = false
                                    }
                                }
                            } else {
                                batteryManager.isProtectionEnabled = true
                            }
                        } else {
                            batteryManager.isProtectionEnabled = false
                        }
                    }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
            }

            if batteryManager.isProtectionEnabled {
                HStack(spacing: 6) {
                    Text(tr("Mức khóa:", "Limit:"))
                        .font(.system(size: FS.caption, weight: .medium))
                        .foregroundStyle(.secondary)
                    ForEach([70, 80, 90], id: \.self) { val in
                        Button {
                            if val < 80 && !batteryManager.isHelperInstalled {
                                batteryManager.installHelper { success in
                                    if success {
                                        batteryManager.chargeLimit = val
                                    }
                                }
                            } else {
                                batteryManager.chargeLimit = val
                            }
                        } label: {
                            Text("\(val)%\(val == 80 ? " (" + tr("Chuẩn", "Standard") + ")" : "")")
                                .font(.system(size: FS.caption, weight: batteryManager.chargeLimit == val ? .semibold : .medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(batteryManager.chargeLimit == val ? Color.accentColor : Color.primary.opacity(0.06)))
                                .foregroundStyle(batteryManager.chargeLimit == val ? Color.white : Color.primary)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
            }

            HStack(spacing: 8) {
                Button {
                    batteryManager.isTopUpActive.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: batteryManager.isTopUpActive ? "xmark.circle" : "bolt.fill")
                            .font(.system(size: FS.caption))
                        Text(batteryManager.isTopUpActive ? tr("Hủy sạc 100% (Khóa lại)", "Cancel 100% (Re-lock)") : tr("Sạc đầy 100% tạm thời", "Temporary 100% Top-up"))
                            .font(.system(size: FS.caption, weight: .semibold))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3.5)
                    .background(batteryManager.isTopUpActive ? Color.orange.opacity(0.10) : Color.primary.opacity(0.06))
                    .foregroundStyle(batteryManager.isTopUpActive ? Color.orange : Color.primary)
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
                Spacer()
                Text(tr("Khi cần mang máy ra ngoài", "When taking laptop on the go")).font(.system(size: FS.caption)).foregroundStyle(.tertiary)
                    .lineLimit(1).minimumScaleFactor(0.7).layoutPriority(-1)
            }

            // Toggles
            toggleRow(icon: "thermometer.sun.fill", iconColor: .secondary, title: tr("Thông báo khi pin nóng > 38°C", "Alert when battery temp > 38°C"), isOn: Binding<Bool>(
                get: { batteryManager.isTempAlertEnabled },
                set: { batteryManager.isTempAlertEnabled = $0 }
            ))
            toggleRow(icon: "bell.badge.fill", iconColor: .secondary, title: tr("Cảnh báo chống chai pin (Màn ngoài, pin < 20%)", "Battery health warning (External display, < 20%)"), isOn: Binding<Bool>(
                get: { batteryManager.isSmartAlertsEnabled },
                set: { batteryManager.isSmartAlertsEnabled = $0 }
            ))

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lightbulb")
                    .font(.system(size: FS.label))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                Text(tr("Lưu ý: Tắt 'Sạc pin tối ưu hoá' trong Cài đặt hệ thống để tránh macOS tự sạc lên 100%.", "Tip: Turn off 'Optimized Battery Charging' in macOS Settings to prevent macOS overriding limit."))
                    .font(.system(size: FS.caption))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 2)
        }
    }

    // SUB-TAB 1: SLEEP GUARD
    private var sleepGuardSubTab: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Image(systemName: "moon").font(.system(size: FS.label)).foregroundStyle(.secondary).frame(width: 16)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("Bảo vệ Sleep Guard khi gập máy", "Sleep Guard Clamshell Protection"))
                        .font(.system(size: FS.label, weight: .semibold))
                    Text(tr("Chống Dark Wake và ngăn máy nóng ngầm trong balo", "Prevents Dark Wake & background heating in backpack"))
                        .font(.system(size: FS.caption)).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: Binding<Bool>(
                    get: { batteryManager.isSleepGuardEnabled },
                    set: { batteryManager.isSleepGuardEnabled = $0 }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
            }

            if batteryManager.isSleepGuardEnabled {
                HStack(spacing: 8) {
                    Image(systemName: "wave.3.forward").font(.system(size: FS.label)).foregroundStyle(.secondary).frame(width: 16)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tr("Tự ngắt Bluetooth khi gập máy", "Auto-disconnect Bluetooth on lid close"))
                            .font(.system(size: FS.label, weight: .semibold))
                        Text(tr("AirPods/chuột không đánh thức máy ngầm qua đêm. Tự bật lại ngay khi mở máy.", "AirPods/mouse won't wake Mac overnight. Auto re-connects on lid open."))
                            .font(.system(size: FS.caption)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding<Bool>(
                        get: { batteryManager.sleepGuardTurnOffBluetooth },
                        set: { batteryManager.sleepGuardTurnOffBluetooth = $0 }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
                }

                HStack(spacing: 8) {
                    Image(systemName: "lock.shield").font(.system(size: FS.label)).foregroundStyle(.secondary).frame(width: 16)
                    Text(tr("Khóa SMC 80% được bảo lưu liên tục trong lúc ngủ và tái kích hoạt ngay khi mở màn hình.", "SMC 80% limit is preserved during sleep and reapplied on wake."))
                        .font(.system(size: FS.caption)).foregroundStyle(.secondary)
                }

                if !batteryManager.lastSleepReport.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "chart.line.uptrend.xyaxis").font(.system(size: FS.label)).foregroundStyle(.secondary).frame(width: 16)
                        Text(tr("Lần gần nhất: \(batteryManager.lastSleepReport)", "Last report: \(batteryManager.lastSleepReport)"))
                            .font(.system(size: FS.caption)).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // SUB-TAB 2: PROCESS FREEZE
    private var processFreezeSubTab: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(tr("Tiến trình ngốn CPU & Tỏa nhiệt:", "Heavy CPU & Heat Generating Processes:"))
                    .font(.system(size: FS.caption, weight: .semibold))
                Spacer()
                Button {
                    energyManager.refreshProcesses()
                } label: {
                    HStack(spacing: 2.5) {
                        Image(systemName: "arrow.clockwise").font(.system(size: FS.caption))
                        Text(tr("Quét lại", "Refresh")).font(.system(size: FS.caption))
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.06))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }

            if energyManager.processes.isEmpty {
                HStack {
                    Spacer()
                    Text(tr("Máy đang rất mát mẻ, không có tiến trình nền nặng.", "System is running cool, no heavy background processes."))
                        .font(.system(size: FS.caption)).foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.vertical, 4)
            } else {
                VStack(spacing: 3.5) {
                    ForEach(energyManager.processes) { p in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(p.isFrozen ? Color.accentColor : (p.cpu > 25.0 ? Color.red : Color.orange))
                                .frame(width: 5, height: 5)

                            VStack(alignment: .leading, spacing: 0.5) {
                                Text(p.name)
                                    .font(.system(size: FS.caption, weight: .semibold))
                                    .lineLimit(1)
                                Text("PID: \(p.pid)")
                                    .font(.system(size: FS.caption)).foregroundStyle(.tertiary)
                            }

                            Spacer()

                            if p.isFrozen {
                                Text("❄️ " + tr("ĐÃ ĐÓNG BĂNG", "FROZEN"))
                                    .font(.system(size: FS.caption, weight: .semibold))
                                    .foregroundStyle(Color.accentColor)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1.5)
                                    .background(Capsule().fill(Color.accentColor.opacity(0.12)))
                            } else {
                                Text(String(format: "%.1f%% CPU", p.cpu))
                                    .font(.system(size: FS.caption, weight: .semibold))
                                    .foregroundStyle(p.cpu > 25.0 ? Color.red : Color.orange)
                            }

                            Button {
                                if p.isFrozen {
                                    energyManager.resumeProcess(pid: p.pid)
                                } else {
                                    energyManager.freezeProcess(pid: p.pid)
                                }
                            } label: {
                                Text(p.isFrozen ? ("▶️ " + tr("Rã đông", "Resume")) : ("❄️ " + tr("Đóng băng", "Freeze")))
                                    .font(.system(size: FS.caption, weight: .semibold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(p.isFrozen ? Tone.good.opacity(0.10) : Color.accentColor.opacity(0.10))
                                    .foregroundStyle(p.isFrozen ? Tone.good : Color.accentColor)
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2.5)
                        .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.primary.opacity(0.03)))
                    }
                }
            }

            Text(tr("Đóng băng (SIGSTOP) giữ nguyên cửa sổ và dữ liệu trong RAM nhưng ngừng 100% việc đốt CPU và tỏa nhiệt trên M2.", "Freezing (SIGSTOP) keeps windows & data in RAM while completely halting CPU burn & heat."))
                .font(.system(size: FS.caption)).foregroundStyle(.secondary)
        }
    }

    // SUB-TAB 3: AUTO-SCHEDULED BATTERY CALIBRATION (BMS)
    private var autoScheduledCalibrationSubTab: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Master Auto-Schedule Toggle
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: FS.body))
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 1) {
                    Text(tr("Tự động đặt lịch hiệu chuẩn pin định kỳ", "Auto-schedule Periodic Battery Calibration"))
                        .font(.system(size: FS.label, weight: .semibold))
                    Text(tr("Cân bằng điện áp cell & khôi phục thước đo dung lượng chuẩn", "Balances cell voltage & recalibrates gauge"))
                        .font(.system(size: FS.caption))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: Binding<Bool>(
                    get: { batteryManager.isAutoCalibrationEnabled },
                    set: { batteryManager.isAutoCalibrationEnabled = $0 }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
            }

            if batteryManager.isAutoCalibrationEnabled {
                // Interval Selector Pills
                HStack(spacing: 5) {
                    Text(tr("Chu kỳ:", "Interval:"))
                        .font(.system(size: FS.caption, weight: .medium))
                        .foregroundStyle(.secondary)

                    ForEach([30, 45, 60], id: \.self) { days in
                        Button {
                            batteryManager.calibrationIntervalDays = days
                        } label: {
                            Text(tr("\(days) ngày", "\(days) days") + (days == 30 ? " ★" : ""))
                                .font(.system(size: FS.caption, weight: batteryManager.calibrationIntervalDays == days ? .semibold : .medium))
                                .lineLimit(1)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(batteryManager.calibrationIntervalDays == days ? Color.accentColor : Color.primary.opacity(0.06))
                                .foregroundStyle(batteryManager.calibrationIntervalDays == days ? Color.white : Color.primary)
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                }

                // Schedule Info Box
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath").font(.system(size: FS.caption)).foregroundStyle(.secondary)
                        Text(tr("Lịch tiếp theo:", "Next date:"))
                            .font(.system(size: FS.caption, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(formatDate(batteryManager.nextScheduledCalibrationDate))
                            .font(.system(size: FS.caption, weight: .semibold))
                            .foregroundStyle(.primary)

                        Spacer()

                        Text(tr("Còn \(batteryManager.daysRemainingUntilCalibration) ngày", "\(batteryManager.daysRemainingUntilCalibration) days left"))
                            .font(.system(size: FS.caption, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.primary.opacity(0.07)))
                    }

                    HStack {
                        Image(systemName: "checkmark.circle").font(.system(size: FS.caption)).foregroundStyle(.secondary)
                        Text(tr("Lần gần nhất:", "Last completed:"))
                            .font(.system(size: FS.caption, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(batteryManager.lastCalibrationDate != nil ? formatDate(batteryManager.lastCalibrationDate!) : tr("Chưa thực hiện", "Never performed"))
                            .font(.system(size: FS.caption))
                            .foregroundStyle(.secondary)
                    }

                    Text(tr("Quy trình: Khi đến lịch, bạn rút sạc dùng máy tự nhiên xuống ≤ 20%. Khi cắm sạc lại, HyperMac sẽ tự động sạc 100% cân bằng cell ➔ ngâm 15p ➔ tự khóa lại 80% SMC Bypass.", "Procedure: When due, unplug & use normally down to ≤ 20%. Once plugged back in, HyperMac charges to 100% to balance cells ➔ soaks for 15m ➔ re-locks to 80% SMC Bypass."))
                        .font(.system(size: FS.caption))
                        .foregroundStyle(.secondary)
                        .padding(.top, 1)
                }
                .padding(6)
                .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.primary.opacity(0.03)))
            }

            // Action: Manual Run or Active Status
            if batteryManager.calibrationState == .idle {
                Button {
                    batteryManager.startCalibration()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "play.circle.fill").font(.system(size: FS.caption))
                        Text(tr("Hiệu chuẩn ngay bây giờ (Chạy trước lịch)", "Calibrate now (Run ahead of schedule)"))
                            .font(.system(size: FS.caption, weight: .semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity)
                    .background(Color.accentColor.opacity(0.12))
                    .foregroundStyle(Color.accentColor)
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 4) {
                    HStack {
                        ProgressView().controlSize(.mini)
                        Text(batteryManager.calibrationMessage)
                            .font(.system(size: FS.caption, weight: .semibold))
                            .foregroundStyle(.orange)
                        Spacer()
                    }
                    .padding(5)
                    .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.orange.opacity(0.1)))

                    Button {
                        batteryManager.cancelCalibration()
                    } label: {
                        Text(tr("Hủy hiệu chuẩn (Quay về khóa 80%)", "Cancel calibration (Revert to 80% lock)"))
                            .font(.system(size: FS.caption, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .frame(maxWidth: .infinity)
                            .background(Color.primary.opacity(0.06))
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func toggleRow(icon: String, iconColor: Color, title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: FS.label))
                .foregroundStyle(iconColor)
                .frame(width: 16)
            Text(title)
                .font(.system(size: FS.label))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
        }
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yyyy"
        return f.string(from: date)
    }

    private var tempBadgeColor: Color {
        if batteryManager.temperature < 32.0 {
            return Tone.good
        } else if batteryManager.temperature < 38.0 {
            return .orange
        } else {
            return .red
        }
    }

    private var tempStatusText: String {
        if batteryManager.temperature < 32.0 {
            return tr("Mát mẻ", "Cool")
        } else if batteryManager.temperature < 38.0 {
            return tr("Ấm nhẹ", "Warm")
        } else {
            return tr("Nóng!", "Hot!")
        }
    }
}
