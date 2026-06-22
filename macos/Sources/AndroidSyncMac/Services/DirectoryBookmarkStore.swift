import Foundation

struct DirectoryBookmarkClient {
    let resolve: @MainActor () throws -> URL?
    let save: @MainActor (URL) throws -> Void
    let clear: @MainActor () -> Void

    static let live = DirectoryBookmarkClient(
        resolve: DirectoryBookmarkStore.resolve,
        save: DirectoryBookmarkStore.save,
        clear: DirectoryBookmarkStore.clear
    )
}

struct DirectoryAccessClient {
    let start: @MainActor (URL) -> Bool
    let stop: @MainActor (URL) -> Void

    static let live = DirectoryAccessClient(
        start: { $0.startAccessingSecurityScopedResource() },
        stop: { $0.stopAccessingSecurityScopedResource() }
    )
}

enum DirectoryBookmarkStore {
    private static let bookmarkKey = "receiveDirectoryBookmark"

    static func clear() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
    }

    static func save(_ url: URL) throws {
        let data = try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(data, forKey: bookmarkKey)
    }

    static func resolve() throws -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else {
            return nil
        }
        var stale = false
        let url = try URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        )
        if stale {
            try save(url)
        }
        return url
    }
}
