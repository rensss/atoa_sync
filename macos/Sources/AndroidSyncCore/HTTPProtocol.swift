import Foundation

public struct HTTPRequestHead: Equatable, Sendable {
    public let method: String
    public let target: String
    public let version: String
    public let headers: [String: String]

    public init(
        method: String,
        target: String,
        version: String,
        headers: [String: String]
    ) {
        self.method = method.uppercased()
        self.target = target
        self.version = version
        self.headers = Dictionary(
            uniqueKeysWithValues: headers.map { ($0.key.lowercased(), $0.value) }
        )
    }

    public func header(_ name: String) -> String? {
        headers[name.lowercased()]
    }
}

public enum HTTPParserError: LocalizedError, Equatable {
    case headerTooLarge
    case malformedRequest

    public var errorDescription: String? {
        switch self {
        case .headerTooLarge:
            return "HTTP request headers exceed the allowed size."
        case .malformedRequest:
            return "Malformed HTTP request."
        }
    }
}

public enum HTTPRequestParser {
    public static let maximumHeaderBytes = 64 * 1_024

    public static func extractHead(from buffer: inout Data) throws -> HTTPRequestHead? {
        let separator = Data("\r\n\r\n".utf8)
        guard let separatorRange = buffer.range(of: separator) else {
            if buffer.count > maximumHeaderBytes {
                throw HTTPParserError.headerTooLarge
            }
            return nil
        }
        guard separatorRange.lowerBound <= maximumHeaderBytes else {
            throw HTTPParserError.headerTooLarge
        }

        let headData = buffer[..<separatorRange.lowerBound]
        buffer.removeSubrange(..<separatorRange.upperBound)
        guard let text = String(data: headData, encoding: .utf8) else {
            throw HTTPParserError.malformedRequest
        }
        let lines = text.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            throw HTTPParserError.malformedRequest
        }
        let requestParts = requestLine.split(separator: " ", omittingEmptySubsequences: true)
        guard requestParts.count == 3 else {
            throw HTTPParserError.malformedRequest
        }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else {
                throw HTTPParserError.malformedRequest
            }
            let name = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else {
                throw HTTPParserError.malformedRequest
            }
            headers[name] = value
        }

        return HTTPRequestHead(
            method: String(requestParts[0]),
            target: String(requestParts[1]),
            version: String(requestParts[2]),
            headers: headers
        )
    }
}

public enum ReceiverRoute: Equatable, Sendable {
    case root
    case health
    case manifest
    case upload(expectedSize: Int64, metadata: UploadMetadata)
    case notFound
}

public enum HTTPRouteError: Error, Equatable {
    case forbiddenSource
    case lengthRequired
    case invalidLength
    case invalidFilename
    case unsupportedTransferEncoding
}

public enum ReceiverRouter {
    public static func route(
        _ request: HTTPRequestHead,
        sourceIP: String
    ) throws -> ReceiverRoute {
        guard NetworkAccessPolicy.isTrusted(address: sourceIP) else {
            throw HTTPRouteError.forbiddenSource
        }
        let path = request.target.split(separator: "?", maxSplits: 1).first.map(String.init) ?? request.target

        if request.method == "GET" {
            switch path {
            case "/":
                return .root
            case "/health":
                return .health
            case "/manifest.json":
                return .manifest
            default:
                return .notFound
            }
        }

        guard request.method == "PUT", path.hasPrefix("/uploads/") else {
            return .notFound
        }
        if request.header("transfer-encoding") != nil {
            throw HTTPRouteError.unsupportedTransferEncoding
        }
        guard let lengthText = request.header("content-length") else {
            throw HTTPRouteError.lengthRequired
        }
        guard let expectedSize = Int64(lengthText), expectedSize >= 0 else {
            throw HTTPRouteError.invalidLength
        }
        let rawFilename = String(path.dropFirst("/uploads/".count))
        let filename: String
        do {
            filename = try FilePolicy.safeFilename(from: rawFilename)
        } catch {
            throw HTTPRouteError.invalidFilename
        }

        return .upload(
            expectedSize: expectedSize,
            metadata: UploadMetadata(
                filename: filename,
                contentType: request.header("content-type"),
                stableID: request.header("x-android-sync-id"),
                dateModifiedMillis: int64Header(request.header("x-android-sync-date-modified")),
                dateTakenMillis: int64Header(request.header("x-android-sync-date-taken")),
                dateAddedMillis: int64Header(request.header("x-android-sync-date-added")),
                sourceIP: sourceIP
            )
        )
    }

    private static func int64Header(_ value: String?) -> Int64? {
        guard let value, !value.isEmpty else {
            return nil
        }
        return Int64(value)
    }
}

public struct HTTPResponse: Sendable {
    public let status: Int
    public let reason: String
    public let body: Data
    public let contentType: String

    public init(
        status: Int,
        reason: String,
        body: Data,
        contentType: String = "application/json; charset=utf-8"
    ) {
        self.status = status
        self.reason = reason
        self.body = body
        self.contentType = contentType
    }

    public static func json(status: Int, reason: String, object: Any) throws -> HTTPResponse {
        HTTPResponse(
            status: status,
            reason: reason,
            body: try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        )
    }

    public func encoded() -> Data {
        var data = Data(
            """
            HTTP/1.1 \(status) \(reason)\r
            Content-Type: \(contentType)\r
            Content-Length: \(body.count)\r
            Connection: close\r
            \r

            """.utf8
        )
        data.append(body)
        return data
    }
}
