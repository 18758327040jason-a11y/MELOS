import SwiftUI

struct DownloadSheet: View {
    @EnvironmentObject var downloadVM: DownloadService
    @Environment(\.dismiss) var dismiss
    @Environment(\.themeColors) var tc

    @State private var urlInput: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showSuccess: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Spacer()
                Button(action: {
                    downloadVM.showingSheet = false
                    dismiss()
                }) {
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
                Text("下载文件")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(tc.textPrimary)
                Text("粘贴任意下载链接，保存到 MusicPlayer/download/")
                    .font(.system(size: Theme.FontSize.body))
                    .foregroundColor(tc.textSecondary)
            }
            .padding(.top, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.xl)

            // URL input
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("下载地址")
                    .font(.system(size: Theme.FontSize.caption, weight: .medium))
                    .foregroundColor(tc.textSecondary)

                HStack(spacing: Theme.Spacing.md) {
                    PlainTextFieldView(
                        placeholder: "https://...",
                        text: $urlInput
                    )
                    .frame(height: 44)

                    Button(action: startDownload) {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 68, height: 44)
                        } else {
                            Text("下载")
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
                    .disabled(urlInput.isEmpty || isLoading)
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.lg)

            // Download directory hint
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "folder")
                    .font(.system(size: 11))
                    .foregroundColor(tc.textTertiary)
                Text("保存至：~/Documents/program/MusicPlayer/download/")
                    .font(.system(size: Theme.FontSize.small))
                    .foregroundColor(tc.textTertiary)
            }
            .padding(.horizontal, Theme.Spacing.xl)

            // Error message
            if let error = errorMessage {
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

            // Success message
            if showSuccess {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Theme.Palette.success)
                        .font(.system(size: 13))
                    Text("下载完成，文件已保存到 download 目录")
                        .font(.system(size: Theme.FontSize.caption))
                        .foregroundColor(Theme.Palette.success)
                }
                .padding(Theme.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm)
                        .fill(Theme.Palette.success.opacity(0.1))
                )
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.md)
            }

            Spacer()

            // Download history
            if !downloadVM.items.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    HStack {
                        Text("下载历史")
                            .font(.system(size: Theme.FontSize.caption, weight: .semibold))
                            .foregroundColor(tc.textSecondary)
                        Spacer()
                        Button("清除") {
                            downloadVM.clearCompleted()
                        }
                        .font(.system(size: Theme.FontSize.small))
                        .foregroundColor(tc.accent)
                        .buttonStyle(.plain)
                    }

                    ScrollView {
                        VStack(spacing: Theme.Spacing.xs) {
                            ForEach(downloadVM.items.reversed()) { item in
                                DownloadItemRow(item: item)
                            }
                        }
                    }
                    .frame(maxHeight: 160)
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.xl)
                .background(tc.bgTertiary.opacity(0.5))
            }
        }
        .frame(width: 480)
    }

    private func startDownload() {
        errorMessage = nil
        showSuccess = false
        isLoading = true

        Task {
            do {
                let fileURL = try await DownloadService.shared.download(from: urlInput)
                showSuccess = true
                urlInput = ""
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - Download Item Row

struct DownloadItemRow: View {
    @Environment(\.themeColors) var tc
    let item: DownloadItem

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // Status icon
            Group {
                switch item.state {
                case .pending:
                    Image(systemName: "clock").foregroundColor(tc.textTertiary)
                case .downloading:
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 14, height: 14)
                case .completed:
                    Image(systemName: "checkmark.circle.fill").foregroundColor(Theme.Palette.success)
                case .failed:
                    Image(systemName: "xmark.circle.fill").foregroundColor(tc.error)
                case .cancelled:
                    Image(systemName: "minus.circle.fill").foregroundColor(tc.textTertiary)
                }
            }
            .font(.system(size: 13))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.fileName)
                    .font(.system(size: Theme.FontSize.caption))
                    .foregroundColor(tc.textPrimary)
                    .lineLimit(1)

                if let err = item.error {
                    Text(err)
                        .font(.system(size: Theme.FontSize.small))
                        .foregroundColor(tc.error)
                        .lineLimit(1)
                } else if item.state == .completed {
                    Text("保存至 download/")
                        .font(.system(size: Theme.FontSize.small))
                        .foregroundColor(tc.textTertiary)
                }
            }

            Spacer()

            if item.state == .downloading {
                Text("\(Int(item.progress * 100))%")
                    .font(.system(size: Theme.FontSize.small))
                    .foregroundColor(tc.textTertiary)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .fill(tc.bgElevated)
        )
    }
}
