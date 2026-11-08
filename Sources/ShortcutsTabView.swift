import SwiftUI
import AppKit

// MARK: - TAB 2: Shortcuts & Window Controls View

struct ShortcutsTabView: View {
    @ObservedObject var displayManager: DisplayManager
    @ObservedObject var snapManager: WindowSnapManager
    @ObservedObject var windowManager: WindowManager
    @ObservedObject var clipboardManager: ClipboardManager
    @ObservedObject var caffeinateManager: CaffeinateManager = CaffeinateManager.shared
    @ObservedObject var launchAtLoginManager: LaunchAtLoginManager = LaunchAtLoginManager.shared
    @ObservedObject var finderCutPasteManager: FinderCutPasteManager = FinderCutPasteManager.shared
    @ObservedObject var screenshotManager: ScreenshotManager = ScreenshotManager.shared

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 10) {
                // Accessibility Alert if not granted
                if !displayManager.hasAccessibility {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: FS.subhead))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(tr("Cần cấp quyền Trợ năng (Accessibility)", "Accessibility Permission Required"))
                                .font(.system(size: FS.label, weight: .semibold))
                            Text(tr("Bật HyperMac trong Cài đặt hệ thống để phím tắt hoạt động.", "Enable HyperMac in System Settings to allow shortcut interception."))
                                .font(.system(size: FS.caption))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button(tr("Cấp quyền", "Grant")) {
                            displayManager.requestAccessibility()
                        }
                        .font(.system(size: FS.caption, weight: .semibold))
                        .controlSize(.mini)
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.orange.opacity(0.12)))
                }

                // Launch at Login Card
                HStack(spacing: 8) {
                    Image(systemName: "power.circle.fill")
                        .font(.system(size: FS.title))
                        .foregroundStyle(Color.accentColor)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(tr("Khởi động cùng macOS", "Launch at Login"))
                            .font(.system(size: FS.label, weight: .semibold))
                        Text(tr("Tự động chạy HyperMac ngay khi đăng nhập vào máy Mac", "Automatically start HyperMac upon logging in"))
                            .font(.system(size: FS.caption))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: Binding<Bool>(
                        get: { launchAtLoginManager.isEnabled },
                        set: { launchAtLoginManager.setEnabled($0) }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
                }
                .padding(10)
                .cardBackground()

                // Caffeinate (Anti-Sleep) Control Card
                CaffeinateCardView(caffeinateManager: caffeinateManager)

                // Menu Bar Hider (Gom gọn thanh Status Bar) Card
                MenuBarHiderCardView()

                // Finder Cut & Paste (Windows-style ⌘X ➔ ⌘V) Card
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "scissors")
                            .font(.system(size: FS.body, weight: .semibold))
                            .foregroundStyle(Color.accentColor)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(tr("Cắt & Dán tệp trong Finder (⌘X ➔ ⌘V)", "Finder Cut & Paste (⌘X ➔ ⌘V)"))
                                .font(.system(size: FS.label, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                            Text(tr("Cắt và di chuyển tệp như trên Windows (bấm ⌘X để cắt, ⌘V để di chuyển)", "Cut & move files Windows-style (press ⌘X to cut, ⌘V to move)"))
                                .font(.system(size: FS.caption))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if finderCutPasteManager.isEnabled {
                            Button {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    finderCutPasteManager.isDetailsExpanded.toggle()
                                }
                            } label: {
                                Image(systemName: finderCutPasteManager.isDetailsExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: FS.caption, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20, height: 20)
                                    .background(Circle().fill(Color.primary.opacity(finderCutPasteManager.isDetailsExpanded ? 0.08 : 0.04)))
                            }
                            .buttonStyle(.plain)
                            .help(finderCutPasteManager.isDetailsExpanded ? tr("Thu gọn chi tiết", "Collapse details") : tr("Xem chi tiết phím tắt", "View shortcut details"))
                        }

                        Toggle("", isOn: Binding<Bool>(
                            get: { finderCutPasteManager.isEnabled },
                            set: { finderCutPasteManager.isEnabled = $0 }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .labelsHidden()
                    }

                    if finderCutPasteManager.isEnabled && finderCutPasteManager.isDetailsExpanded {
                        Divider().opacity(0.35)

                        VStack(spacing: 5) {
                            ShortcutGrid {
                                shortcutPill(key: "⌘ + X", desc: tr("Cắt tệp / thư mục", "Cut file / folder"))
                                shortcutPill(key: "⌘ + V", desc: tr("Di chuyển đến đây", "Move here"))
                                shortcutPill(key: "esc", desc: tr("Huỷ cắt", "Cancel cut"))
                                shortcutPill(key: "⌘ + C", desc: tr("Chuyển sang Copy", "Switch to Copy"))
                            }

                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: FS.caption))
                                    .foregroundStyle(.secondary)
                                Text(tr("Tự động nhận diện khi đổi tên hoặc tìm kiếm: vẫn cắt văn bản bình thường.", "Smart context: text cutting remains untouched while renaming or searching."))
                                    .font(.system(size: FS.caption))
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.top, 2)
                        }
                    }
                }
                .padding(10)
                .cardBackground()

                // AltTab Card
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "macwindow.on.rectangle")
                            .font(.system(size: FS.body))
                            .foregroundStyle(Color.accentColor)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(tr("Chuyển cửa sổ (⌘ Tab)", "Window Switcher (⌘ Tab)"))
                                .font(.system(size: FS.label, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                            Text(tr("Thay thế AltTab với live preview độc lập & chuẩn MRU", "AltTab replacement with live preview & MRU order"))
                                .font(.system(size: FS.caption))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if windowManager.isAltTabEnabled {
                            Button {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    windowManager.isDetailsExpanded.toggle()
                                }
                            } label: {
                                Image(systemName: windowManager.isDetailsExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: FS.caption, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20, height: 20)
                                    .background(Circle().fill(Color.primary.opacity(windowManager.isDetailsExpanded ? 0.08 : 0.04)))
                            }
                            .buttonStyle(.plain)
                            .help(windowManager.isDetailsExpanded ? tr("Thu gọn chi tiết", "Collapse details") : tr("Xem chi tiết phím tắt", "View shortcut details"))
                        }

                        Toggle("", isOn: Binding<Bool>(
                            get: { windowManager.isAltTabEnabled },
                            set: { windowManager.isAltTabEnabled = $0 }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .labelsHidden()
                    }

                    if windowManager.isAltTabEnabled && windowManager.isDetailsExpanded {
                        Divider().opacity(0.35)

                        // Multi-monitor screen isolation toggle
                        HStack(spacing: 6) {
                            Image(systemName: "display.2")
                                .font(.system(size: FS.caption))
                                .foregroundStyle(.secondary)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(tr("Chỉ hiện cửa sổ trên màn hình hiện tại", "Only show windows on current display"))
                                    .font(.system(size: FS.caption, weight: .semibold))
                                Text(tr("Lọc riêng các cửa sổ thuộc màn hình con trỏ chuột đang đứng", "Filter windows belonging to the display where cursor is located"))
                                    .font(.system(size: FS.caption))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Toggle("", isOn: Binding<Bool>(
                                get: { windowManager.showOnlyCurrentScreenWindows },
                                set: { windowManager.showOnlyCurrentScreenWindows = $0 }
                            ))
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .labelsHidden()
                        }
                        .padding(.vertical, 2)

                        // AltTab Shortcuts Guide
                        ShortcutGrid {
                            shortcutPill(key: "⌘ + Tab", desc: tr("Chuyển tiếp", "Forward"))
                            shortcutPill(key: "⌘ + ~", desc: tr("Lùi lại", "Backward"))
                            shortcutPill(key: "↑↓←→", desc: tr("Duyệt lưới", "Grid nav"))
                            shortcutPill(key: "W", desc: tr("Đóng", "Close"))
                            shortcutPill(key: "Q", desc: tr("Thoát App", "Quit App"))
                        }

                        if !windowManager.hasScreenRecording {
                            HStack(spacing: 6) {
                                Image(systemName: "camera.viewfinder")
                                    .font(.system(size: FS.caption))
                                    .foregroundStyle(.secondary)
                                Text(tr("Cần quyền Ghi màn hình để hiện ảnh chụp cửa sổ thực tế.", "Screen Recording permission needed for actual window snapshots."))
                                    .font(.system(size: FS.caption))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button(tr("Cấp quyền", "Grant")) {
                                    windowManager.requestScreenRecordingPermission()
                                }
                                .font(.system(size: FS.caption, weight: .semibold))
                                .controlSize(.mini)
                            }
                            .padding(5)
                            .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.accentColor.opacity(0.08)))
                        }
                    }
                }
                .padding(10)
                .cardBackground()

                // Window Snapping (Rectangle) Card
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.split.2x1")
                            .font(.system(size: FS.body))
                            .foregroundStyle(Color.accentColor)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(tr("Chia cửa sổ", "Window Snapping"))
                                .font(.system(size: FS.label, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                            Text(tr("Bố trí cửa sổ nhanh với độ trễ 0ms", "Instant window positioning with 0ms latency"))
                                .font(.system(size: FS.caption))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if snapManager.isSnapEnabled {
                            Button {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    snapManager.isDetailsExpanded.toggle()
                                }
                            } label: {
                                Image(systemName: snapManager.isDetailsExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: FS.caption, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20, height: 20)
                                    .background(Circle().fill(Color.primary.opacity(snapManager.isDetailsExpanded ? 0.08 : 0.04)))
                            }
                            .buttonStyle(.plain)
                            .help(snapManager.isDetailsExpanded ? tr("Thu gọn chi tiết", "Collapse details") : tr("Xem chi tiết phím tắt", "View shortcut details"))
                        }

                        Toggle("", isOn: Binding<Bool>(
                            get: { snapManager.isSnapEnabled },
                            set: { snapManager.isSnapEnabled = $0 }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .labelsHidden()
                    }

                    if snapManager.isSnapEnabled && snapManager.isDetailsExpanded {
                        Divider().opacity(0.35)

                        VStack(spacing: 5) {
                            ShortcutGrid {
                                shortcutPill(key: "⌃⌥←", desc: tr("Nửa trái", "Left Half"))
                                shortcutPill(key: "⌃⌥→", desc: tr("Nửa phải", "Right Half"))
                                shortcutPill(key: "⌃⌥↑", desc: tr("Nửa trên", "Top Half"))
                                shortcutPill(key: "⌃⌥↓", desc: tr("Nửa dưới", "Bottom Half"))
                            }
                            ShortcutGrid {
                                shortcutPill(key: "⌃⌥↩", desc: tr("Toàn màn hình", "Maximize"))
                                shortcutPill(key: "⌃⌥C / ⌃⌥⌫", desc: tr("Căn giữa", "Center"))
                                shortcutPill(key: "⌃⌥←↑/U", desc: tr("4 góc", "Quarters"))
                            }
                            ShortcutGrid {
                                shortcutPill(key: "⌥⌘→", desc: tr("Sang màn hình phải", "Next Display"))
                                shortcutPill(key: "⌥⌘←", desc: tr("Sang màn hình trái", "Previous Display"))
                            }
                        }
                    }
                }
                .padding(10)
                .cardBackground()

                // Clipboard Manager (Maccy Replacement) Card
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.on.clipboard.fill")
                            .font(.system(size: FS.body))
                            .foregroundStyle(Color.accentColor)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(tr("Lịch sử Clipboard", "Clipboard History"))
                                .font(.system(size: FS.label, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                            Text(tr("Lịch sử sao chép thông minh, tìm kiếm & dán tức thì", "Smart clipboard history, search & instant paste"))
                                .font(.system(size: FS.caption))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if clipboardManager.isMonitoringEnabled {
                            Button {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    clipboardManager.isDetailsExpanded.toggle()
                                }
                            } label: {
                                Image(systemName: clipboardManager.isDetailsExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: FS.caption, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20, height: 20)
                                    .background(Circle().fill(Color.primary.opacity(clipboardManager.isDetailsExpanded ? 0.08 : 0.04)))
                            }
                            .buttonStyle(.plain)
                            .help(clipboardManager.isDetailsExpanded ? tr("Thu gọn chi tiết", "Collapse details") : tr("Xem chi tiết cài đặt", "View settings details"))
                        }

                        Toggle("", isOn: Binding<Bool>(
                            get: { clipboardManager.isMonitoringEnabled },
                            set: { clipboardManager.isMonitoringEnabled = $0 }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .labelsHidden()
                    }

                    if clipboardManager.isMonitoringEnabled && clipboardManager.isDetailsExpanded {
                        Divider().opacity(0.35)

                        // Shortcuts & Quick Actions
                        ShortcutGrid {
                            shortcutPill(key: clipboardManager.hudShortcut.displayShort, desc: tr("Mở bảng HUD", "Open HUD"))
                            shortcutPill(key: "1..9", desc: tr("Dán tức thì", "Instant Paste"))
                            shortcutPill(key: "⌥P", desc: tr("Ghim", "Pin"))
                            shortcutPill(key: "⌥⌫", desc: tr("Xóa", "Delete"))
                        }

                        // Storage limit + automatic cleanup + HUD shortcut options
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 4) {
                                Text(tr("Phím mở:", "Open key:"))
                                    .font(.system(size: FS.caption))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 80, alignment: .leading)

                                optionChip("⌘⇧C", selected: clipboardManager.hudShortcut == .cmdShiftC) {
                                    clipboardManager.hudShortcut = .cmdShiftC
                                }
                                optionChip("⌘⇧V", selected: clipboardManager.hudShortcut == .cmdShiftV) {
                                    clipboardManager.hudShortcut = .cmdShiftV
                                }

                                Spacer()
                            }

                            HStack(spacing: 4) {
                                Text(tr("Giới hạn:", "Max items:"))
                                    .font(.system(size: FS.caption))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 80, alignment: .leading)

                                ForEach([50, 100, 200, 500], id: \.self) { count in
                                    optionChip("\(count)", selected: clipboardManager.maxItemsCount == count) {
                                        clipboardManager.maxItemsCount = count
                                    }
                                }
                                optionChip("∞", selected: clipboardManager.hasUnlimitedHistory) {
                                    clipboardManager.maxItemsCount = 0
                                }

                                Spacer()

                                Text("\(clipboardManager.items.count) " + tr("mục lưu", "items stored"))
                                    .font(.system(size: FS.caption))
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 4) {
                                Text(tr("Tự động xoá:", "Auto cleanup:"))
                                    .font(.system(size: FS.caption))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 80, alignment: .leading)

                                ForEach([0, 7, 30, 90], id: \.self) { days in
                                    optionChip(days == 0 ? tr("Không", "Never") : "\(days) " + tr("ngày", "days"),
                                               selected: clipboardManager.autoCleanupDays == days) {
                                        clipboardManager.autoCleanupDays = days
                                    }
                                }

                            }

                            HStack(spacing: 8) {
                                Button {
                                    clipboardManager.cleanupNow()
                                } label: {
                                    Text(tr("Dọn ngay", "Clean now"))
                                        .font(.system(size: FS.caption, weight: .medium))
                                        .lineLimit(1)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 4)
                                        .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.primary.opacity(0.06)))
                                        .foregroundStyle(Color.primary)
                                }
                                .buttonStyle(.plain)
                                .help(tr("Xoá mục chưa ghim cũ hơn \(clipboardManager.autoCleanupDays > 0 ? "\(clipboardManager.autoCleanupDays) ngày" : "30 ngày")", "Delete unpinned items older than \(clipboardManager.autoCleanupDays > 0 ? "\(clipboardManager.autoCleanupDays) days" : "30 days")"))

                                Button {
                                    clipboardManager.requestClearAllUnpinned()
                                } label: {
                                    Text(clipboardManager.pendingClearAllConfirm ? tr("Chắc chắn?", "Confirm?") : tr("Xoá tất cả", "Clear all"))
                                        .font(.system(size: FS.caption, weight: .medium))
                                        .lineLimit(1)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 4)
                                        .background(RoundedRectangle(cornerRadius: Rad.sm).fill(clipboardManager.pendingClearAllConfirm ? Color.red.opacity(0.14) : Color.primary.opacity(0.06)))
                                        .foregroundStyle(Tone.bad)
                                }
                                .buttonStyle(.plain)
                                .help(tr("Xoá mọi mục chưa ghim (bấm 2 lần để xác nhận)", "Delete all unpinned items (click twice to confirm)"))
                            }

                            if let message = clipboardManager.cleanupMessage {
                                Text(message)
                                    .font(.system(size: FS.caption, weight: .medium))
                                    .foregroundStyle(Color.orange.opacity(0.95))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .transition(.opacity)
                            }

                            if clipboardManager.hasUnlimitedHistory {
                                Text(clipboardManager.autoCleanupDays == 0
                                     ? tr("Không giới hạn số mục: nên bật tự động xoá để tránh phình bộ nhớ.", "Unlimited items: recommended to enable auto-cleanup to save memory.")
                                     : tr("Không giới hạn số mục • tự động xoá sau \(clipboardManager.autoCleanupDays) ngày.", "Unlimited items • auto-cleans after \(clipboardManager.autoCleanupDays) days."))
                                    .font(.system(size: FS.caption))
                                    .foregroundStyle(Color.orange.opacity(0.9))
                            }
                        }

                        // Ignore passwords toggle
                        HStack(spacing: 6) {
                            Image(systemName: "lock.shield")
                                .font(.system(size: FS.caption))
                                .foregroundStyle(.secondary)
                            Text(tr("Tự động bỏ qua mật khẩu (1Password, Bitwarden, Keychain)", "Auto-ignore passwords (1Password, Bitwarden, Keychain)"))
                                .font(.system(size: FS.caption))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Toggle("", isOn: Binding<Bool>(
                                get: { clipboardManager.ignoreConcealedTypes },
                                set: { clipboardManager.ignoreConcealedTypes = $0 }
                            ))
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .labelsHidden()
                        }

                        // Open HUD Button
                        Button {
                            clipboardManager.toggleHUD()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "macwindow")
                                    .font(.system(size: FS.caption))
                                Text(tr("Mở bảng Clipboard HUD (\(clipboardManager.hudShortcut.displayTitle))", "Open Clipboard HUD (\(clipboardManager.hudShortcut.displayTitle))"))
                                    .font(.system(size: FS.caption, weight: .semibold))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.primary.opacity(0.06)))
                            .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
                .cardBackground()

                // Screenshot (LightShot / ⌘⇧1) Card
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: FS.body))
                            .foregroundStyle(Color.accentColor)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(tr("Chụp ảnh màn hình (⌘⇧1)", "Screenshot Snipping (⌘⇧1)"))
                                .font(.system(size: FS.label, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                            Text(tr("Kéo chọn vùng, vẽ bút đỏ chú thích, ⌘C sao chép, ⌘S lưu tệp", "LightShot-style: crop area, red pen annotations, ⌘C copy, ⌘S save"))
                                .font(.system(size: FS.caption))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if screenshotManager.isScreenshotEnabled {
                            Button {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    screenshotManager.isDetailsExpanded.toggle()
                                }
                            } label: {
                                Image(systemName: screenshotManager.isDetailsExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: FS.caption, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20, height: 20)
                                    .background(Circle().fill(Color.primary.opacity(screenshotManager.isDetailsExpanded ? 0.08 : 0.04)))
                            }
                            .buttonStyle(.plain)
                            .help(screenshotManager.isDetailsExpanded ? tr("Thu gọn chi tiết", "Collapse details") : tr("Xem chi tiết cài đặt", "View settings details"))
                        }

                        Toggle("", isOn: Binding<Bool>(
                            get: { screenshotManager.isScreenshotEnabled },
                            set: { screenshotManager.isScreenshotEnabled = $0 }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .labelsHidden()
                    }

                    if screenshotManager.isScreenshotEnabled && screenshotManager.isDetailsExpanded {
                        Divider().opacity(0.35)

                        // Shortcuts & Quick Actions Grid
                        ShortcutGrid {
                            shortcutPill(key: "⌘⇧1", desc: tr("Mở chụp ảnh", "Start Snipping"))
                            shortcutPill(key: "⌘C", desc: tr("Sao chép ảnh", "Copy Image"))
                            shortcutPill(key: "⌘S", desc: tr("Lưu ảnh PNG", "Save PNG"))
                            shortcutPill(key: "⎋", desc: tr("Huỷ bỏ", "Cancel"))
                        }

                        // Capture Now Button
                        Button {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                screenshotManager.startCapture()
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: FS.caption))
                                Text(tr("Chụp màn hình ngay (⌘⇧1)", "Capture Screenshot Now (⌘⇧1)"))
                                    .font(.system(size: FS.caption, weight: .semibold))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.primary.opacity(0.06)))
                            .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
                .cardBackground()

                // Mouse Chording Card
                HStack(spacing: 8) {
                    Image(systemName: "cursorarrow.click.2")
                        .font(.system(size: FS.body))
                        .foregroundStyle(Color.accentColor)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(tr("Bấm đồng thời Chuột Trái + Phải mở F3", "Left + Right click opens Mission Control (F3)"))
                            .font(.system(size: FS.label, weight: .semibold))
                        Text(tr("Mở Mission Control ngay trên chuột mà không cần chạm bàn phím", "Trigger Mission Control directly from mouse without keyboard"))
                            .font(.system(size: FS.caption))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: Binding<Bool>(
                        get: { displayManager.isMouseChordEnabled },
                        set: {
                            displayManager.isMouseChordEnabled = $0
                            UserDefaults.standard.set($0, forKey: "mouse_chord_enabled")
                        }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
                }
                .padding(10)
                .cardBackground()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private func optionChip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: FS.caption, weight: selected ? .semibold : .medium))
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(selected ? Color.accentColor : Color.primary.opacity(0.06)))
                .foregroundStyle(selected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }

    private func shortcutPill(key: String, desc: String) -> some View {
        HStack(spacing: 6) {
            Text(desc)
                .font(.system(size: FS.caption))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 4)
            Text(key)
                .font(.system(size: FS.caption, weight: .medium, design: .monospaced))
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.primary.opacity(0.07)))
        }
        .frame(maxWidth: .infinity)
    }
}

