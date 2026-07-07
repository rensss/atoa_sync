import SwiftData
import XCTest
@testable import AndroidSyncMac

@MainActor
final class AppModelStatusCapsuleTests: XCTestCase {
    private func makeModel() throws -> AppModel {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: MediaItemEntity.self,
            configurations: config
        )
        return AppModel(
            modelContainer: container,
            userDefaults: UserDefaults(suiteName: UUID().uuidString)!
        )
    }

    func testTitleCoversAllFiveStatuses() throws {
        let model = try makeModel()
        let cases: [(ReceiverStatus, AppStringKey)] = [
            (.needsDirectory, .receiveFolderRequired),
            (.stopped, .receiverPaused),
            (.starting, .startingReceiver),
            (.running, .readyToReceive),
            (.failed("x"), .receiverUnavailable),
        ]
        for (status, key) in cases {
            model.status = status
            XCTAssertEqual(model.statusCapsuleTitle, model.text(key))
        }
    }

    func testTitleShowsReceivingCountWhileRunning() throws {
        let model = try makeModel()
        model.status = .running
        model.activeUploads[UUID()] = ActiveUpload(
            id: UUID(), filename: "a.jpg", expectedSize: 1
        )
        XCTAssertEqual(
            model.statusCapsuleTitle,
            model.format(.receivingFilesFormat, 1)
        )
    }

    func testDetailFallsBackToPortWhenNoURL() throws {
        let model = try makeModel()
        model.uploadURL = ""
        XCTAssertEqual(
            model.statusCapsuleDetail,
            model.format(.portFormat, Int(model.port))
        )
        model.uploadURL = "http://192.168.1.8:8765/uploads/"
        XCTAssertEqual(model.statusCapsuleDetail, model.uploadURL)
    }
}
