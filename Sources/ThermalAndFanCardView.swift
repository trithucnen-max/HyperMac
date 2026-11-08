import SwiftUI
import AppKit

// MARK: - Thermal & Fan Control View (Macs Fan Control + Apple Silicon Thermal Suite)

/* Hallmark · pre-emit critique: P5 H5 E5 S5 R5 V5 */
struct ThermalAndFanCardView: View {
    @ObservedObject var thermalManager: ThermalManager

    var body: some View {
        VStack(spacing: 8) {
            // 1. Device Profile & Thermal Health Header
            deviceHeaderCard

            // 1b. Fan control (hidden on fanless Macs)
            FanControlCardView(fan: FanManager.shared)

            // 2. Optional Menu Bar temperature pill
            menuBarMonitorRow

            // 3. Apple Silicon 6-Sensor Telemetry Matrix
            thermalMatrixGrid

            // 4. Detailed Sensor Breakdown (Expandable Accordion)
            detailedSensorsAccordion
        }
    }

    // MARK: - 1. Device Header Card
    private var deviceHeaderCard: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(headerIconBackground)
                        .frame(width: 32, height: 32)

                    Image(systemName: "thermometer.medium")
                        .font(.system(size: FS.subhead, weight: .semibold))
                        .foregroundStyle(headerIconColor)
                }

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(thermalManager.machineModelName)
                            .font(.system(size: FS.body, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text("HID PMU")
                            .font(.system(size: FS.caption, weight: .semibold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.primary.opacity(0.08)))
                            .foregroundStyle(.secondary)
                    }

                    Text(tr("Cảm biến nhiệt Apple Silicon • Cập nhật mỗi 2.5s", "Apple Silicon Thermal Sensors • Updates every 2.5s"))
                        .font(.system(size: FS.caption))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Thermal State Pill
                HStack(spacing: 3) {
                    Circle()
                        .fill(stateColor)
                        .frame(width: 5, height: 5)
                    Text(localizedThermalStateDescription)
                        .font(.system(size: FS.caption, weight: .semibold))
                        .foregroundStyle(stateColor)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Capsule().fill(stateColor.opacity(0.12)))

                // Refresh Button
                Button {
                    thermalManager.isRefreshing = true
                    thermalManager.refreshMetrics()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        thermalManager.isRefreshing = false
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: FS.caption, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(thermalManager.isRefreshing ? 360 : 0))
                        .animation(thermalManager.isRefreshing ? .linear(duration: 0.4) : .default, value: thermalManager.isRefreshing)
                        .padding(5)
                        .background(Circle().fill(Color.primary.opacity(0.05)))
                }
                .buttonStyle(.plain)
                .help(tr("Làm mới cảm biến nhiệt ngay lập tức", "Refresh thermal sensors immediately"))
            }
        }
        .padding(8)
        .cardBackground()
    }

    // MARK: - 2. Menu Bar Monitor (temperature only)

    private var menuBarMonitorRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "menubar.dock.rectangle")
                .font(.system(size: FS.caption))
                .foregroundStyle(Color.accentColor)

            Text(tr("Hiện nhiệt độ trên Menu Bar", "Show temperature on Menu Bar"))
                .font(.system(size: FS.caption))
                .foregroundStyle(.secondary)

            Spacer()

            if thermalManager.showMenuBarMetrics {
                Text("\(Int(thermalManager.cpuAvgTemp))°C")
                    .font(.system(size: FS.caption, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.accentColor)
            }

            Toggle("", isOn: Binding<Bool>(
                get: { thermalManager.showMenuBarMetrics },
                set: { thermalManager.showMenuBarMetrics = $0 }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()
        }
        .padding(8)
        .cardBackground()
    }

    // MARK: - 3. Apple Silicon Thermal Matrix (6 Core Metrics)
    private var thermalMatrixGrid: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(tr("Bản đồ nhiệt Apple Silicon (HID PMU)", "Apple Silicon Thermal Matrix (HID PMU)"), systemImage: "cpu")
                    .font(.system(size: FS.caption, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Text(tr("Thời gian thực: 2.5s", "Real-time: 2.5s"))
                    .font(.system(size: FS.caption))
                    .foregroundStyle(.tertiary)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 5), GridItem(.flexible(), spacing: 5)], spacing: 5) {
                sensorTile(
                    title: tr("CPU Trung bình", "CPU Average"),
                    temp: thermalManager.cpuAvgTemp,
                    icon: "cpu",
                    sub: tr("Tất cả các nhân", "All Cores Average")
                )
                sensorTile(
                    title: tr("CPU Nóng nhất", "CPU Peak"),
                    temp: thermalManager.cpuPeakTemp,
                    icon: "flame.fill",
                    sub: "Core Peak Hotspot"
                )
                sensorTile(
                    title: tr("GPU Đồ họa", "GPU Core"),
                    temp: thermalManager.gpuAvgTemp,
                    icon: "gamecontroller.fill",
                    sub: tr("Cụm nhân GPU", "GPU Cluster")
                )
                sensorTile(
                    title: tr("Pin Cell", "Battery Pack"),
                    temp: thermalManager.batteryTemp,
                    icon: "battery.100.bolt",
                    sub: "Gas Gauge Pack"
                )
                sensorTile(
                    title: tr("Ổ cứng SSD", "SSD Storage"),
                    temp: thermalManager.ssdTemp,
                    icon: "internaldrive.fill",
                    sub: "NAND Flash Storage"
                )
                sensorTile(
                    title: tr("Hotspot Bo mạch", "Motherboard Hotspot"),
                    temp: thermalManager.hotspotTemp,
                    icon: "thermometer.sun.fill",
                    sub: "PMU Calibration"
                )
            }
        }
        .padding(8)
        .cardBackground()
    }

    private func sensorTile(title: String, temp: Double, icon: String, sub: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: FS.body))
                .foregroundStyle(tempColor(temp))
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: FS.caption, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(temp > 0 ? String(format: "%.1f°C", temp) : "—")
                    .font(.system(size: FS.body, weight: .semibold, design: .rounded))
                    .foregroundStyle(tempColor(temp))

                Text(sub)
                    .font(.system(size: FS.caption))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4.5)
        .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.primary.opacity(0.03)))
    }

    // MARK: - 4. Detailed Sensor Breakdown Accordion
    private var detailedSensorsAccordion: some View {
        VStack(spacing: 4) {
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    thermalManager.isDetailExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: FS.caption))
                        .foregroundStyle(Color.accentColor)

                    Text(tr("Chi tiết \(thermalManager.detailedSensors.count) cảm biến PMU trên chip", "Detailed \(thermalManager.detailedSensors.count) on-chip PMU sensors"))
                        .font(.system(size: FS.caption, weight: .semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: thermalManager.isDetailExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: FS.caption, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 4.5)
                .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.primary.opacity(0.04)))
            }
            .buttonStyle(.plain)

            if thermalManager.isDetailExpanded {
                VStack(spacing: 3) {
                    ForEach(thermalManager.detailedSensors) { s in
                        HStack {
                            Text(s.displayName)
                                .font(.system(size: FS.caption, weight: .medium))
                                .foregroundStyle(.primary)
                            Text("(\(s.name))")
                                .font(.system(size: FS.caption))
                                .foregroundStyle(.tertiary)
                            Spacer()
                            Text(String(format: "%.1f°C", s.temp))
                                .font(.system(size: FS.caption, weight: .semibold, design: .rounded))
                                .foregroundStyle(tempColor(s.temp))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                    }
                }
                .padding(4)
                .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.primary.opacity(0.02)))
            }
        }
    }

    private func tempColor(_ temp: Double) -> Color {
        guard temp > 0 else { return .secondary }
        if temp < 55.0 {
            return Tone.good
        } else if temp < 75.0 {
            return .orange
        } else {
            return .red
        }
    }

    private var stateColor: Color {
        if thermalManager.isThrottling {
            return .red
        }
        let peak = thermalManager.cpuPeakTemp
        if peak < 60.0 {
            return Tone.good
        } else if peak < 80.0 {
            return .orange
        } else {
            return .red
        }
    }

    private var localizedThermalStateDescription: String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return tr("Mát mẻ (Bình thường)", "Nominal (Cool)")
        case .fair: return tr("Ấm nhẹ (Tải vừa)", "Fair (Moderate)")
        case .serious: return tr("Nóng (Đang giảm xung)", "Serious (Throttling)")
        case .critical: return tr("Rất nóng (Throttling tối đa!)", "Critical (Heavy Throttling!)")
        @unknown default: return tr("Bình thường", "Normal")
        }
    }

    private var headerIconColor: Color {
        Color.accentColor
    }

    private var headerIconBackground: Color {
        Color.accentColor.opacity(0.12)
    }
}

