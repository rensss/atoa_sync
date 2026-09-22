import Foundation
import XCTest
@testable import AndroidSyncCore

final class HTTPProtocolTests: XCTestCase {
    func testParserWaitsForCompleteHeaderAndLeavesBodyBytes() throws {
        var data = Data("PUT /uploads/IMG%2001.jpg HTTP/1.1\r\nContent-Length: 3\r\n".utf8)
        XCTAssertNil(try HTTPRequestParser.extractHead(from: &data))

        data.append(Data("\r\nabc".utf8))
        let head = try XCTUnwrap(HTTPRequestParser.extractHead(from: &data))

        XCTAssertEqual(head.method, "PUT")
        XCTAssertEqual(head.target, "/uploads/IMG%2001.jpg")
        XCTAssertEqual(head.header("content-length"), "3")
        XCTAssertEqual(data, Data("abc".utf8))
    }

    func testRouterCreatesUploadMetadataFromAndroidHeaders() throws {
        let request = HTTPRequestHead(
            method: "PUT",
            target: "/uploads/IMG%2001.jpg",
            version: "HTTP/1.1",
            headers: [
                "content-length": "3",
                "content-type": "image/jpeg",
                "x-android-sync-id": "image:42",
                "x-android-sync-date-modified": "1780482600000",
                "x-android-sync-batch-index": "2",
                "x-android-sync-batch-total": "5",
                "x-android-sync-batch-total-bytes": "123456"
            ]
        )

        let route = try ReceiverRouter.route(request, sourceIP: "192.168.1.20")

        guard case let .upload(expectedSize, metadata) = route else {
            return XCTFail("Expected upload route")
        }
        XCTAssertEqual(expectedSize, 3)
        XCTAssertEqual(metadata.filename, "IMG 01.jpg")
        XCTAssertEqual(metadata.stableID, "image:42")
        XCTAssertEqual(metadata.dateModifiedMillis, 1_780_482_600_000)
        XCTAssertEqual(metadata.sourceIP, "192.168.1.20")
        XCTAssertEqual(metadata.batchIndex, 2)
        XCTAssertEqual(metadata.batchTotal, 5)
        XCTAssertEqual(metadata.batchTotalBytes, 123456)
    }

    func testRouterTreatsInvalidBatchTotalBytesAsMissing() throws {
        for value in ["-1", "9223372036854775808"] {
            let request = HTTPRequestHead(
                method: "PUT",
                target: "/uploads/a.jpg",
                version: "HTTP/1.1",
                headers: [
                    "content-length": "0",
                    "x-android-sync-batch-total-bytes": value
                ]
            )

            guard case let .upload(_, metadata) = try ReceiverRouter.route(request, sourceIP: "192.168.1.20") else {
                return XCTFail("Expected upload route for invalid optional metadata: \(value)")
            }
            XCTAssertNil(metadata.batchTotalBytes, "invalid optional batch bytes should be treated as absent")
        }
    }

    func testRouterRequiresLengthAndTrustedSource() {
        let missingLength = HTTPRequestHead(
            method: "PUT",
            target: "/uploads/a.jpg",
            version: "HTTP/1.1",
            headers: [:]
        )
        XCTAssertThrowsError(try ReceiverRouter.route(missingLength, sourceIP: "192.168.1.2")) {
            XCTAssertEqual($0 as? HTTPRouteError, .lengthRequired)
        }

        let publicSource = HTTPRequestHead(
            method: "GET",
            target: "/health",
            version: "HTTP/1.1",
            headers: [:]
        )
        XCTAssertThrowsError(try ReceiverRouter.route(publicSource, sourceIP: "8.8.8.8")) {
            XCTAssertEqual($0 as? HTTPRouteError, .forbiddenSource)
        }
    }

    func testRouterRecognizesReadEndpoints() throws {
        XCTAssertEqual(
            try ReceiverRouter.route(
                HTTPRequestHead(method: "GET", target: "/health", version: "HTTP/1.1", headers: [:]),
                sourceIP: "127.0.0.1"
            ),
            .health
        )
        XCTAssertEqual(
            try ReceiverRouter.route(
                HTTPRequestHead(method: "GET", target: "/manifest.json", version: "HTTP/1.1", headers: [:]),
                sourceIP: "127.0.0.1"
            ),
            .manifest
        )
    }
}
