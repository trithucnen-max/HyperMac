import SwiftUI
import AppKit

// MARK: - In-App Update Modal View

struct UpdateModalView: View {
    @ObservedObject var updateManager: UpdateManager

    var body: some View {
        ZStack {
            // Dimmed semi-transparent backdrop
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    if case .downloading = updateManager.state {
                        // Prevent closing during download
                    } else if case .extracting = updateManager.state {
                        // Prevent closing
                    } else {
                        updateManager.showUpdateModal = false
                    }
                }

            // Modal Dialog Card
            VStack(spacing: 12) {
                // Header Bar
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                            .font(.system(size: FS.value, weight: .bold))
                            .foregroundStyle(Color.accentColor)

                        VStack(alignment: .leading, spacing: 0) {
                            Text(tr("Cập nhật HyperMac", "Update HyperMac"))
                                .font(.system(size: FS.body, weight: .semibold))
                            Text(tr("Phiên bản hiện tại: v\(UpdateManager.currentVersion)", "Current version: v\(UpdateManager.currentVersion)"))
                                .font(.system(size: FS.caption))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Button {
                        updateManager.showUpdateModal = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: FS.subhead))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Divider()

                // State Content
                switch updateManager.state {
                case .idle, .checking:
                    VStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.regular)
                        Text(tr("Đang kiểm tra bản cập nhật mới trên GitHub...", "Checking for updates on GitHub..."))
                            .font(.system(size: FS.label))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)

                case .upToDate(let ver):
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: FS.huge))
                            .foregroundStyle(.secondary)

                        Text(tr("Bạn đang dùng phiên bản mới nhất!", "You are using the latest version!"))
                            .font(.system(size: FS.body, weight: .semibold))

                        Text(tr("HyperMac v\(ver) hiện là phiên bản cập nhật nhất. Máy của bạn đã sẵn sàng.", "HyperMac v\(ver) is currently the newest release. You are all set."))
                            .font(.system(size: FS.caption))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 10)

                        Button {
                            updateManager.checkForUpdates(silent: false)
                        } label: {
                            Text(tr("Kiểm tra lại", "Check Again"))
                                .font(.system(size: FS.label, weight: .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.primary.opacity(0.08)))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)

                case .updateAvailable(let ver, let notes, _, _):
                    let displayVer = ver.hasPrefix("v") || ver.hasPrefix("V") ? ver : "v\(ver)"
                    VStack(spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: FS.subhead))
                                .foregroundStyle(.secondary)

                            Text(tr("Đã có phiên bản mới: \(displayVer)", "New version available: \(displayVer)"))
                                .font(.system(size: FS.body, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                        }

                        // Release Notes Box
                        VStack(alignment: .leading, spacing: 3) {
                            Text(tr("Điểm mới trong bản \(displayVer):", "What's new in \(displayVer):"))
                                .font(.system(size: FS.caption, weight: .semibold))
                                .foregroundStyle(.secondary)

                            ScrollView(.vertical, showsIndicators: true) {
                                Text(notes)
                                    .font(.system(size: FS.caption))
                                    .lineSpacing(2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(6)
                            }
                            .frame(height: 95)
                            .background(
                                RoundedRectangle(cornerRadius: Rad.sm)
                                    .fill(Color.primary.opacity(0.04))
                            )
                        }

                        // Action Buttons
                        VStack(spacing: 6) {
                            Button {
                                updateManager.startUpdate()
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .font(.system(size: FS.body, weight: .semibold))
                                    Text(tr("Cập nhật ngay (Tự động tải & Cài đặt)", "Update Now (Auto Download & Install)"))
                                        .font(.system(size: FS.label, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: Rad.sm)
                                        .fill(Color.accentColor)
                                )
                                .foregroundStyle(Color.white)
                            }
                            .buttonStyle(.plain)

                            Button {
                                updateManager.openReleasePage()
                            } label: {
                                Text(tr("Xem chi tiết trên GitHub", "View details on GitHub"))
                                    .font(.system(size: FS.caption))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity)

                case .downloading(let progress):
                    VStack(spacing: 10) {
                        Image(systemName: "arrow.down.app.fill")
                            .font(.system(size: FS.hero))
                            .foregroundStyle(Color.accentColor)

                        Text(tr("Đang tải bản cập nhật: \(Int(progress * 100))%", "Downloading update: \(Int(progress * 100))%"))
                            .font(.system(size: FS.body, weight: .semibold))

                        ProgressView(value: progress, total: 1.0)
                            .progressViewStyle(.linear)
                            .padding(.horizontal, 20)

                        Text(tr("HyperMac sẽ tự động thay thế và khởi động lại ngay sau khi tải xong.", "HyperMac will automatically replace the old version and restart once complete."))
                            .font(.system(size: FS.caption))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 10)
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)

                case .extracting, .readyToRestart:
                    VStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.regular)

                        Text(tr("Đang cài đặt & chuẩn bị khởi động lại...", "Installing & preparing to restart..."))
                            .font(.system(size: FS.body, weight: .semibold))

                        Text(tr("Ứng dụng sẽ tự động mở lại trong giây lát.", "The application will reopen automatically in a moment."))
                            .font(.system(size: FS.caption))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)

                case .failed(let errorMsg):
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: FS.hero))
                            .foregroundStyle(.orange)

                        Text(tr("Không thể cập nhật tự động", "Failed to update automatically"))
                            .font(.system(size: FS.body, weight: .semibold))

                        Text(errorMsg)
                            .font(.system(size: FS.caption))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 10)

                        HStack(spacing: 8) {
                            Button {
                                updateManager.checkForUpdates(silent: false)
                            } label: {
                                Text(tr("Thử lại", "Try Again"))
                                    .font(.system(size: FS.caption, weight: .medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(Color.primary.opacity(0.08)))
                            }
                            .buttonStyle(.plain)

                            Button {
                                updateManager.openReleasePage()
                            } label: {
                                Text(tr("Mở GitHub Releases", "Open GitHub Releases"))
                                    .font(.system(size: FS.caption, weight: .medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(Color.accentColor.opacity(0.10)))
                                    .foregroundStyle(Color.accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)
                }

                Divider()

                // Preferences Row: Auto check on launch
                HStack {
                    Text(tr("Tự động kiểm tra bản mới khi mở HyperMac", "Automatically check for updates on startup"))
                        .font(.system(size: FS.caption))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Toggle("", isOn: Binding<Bool>(
                        get: { updateManager.autoCheckEnabled },
                        set: { updateManager.autoCheckEnabled = $0 }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: Rad.md)
                    .fill(Color(NSColor.windowBackgroundColor))
                    .shadow(color: Color.black.opacity(0.25), radius: 16, x: 0, y: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Rad.md)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Donate Modal View

private func getDonateQRImage() -> NSImage? {
    if let path = Bundle.main.path(forResource: "donate_qr", ofType: "jpg"),
       let img = NSImage(contentsOfFile: path) {
        return img
    }
    let execDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().path
    let fallbackPaths = [
        "/Applications/HyperMac.app/Contents/Resources/donate_qr.jpg",
        FileManager.default.currentDirectoryPath + "/Resources/donate_qr.jpg",
        execDir + "/Resources/donate_qr.jpg",
        execDir + "/../Resources/donate_qr.jpg"
    ]
    for p in fallbackPaths {
        if FileManager.default.fileExists(atPath: p), let img = NSImage(contentsOfFile: p) {
            return img
        }
    }
    return nil
}

struct DonateModalView: View {
    @ObservedObject var updateManager: UpdateManager

    var body: some View {
        ZStack {
            // Dimmed semi-transparent backdrop
            Color.black.opacity(0.45)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    updateManager.showDonateModal = false
                }

            // Modal Dialog Card
            VStack(spacing: 8) {
                // Header Bar
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "heart.circle.fill")
                            .font(.system(size: FS.value, weight: .bold))
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 0) {
                            Text(tr("Ủng hộ tác giả (Donate)", "Support Author (Donate)"))
                                .font(.system(size: FS.body, weight: .semibold))
                            Text(tr("Tiếp thêm động lực phát triển HyperMac", "Fuel HyperMac's continuous development"))
                                .font(.system(size: FS.caption))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Button {
                        updateManager.showDonateModal = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: FS.title))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(tr("Đóng", "Close"))
                }

                Divider()

                // Content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        // QR Code Image
                        if let qrImg = getDonateQRImage() {
                            VStack(spacing: 4) {
                                Image(nsImage: qrImg)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: 205, maxHeight: 255)
                                    .clipShape(RoundedRectangle(cornerRadius: Rad.md, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Rad.md, style: .continuous)
                                            .stroke(Color.accentColor.opacity(0.3), lineWidth: 1.2)
                                    )
                                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 3)

                                Text(tr("Quét mã bằng mọi app ngân hàng", "Scan QR with any banking app"))
                                    .font(.system(size: FS.caption, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, 1)
                        }

                        // Message Box
                        VStack(alignment: .leading, spacing: 6) {
                            Text(tr(
                                "Thật sự cảm ơn bạn đã nhấn vào nút này, từ tận đáy lòng, mình luôn trân trọng số tiền mọi người ủng hộ kể cả ít hay nhiều, điều đó cho mình một động lực rất lớn để tiếp tục phát triển phần mềm này.",
                                "Thank you so much for clicking this button. From the bottom of my heart, I truly appreciate any contribution, big or small. It gives me great motivation to keep maintaining and improving this app."
                            ))
                                .font(.system(size: FS.label))
                                .lineSpacing(2.5)
                                .foregroundStyle(.primary.opacity(0.92))
                                .fixedSize(horizontal: false, vertical: true)

                            Text(tr(
                                "Mình xin chân thành cảm ơn tấm lòng của mọi người 😊😊😊.",
                                "I sincerely thank each and every one of you for your support 😊😊😊."
                            ))
                                .font(.system(size: FS.label, weight: .semibold))
                                .lineSpacing(2.5)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(tr(
                                "Nếu được, rất mong bạn có thể nhắn cho mình thông tin donate qua FB để mình có thể gửi lời cảm ơn trực tiếp đến bạn ❤️",
                                "If possible, please send me a quick message on Facebook so I can thank you personally ❤️"
                            ))
                                .font(.system(size: FS.label))
                                .lineSpacing(2.5)
                                .foregroundStyle(.primary.opacity(0.92))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: Rad.md, style: .continuous)
                                .fill(Color.accentColor.opacity(0.07))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Rad.md, style: .continuous)
                                .stroke(Color.accentColor.opacity(0.10), lineWidth: 1)
                        )

                        // Facebook Link Button
                        Button {
                            if let url = URL(string: "https://bit.ly/4ectK8U") {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                    .font(.system(size: FS.label))
                                Text(tr("Nhắn tin qua Facebook cho tác giả ↗", "Message author on Facebook ↗"))
                                    .font(.system(size: FS.label, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.accentColor.opacity(0.12)))
                            .foregroundStyle(Color.accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 2)
                }
                .frame(maxHeight: 515)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: Rad.md)
                    .fill(Color(NSColor.windowBackgroundColor))
                    .shadow(color: Color.black.opacity(0.28), radius: 16, x: 0, y: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Rad.md)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Community Activation Modal (Zalo Group Onboarding)

/* Hallmark · pre-emit critique: P5 H5 E5 S5 R5 V5 */
struct ActivationModalView: View {
    @ObservedObject var activationManager: ActivationManager
    private let zaloBlue = Color(red: 0.0, green: 0.41, blue: 1.0)

    var body: some View {
        ZStack {
            // High-contrast dimmed backdrop preventing accidental bypass
            Color.black.opacity(0.65)
                .edgesIgnoringSafeArea(.all)

            // Main Activation Dialog Card
            VStack(spacing: 0) {
                // Header Bar
                HStack(spacing: 8) {
                    Image(systemName: "key.fill")
                        .font(.system(size: FS.subhead, weight: .bold))
                        .foregroundStyle(zaloBlue)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(zaloBlue.opacity(0.14)))

                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Text(tr("Kích hoạt HyperMac", "Activate HyperMac"))
                                .font(.system(size: FS.title, weight: .bold))
                            Text(tr("MIỄN PHÍ", "FREE"))
                                .font(.system(size: 9, weight: .heavy))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(Capsule().fill(Tone.good.opacity(0.16)))
                                .foregroundStyle(Tone.good)
                        }
                        Text(tr("Tham gia cộng đồng Zalo để nhận mã vĩnh viễn", "Join our Zalo group to receive the lifetime key"))
                            .font(.system(size: FS.caption))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 8)

                Divider()

                // Scrollable Body
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 11) {
                        // Instruction Notice Card
                        VStack(alignment: .leading, spacing: 5) {
                            Text(tr("Hướng dẫn nhận mã:", "How to get your key:"))
                                .font(.system(size: FS.label, weight: .semibold))
                                .foregroundStyle(.primary)

                            Text(tr(
                                "1. Nhấn nút bên dưới để tham gia nhóm Zalo HyperMac.\n2. Xem tin nhắn đã ghim ở đầu nhóm để lấy mã kích hoạt.\n3. Nhập mã vào ô bên dưới và bấm Kích hoạt.",
                                "1. Tap the button below to join the HyperMac Zalo group.\n2. Check the pinned message at the top of the group for the key.\n3. Enter the key below and click Activate."
                            ))
                            .font(.system(size: FS.label))
                            .lineSpacing(2.5)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: Rad.sm, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                        )

                        // Primary Zalo Group Button
                        Button {
                            activationManager.openZaloGroup()
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                    .font(.system(size: FS.body))
                                Text(tr("Tham gia nhóm Zalo lấy Key ↗", "Join Zalo Group for Key ↗"))
                                    .font(.system(size: FS.body, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: Rad.sm, style: .continuous)
                                    .fill(zaloBlue)
                            )
                            .foregroundStyle(Color.white)
                            .shadow(color: zaloBlue.opacity(0.3), radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                        .help(tr("Mở liên kết nhóm Zalo trong trình duyệt", "Open Zalo group link in browser"))

                        // QR Code Scanner Box
                        if let qrImg = activationManager.getZaloQRImage() {
                            VStack(spacing: 5) {
                                Image(nsImage: qrImg)
                                    .resizable()
                                    .interpolation(.high)
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 140, height: 140)
                                    .padding(6)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: Rad.sm, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Rad.sm, style: .continuous)
                                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                                    )
                                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)

                                Text(tr("Hoặc quét mã QR bằng Zalo trên điện thoại", "Or scan this QR code with Zalo on your phone"))
                                    .font(.system(size: FS.caption, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }

                        // Key Input & Submit Box
                        VStack(alignment: .leading, spacing: 6) {
                            Text(tr("Nhập mã kích hoạt:", "Enter Activation Key:"))
                                .font(.system(size: FS.label, weight: .semibold))
                                .foregroundStyle(.primary)

                            HStack(spacing: 8) {
                                TextField(tr("Nhập mã từ tin nhắn ghim...", "Enter key from pinned message..."), text: $activationManager.inputKey, onCommit: {
                                    activationManager.submitKey()
                                })
                                .textFieldStyle(.plain)
                                .font(.system(size: FS.body, weight: .medium, design: .monospaced))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: Rad.sm, style: .continuous)
                                        .fill(Color(nsColor: .controlBackgroundColor))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: Rad.sm, style: .continuous)
                                        .stroke(activationManager.errorMessage != nil ? Tone.bad : Color.primary.opacity(0.15), lineWidth: 1)
                                )

                                Button {
                                    activationManager.submitKey()
                                } label: {
                                    HStack(spacing: 4) {
                                        if activationManager.isSuccess {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: FS.label, weight: .bold))
                                        }
                                        Text(activationManager.isSuccess ? tr("Đã xong", "Done") : tr("Kích hoạt", "Activate"))
                                            .font(.system(size: FS.label, weight: .semibold))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: Rad.sm, style: .continuous)
                                            .fill(activationManager.isSuccess ? Tone.good : Tone.accent)
                                    )
                                    .foregroundStyle(Color.white)
                                }
                                .buttonStyle(.plain)
                                .disabled(activationManager.inputKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }

                            // Error or Success Feedback
                            if let err = activationManager.errorMessage {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .font(.system(size: FS.caption))
                                    Text(err)
                                        .font(.system(size: FS.caption))
                                }
                                .foregroundStyle(Tone.bad)
                                .padding(.top, 1)
                            } else if activationManager.isSuccess {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: FS.caption))
                                    Text(tr("Kích hoạt thành công! Chúc bạn trải nghiệm tuyệt vời.", "Successfully activated! Enjoy HyperMac."))
                                        .font(.system(size: FS.caption, weight: .medium))
                                }
                                .foregroundStyle(Tone.good)
                                .padding(.top, 1)
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: Rad.sm, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                        )

                        // Lifetime Guarantee Note
                        HStack(alignment: .top, spacing: 5) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: FS.caption))
                                .foregroundStyle(Tone.good)
                                .padding(.top, 1)

                            Text(tr(
                                "Chỉ cần nhập 1 lần duy nhất. Trạng thái kích hoạt được lưu vĩnh viễn trên máy và không bao giờ hỏi lại kể cả sau khi cập nhật phiên bản mới.",
                                "You only need to activate once. Lifetime access is preserved permanently on this Mac across future updates."
                            ))
                            .font(.system(size: FS.caption))
                            .foregroundStyle(.secondary)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 4)
                        .padding(.top, 2)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                .frame(maxHeight: 490)
            }
            .background(
                RoundedRectangle(cornerRadius: Rad.md, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .shadow(color: Color.black.opacity(0.35), radius: 20, x: 0, y: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Rad.md, style: .continuous)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            )
            .padding(.horizontal, 14)
        }
    }
}
