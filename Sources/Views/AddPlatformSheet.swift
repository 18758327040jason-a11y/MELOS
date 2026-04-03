import SwiftUI
import AppKit

// MARK: - Plain NSTextField (no custom key handling, Cmd+C/V/A works natively)

final class PlainTextField: NSTextField {
    override func keyDown(with event: NSEvent) {
        super.keyDown(with: event)
    }
}

struct PlainTextFieldView: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: NSViewRepresentableContext<PlainTextFieldView>) -> NSTextField {
        let field = NSTextField()
        field.placeholderString = placeholder
        field.stringValue = text
        field.font = NSFont.systemFont(ofSize: 13)
        field.bezelStyle = .roundedBezel
        field.focusRingType = .none
        field.delegate = context.coordinator
        // Explicitly make this the first responder so Cmd+C/V work immediately
        DispatchQueue.main.async {
            field.window?.makeFirstResponder(field)
        }
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: NSViewRepresentableContext<PlainTextFieldView>) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: PlainTextFieldView

        init(_ parent: PlainTextFieldView) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }
    }
}

// MARK: - Add Platform Sheet

struct AddPlatformSheet: View {
    @EnvironmentObject var playlistVM: PlaylistViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.themeColors) var tc

    @State private var urlInput: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(tc.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(tc.bgTertiary))
                }
                .buttonStyle(.plain)
            }
            .padding(.trailing, Theme.Spacing.xl)
            .padding(.top, Theme.Spacing.xl)

            // Title
            VStack(spacing: Theme.Spacing.sm) {
                Text("添加歌单")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(tc.textPrimary)
                Text("粘贴歌单链接，一键导入")
                    .font(.system(size: Theme.FontSize.body))
                    .foregroundColor(tc.textSecondary)
            }
            .padding(.top, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.xl)

            // Platform cards
            HStack(spacing: Theme.Spacing.md) {
                PlatformCardView(
                    platform: .qq,
                    icon: "music.note",
                    color: Theme.Palette.qq
                )
                PlatformCardView(
                    platform: .netEase,
                    icon: "music.note.list",
                    color: Theme.Palette.netease
                )
            }
            .padding(.horizontal, Theme.Spacing.xl)

            // URL input
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("歌单链接")
                    .font(.system(size: Theme.FontSize.caption, weight: .medium))
                    .foregroundColor(tc.textSecondary)

                HStack(spacing: Theme.Spacing.md) {
                    PlainTextFieldView(
                        placeholder: "https://y.qq.com/... 或 https://music.163.com/...",
                        text: $urlInput
                    )
                    .frame(height: 44)

                    Button(action: {
                        Task {
                            await playlistVM.addPlaylistFromURL(urlInput)
                        }
                    }) {
                        if playlistVM.isLoading {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 44, height: 44)
                        } else {
                            Text("导入")
                                .font(.system(size: Theme.FontSize.body, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 68, height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                                        .fill(urlInput.isEmpty ? tc.textTertiary : tc.accent)
                                )
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(urlInput.isEmpty || playlistVM.isLoading)
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.top, Theme.Spacing.xl)

            // Error message
            if let error = playlistVM.errorMessage {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(tc.error)
                        .font(.system(size: 13))
                    Text(error)
                        .font(.system(size: Theme.FontSize.caption))
                        .foregroundColor(tc.error)
                }
                .padding(Theme.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm)
                        .fill(tc.errorBg)
                )
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.md)
            }

            Spacer()

            // Footer hints
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("支持格式：")
                    .font(.system(size: Theme.FontSize.small, weight: .medium))
                    .foregroundColor(tc.textTertiary)
                Text("QQ音乐: y.qq.com/n/ryqq/playlist/xxxxx")
                    .font(.system(size: Theme.FontSize.small, design: .monospaced))
                    .foregroundColor(tc.textTertiary)
                Text("网易云: music.163.com/playlist?id=xxxxx")
                    .font(.system(size: Theme.FontSize.small, design: .monospaced))
                    .foregroundColor(tc.textTertiary)
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tc.bgTertiary.opacity(0.5))
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .frame(width: 480)
    }
}

// MARK: - Platform Card

struct PlatformCardView: View {
    @Environment(\.themeColors) var tc
    let platform: Platform
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(color)
                )

            Text(platform.rawValue)
                .font(.system(size: Theme.FontSize.caption, weight: .semibold))
                .foregroundColor(tc.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .fill(tc.bgTertiary)
        )
    }
}
