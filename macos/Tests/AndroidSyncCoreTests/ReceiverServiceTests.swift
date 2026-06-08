import Foundation
import XCTest
@testable import AndroidSyncCore

final class ReceiverServiceTests: XCTestCase {
    func testHealthUploadAndManifestOverRealHTTP() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let repository = LibraryRepository(rootURL: root)
        let service = ReceiverService(repository: repository, port: 0)
        let port = try await service.start()
        defer { service.stop() }

        let baseURL = try XCTUnwrap(URL(string: "http://127.0.0.1:\(port)"))
        let (healthData, healthResponse) = try await URLSession.shared.data(
            from: baseURL.appendingPathComponent("health")
        )
        XCTAssertEqual((healthResponse as? HTTPURLResponse)?.statusCode, 200)
        XCTAssertEqual(
            (try JSONSerialization.jsonObject(with: healthData) as? [String: String])?["status"],
            "ok"
        )

        var uploadRequest = URLRequest(
            url: baseURL.appendingPathComponent("uploads/Network.jpg")
        )
        uploadRequest.httpMethod = "PUT"
        uploadRequest.httpBody = Data("network photo".utf8)
        uploadRequest.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        uploadRequest.setValue("image:network", forHTTPHeaderField: "X-Android-Sync-Id")
        let (uploadData, uploadResponse) = try await URLSession.shared.data(for: uploadRequest)
        XCTAssertEqual((uploadResponse as? HTTPURLResponse)?.statusCode, 201)
        XCTAssertEqual(
            (try JSONSerialization.jsonObject(with: uploadData) as? [String: Any])?["status"] as? String,
            "stored"
        )

        let (manifestData, manifestResponse) = try await URLSession.shared.data(
            from: baseURL.appendingPathComponent("manifest.json")
        )
        XCTAssertEqual((manifestResponse as? HTTPURLResponse)?.statusCode, 200)
        let manifest = try JSONSerialization.jsonObject(with: manifestData) as! [String: Any]
        XCTAssertEqual(manifest["count"] as? Int, 1)
        let uploads = manifest["uploads"] as! [[String: Any]]
        XCTAssertEqual(uploads[0]["stable_id"] as? String, "image:network")
    }
}
