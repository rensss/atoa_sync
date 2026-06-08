import Foundation

public enum UploadKind: String, Codable, CaseIterable, Sendable {
    case photo = "photos"
    case video = "videos"
    case file = "files"
}

public enum FilePolicyError: LocalizedError {
    case invalidFilename
    case absolutePath
    case pathTraversal

    public var errorDescription: String? {
        switch self {
        case .invalidFilename:
            return "Invalid upload filename."
        case .absolutePath:
            return "Absolute upload paths are not allowed."
        case .pathTraversal:
            return "Path traversal is not allowed."
        }
    }
}

public enum FilePolicy {
    private static let photoExtensions: Set<String> = [
        "jpg", "jpeg", "png", "webp", "heic", "heif", "gif"
    ]
    private static let videoExtensions: Set<String> = [
        "mp4", "mov", "m4v", "3gp", "webm", "avi", "mkv"
    ]

    public static func safeFilename(from rawPath: String) throws -> String {
        let decoded = rawPath.removingPercentEncoding ?? rawPath
        let normalized = decoded.replacingOccurrences(of: "\\", with: "/")
        guard !normalized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FilePolicyError.invalidFilename
        }
        guard !normalized.hasPrefix("/") else {
            throw FilePolicyError.absolutePath
        }

        let parts = normalized
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)
        guard !parts.isEmpty else {
            throw FilePolicyError.invalidFilename
        }
        guard !parts.contains("..") else {
            throw FilePolicyError.pathTraversal
        }

        let filename = parts[parts.count - 1].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !filename.isEmpty, filename != ".", filename != ".." else {
            throw FilePolicyError.invalidFilename
        }
        return filename
    }

    public static func kind(filename: String, contentType: String?) -> UploadKind {
        let fileExtension = URL(fileURLWithPath: filename).pathExtension.lowercased()
        if photoExtensions.contains(fileExtension) {
            return .photo
        }
        if videoExtensions.contains(fileExtension) {
            return .video
        }
        if contentType?.lowercased().hasPrefix("image/") == true {
            return .photo
        }
        if contentType?.lowercased().hasPrefix("video/") == true {
            return .video
        }
        return .file
    }
}
