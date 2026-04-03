import SwiftUI

struct AddPlatformSheet: View {
    @EnvironmentObject var playlistVM: PlaylistViewModel
    @Environment(\.dismiss) var dismiss

    @State private var urlInput: String = ""
    @FocusState private var isURLFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("添加歌单")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "#202124"))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "#5F6368"))
                        .frame(width: 28, height: 28)
                        .background(Color(hex: "#F1F3F4"))
                        .cornerRadius(14)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            // Platform cards
            VStack(spacing: 12) {
                PlatformCard(
                    platform: .qq,
                    description: "打开 QQ音乐 → 进入歌单 → 点击分享 → 复制链接 → 粘贴到下方",
                    color: "#31C34A"
                )

                PlatformCard(
                    platform: .netEase,
                    description: "打开网易云音乐 → 进入歌单 → 点击分享 → 复制链接 → 粘贴到下方",
                    color: "#C20C0C"
                )
            }
            .padding(20)

            // URL input
            VStack(alignment: .leading, spacing: 8) {
                Text("歌单链接")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "#5F6368"))

                HStack(spacing: 8) {
                    TextField("https://y.qq.com/... 或 https://music.163.com/...", text: $urlInput)
                        .font(.system(size: 13))
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(hex: "#F1F3F4"))
                        .cornerRadius(8)
                        .focused($isURLFieldFocused)

                    Button(action: {
                        Task {
                            await playlistVM.addPlaylistFromURL(urlInput)
                        }
                    }) {
                        if playlistVM.isLoading {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 36, height: 36)
                        } else {
                            Text("添加")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 56, height: 36)
                                .background(urlInput.isEmpty ? Color(hex: "#DADCE0") : Color(hex: "#1A73E8"))
                                .cornerRadius(8)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(urlInput.isEmpty || playlistVM.isLoading)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            // Error message
            if let error = playlistVM.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 13))
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }

            // Usage hints
            VStack(alignment: .leading, spacing: 6) {
                Text("支持的链接格式：")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "#9AA0A6"))

                Text("QQ音乐: y.qq.com/n/ryqq/playlist/xxxxx")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color(hex: "#9AA0A6"))

                Text("网易云: music.163.com/playlist?id=xxxxx")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color(hex: "#9AA0A6"))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: "#F8F9FA"))
            .cornerRadius(8)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(width: 480)
        .onAppear {
            isURLFieldFocused = true
        }
    }
}

// MARK: - Platform Card

struct PlatformCard: View {
    let platform: Platform
    let description: String
    let color: String

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: color))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: platform.iconName)
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(platform.rawValue)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "#202124"))
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#5F6368"))
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(12)
        .background(Color(hex: "#F8F9FA"))
        .cornerRadius(12)
    }
}
