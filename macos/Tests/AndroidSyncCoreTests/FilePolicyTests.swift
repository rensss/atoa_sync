import XCTest
@testable import AndroidSyncCore

final class FilePolicyTests: XCTestCase {
    func testSafeFilenameKeepsOnlyFinalDecodedComponent() throws {
        XCTAssertEqual(
            try FilePolicy.safeFilename(from: "DCIM/Camera/IMG%200001.jpg"),
            "IMG 0001.jpg"
        )
    }

    func testSafeFilenameRejectsTraversalAndAbsolutePaths() {
        XCTAssertThrowsError(try FilePolicy.safeFilename(from: "../secret.txt"))
        XCTAssertThrowsError(try FilePolicy.safeFilename(from: "/tmp/secret.txt"))
        XCTAssertThrowsError(try FilePolicy.safeFilename(from: ""))
    }

    func testKindUsesExtensionBeforeContentType() {
        XCTAssertEqual(FilePolicy.kind(filename: "photo.HEIC", contentType: nil), .photo)
        XCTAssertEqual(FilePolicy.kind(filename: "clip.bin", contentType: "video/mp4"), .video)
        XCTAssertEqual(FilePolicy.kind(filename: "notes.txt", contentType: "text/plain"), .file)
    }

    func testPrivateNetworkPolicyAllowsLANAndLoopbackOnly() {
        XCTAssertTrue(NetworkAccessPolicy.isTrusted(address: "127.0.0.1"))
        XCTAssertTrue(NetworkAccessPolicy.isTrusted(address: "10.1.2.3"))
        XCTAssertTrue(NetworkAccessPolicy.isTrusted(address: "172.16.2.3"))
        XCTAssertTrue(NetworkAccessPolicy.isTrusted(address: "192.168.1.20"))
        XCTAssertTrue(NetworkAccessPolicy.isTrusted(address: "fe80::1234"))
        XCTAssertFalse(NetworkAccessPolicy.isTrusted(address: "8.8.8.8"))
        XCTAssertFalse(NetworkAccessPolicy.isTrusted(address: "172.32.0.1"))
    }
}
