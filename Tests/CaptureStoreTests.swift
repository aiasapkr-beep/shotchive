import XCTest
import UIKit
@testable import Screenshots

final class CaptureStoreTests: XCTestCase {
    private var temporaryDirectory: URL!
    private var store: CaptureStore!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        store = try CaptureStore(directory: temporaryDirectory)
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        store = nil
        temporaryDirectory = nil
    }

    func testSavePersistsCaptureAndImage() throws {
        let imageData = try makeImageData()
        let capture = try store.save(imageData: imageData, note: "Keep this idea")

        let reloadedStore = try CaptureStore(directory: temporaryDirectory)
        XCTAssertEqual(try reloadedStore.all(), [capture])
        XCTAssertEqual(try Data(contentsOf: reloadedStore.imageURL(for: capture)), imageData)
    }

    func testIndependentStoresDoNotLoseEachOthersCaptures() throws {
        let firstStore = try CaptureStore(directory: temporaryDirectory)
        let secondStore = try CaptureStore(directory: temporaryDirectory)

        let first = try firstStore.save(imageData: makeImageData(), note: "First")
        let second = try secondStore.save(imageData: makeImageData(), note: "Second")

        let captures = try CaptureStore(directory: temporaryDirectory).all()
        XCTAssertEqual(Set(captures.map(\.id)), Set([first.id, second.id]))
        XCTAssertEqual(captures.count, 2)
    }

    func testUpdateChangesOnlyNote() throws {
        let capture = try store.save(imageData: makeImageData(), note: "Before")
        try store.update(capture, note: "After")

        let updated = try XCTUnwrap(try store.all().first)
        XCTAssertEqual(updated.id, capture.id)
        XCTAssertEqual(updated.createdAt, capture.createdAt)
        XCTAssertEqual(updated.imageFilename, capture.imageFilename)
        XCTAssertEqual(updated.note, "After")
    }

    func testDeleteRemovesMetadataAndImage() throws {
        let capture = try store.save(imageData: makeImageData(), note: "Disposable")
        let imageURL = store.imageURL(for: capture)

        try store.delete(capture)

        XCTAssertTrue(try store.all().isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: imageURL.path))
    }

    func testSaveRejectsMalformedImageData() throws {
        XCTAssertThrowsError(try store.save(imageData: Data("not an image".utf8), note: "Bad")) {
            XCTAssertEqual($0 as? CaptureStore.StoreError, .invalidImageData)
        }
        XCTAssertTrue(try store.all().isEmpty)
    }

    func testSUITFontIsRegistered() {
        XCTAssertNotNil(UIFont(name: "SUITVariable-Regular", size: 17))
        XCTAssertNotNil(UIFont(name: "SUITVariable-Bold", size: 34))
    }

    private func makeImageData() throws -> Data {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
        return try XCTUnwrap(image.pngData())
    }
}
