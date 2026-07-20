import SwiftUI

struct SidebarView: View {
    @Bindable var model: AppModel

    var body: some View {
        List(LibraryCategory.allCases, selection: $model.category) { category in
            Label(
                category.title(using: model.language),
                systemImage: category.systemImage
            )
            .badge(
                Text("\(model.categoryCount(category))")
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
            )
            .tag(category)
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(Theme.bgSidebar)
        .navigationTitle("Android Sync")
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: Theme.spacingS) {
                Divider()

                librarySummary

                if let directory = model.receiveDirectory {
                    Button {
                        model.openReceiveDirectory()
                    } label: {
                        Label(directory.lastPathComponent, systemImage: "folder")
                            .lineLimit(1)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .help(directory.path)
                }
            }
            .padding(.horizontal, Theme.spacingM)
            .padding(.bottom, Theme.spacingM)
        }
    }

    private var librarySummary: some View {
        let stats = model.sidebarLibraryStats

        return VStack(alignment: .leading, spacing: Theme.spacingS) {
            Text(model.text(.librarySummary))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.textSecondary)

            HStack(spacing: Theme.spacingM) {
                summaryCount(
                    stats.photoCount,
                    title: LibraryCategory.photos.title(using: model.language),
                    systemImage: LibraryCategory.photos.systemImage
                )
                summaryCount(
                    stats.videoCount,
                    title: LibraryCategory.videos.title(using: model.language),
                    systemImage: LibraryCategory.videos.systemImage
                )
                summaryCount(
                    stats.fileCount,
                    title: LibraryCategory.files.title(using: model.language),
                    systemImage: LibraryCategory.files.systemImage
                )
            }

            Label(
                model.format(
                    .storageUsedFormat,
                    model.formatByteCount(stats.totalBytes)
                ),
                systemImage: "internaldrive"
            )
            .font(.caption)
            .foregroundStyle(Theme.textSecondary)
        }
    }

    private func summaryCount(
        _ count: Int,
        title: String,
        systemImage: String
    ) -> some View {
        Label("\(count)", systemImage: systemImage)
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(Theme.textPrimary)
            .help(title)
            .accessibilityLabel("\(title): \(count)")
    }
}
