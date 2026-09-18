import Foundation
import UIKit

struct Capture: Identifiable, Codable, Equatable {
    let id: UUID
    let createdAt: Date
    var note: String
    let imageFilename: String
}

final class CaptureStore {
    static let appGroupIdentifier = "group.com.kimminsu.screenshotsmemo"

    enum StoreError: LocalizedError, Equatable {
        case appGroupUnavailable(String)
        case invalidImageData
        case missingImage(String)

        var errorDescription: String? {
            switch self {
            case .appGroupUnavailable(let identifier):
                return "공유 저장 공간(\(identifier))을 사용할 수 없습니다. 앱과 공유 확장 모두에서 App Group 권한을 확인해 주세요."
            case .invalidImageData:
                return "선택한 항목은 올바른 이미지가 아닙니다."
            case .missingImage(let filename):
                return "이미지 파일(\(filename))을 찾을 수 없습니다."
            }
        }
    }

    private let directory: URL
    private let metadataDirectory: URL
    private let imagesDirectory: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(directory: URL? = nil) throws {
        let fileManager = FileManager.default
        let root: URL

        if let directory {
            root = directory
        } else {
            guard let group = fileManager.containerURL(
                forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier
            ) else {
                throw StoreError.appGroupUnavailable(Self.appGroupIdentifier)
            }
            root = group.appendingPathComponent("Captures", isDirectory: true)
        }

        self.fileManager = fileManager
        self.directory = root
        self.metadataDirectory = root.appendingPathComponent("Metadata", isDirectory: true)
        self.imagesDirectory = root.appendingPathComponent("Images", isDirectory: true)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .deferredToDate
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .deferredToDate
        self.decoder = decoder

        try fileManager.createDirectory(at: self.metadataDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: self.imagesDirectory, withIntermediateDirectories: true)
    }

    func all() throws -> [Capture] {
        let urls = try fileManager.contentsOfDirectory(
            at: metadataDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        return try urls
            .filter { $0.pathExtension == "json" }
            .map { try decoder.decode(Capture.self, from: Data(contentsOf: $0)) }
            .sorted {
                if $0.createdAt == $1.createdAt { return $0.id.uuidString > $1.id.uuidString }
                return $0.createdAt > $1.createdAt
            }
    }

    @discardableResult
    func save(imageData: Data, note: String) throws -> Capture {
        guard UIImage(data: imageData) != nil else {
            throw StoreError.invalidImageData
        }

        let id = UUID()
        let filename = "\(id.uuidString).image"
        let capture = Capture(
            id: id,
            createdAt: Date(),
            note: note,
            imageFilename: filename
        )
        let imageURL = imagesDirectory.appendingPathComponent(filename, isDirectory: false)

        try imageData.write(to: imageURL, options: .atomic)
        do {
            try writeMetadata(capture)
        } catch {
            try? fileManager.removeItem(at: imageURL)
            throw error
        }
        return capture
    }

    func update(_ capture: Capture, note: String) throws {
        guard fileManager.fileExists(atPath: imageURL(for: capture).path) else {
            throw StoreError.missingImage(capture.imageFilename)
        }
        var updated = capture
        updated.note = note
        try writeMetadata(updated)
    }

    func delete(_ capture: Capture) throws {
        let metadataURL = self.metadataURL(for: capture.id)
        let imageURL = imageURL(for: capture)

        if fileManager.fileExists(atPath: metadataURL.path) {
            try fileManager.removeItem(at: metadataURL)
        }
        if fileManager.fileExists(atPath: imageURL.path) {
            try fileManager.removeItem(at: imageURL)
        }
    }

    func imageURL(for capture: Capture) -> URL {
        imagesDirectory.appendingPathComponent(capture.imageFilename, isDirectory: false)
    }

    private func metadataURL(for id: UUID) -> URL {
        metadataDirectory.appendingPathComponent("\(id.uuidString).json", isDirectory: false)
    }

    private func writeMetadata(_ capture: Capture) throws {
        try encoder.encode(capture).write(to: metadataURL(for: capture.id), options: .atomic)
    }
}
