import SwiftUI

// MARK: - Add Platform Sheet

struct AddPlatformSheet: View {
    @EnvironmentObject var playlistVM: PlaylistViewModel
    @Environment(\.dismiss) var dismiss

    @State private var urlInput: String = ""
    @FocusState private var isURLFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.Palette.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Theme.Palette.bgTertiary))
                }
                .buttonStyle(.plain)
            }
            .padding(.trailing, Theme.Spacing.xl)
            .padding(.top, Theme.Spacing.xl)

            // Title
            VStack(spacing: Theme.Spacing.sm) {
                Text("添加歌单")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Theme.Palette.textPrimary)
                Text("粘贴歌单链接，一键导入")
                    .font(.system(size: Theme.FontSize.body))
                    .foregroundColor(Theme.Palette.textSecondary)
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
                    .foregroundColor(Theme.Palette.textSecondary)

                HStack(spacing: Theme.Spacing.md) {
                    TextField("https://y.qq.com/... 或 https://music.163.com/...", text: $urlInput)
                        .font(.system(size: Theme.FontSize.body))
                        .textFieldStyle(.plain)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.md)
                                .fill(Theme.Palette.bgTertiary)
                        )
                        .focused($isURLFieldFocused)

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
                                        .fill(urlInput.isEmpty ? Theme.Palette.textTertiary : Theme.Palette.accent)
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
                        .foregroundColor(Theme.Palette.error)
                        .font(.system(size: 13))
                    Text(error)
                        .font(.system(size: Theme.FontSize.caption))
                        .foregroundColor(Theme.Palette.error)
                }
                .padding(Theme.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm)
                        .fill(Theme.Palette.errorBg)
                )
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.md)
            }

            Spacer()

            // Footer hints
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("支持格式：")
                    .font(.system(size: Theme.FontSize.small, weight: .medium))
                    .foregroundColor(Theme.Palette.textTertiary)
                Text("QQ音乐: y.qq.com/n/ryqq/playlist/xxxxx")
                    .font(.system(size: Theme.FontSize.small, design: .monospaced))
                    .foregroundColor(Theme.Palette.textTertiary)
                Text("网易云: music.163.com/playlist?id=xxxxx")
                    .font(.system(size: Theme.FontSize.small, design: .monospaced))
                    .foregroundColor(Theme.Palette.textTertiary)
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Palette.bgTertiary.opacity(0.5))
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .frame(width: 480)
        .onAppear {
            isURLFieldFocused = true
        }
    }
}

// MARK: - Platform Card

struct PlatformCardView: View {
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
                .foregroundColor(Theme.Palette.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .fill(Theme.Palette.bgTertiary)
        )
    }
}
