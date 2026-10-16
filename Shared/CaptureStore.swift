import Foundation
import UIKit

struct Capture: Identifiable, Codable, Equatable {
    let id: UUID
    let createdAt: Date
    var note: String
    let imageFilename: String
    /// 사진 보관함에서 가져온 캡처라면 그 에셋의 식별자. 같은 스크린샷을 두 번
    /// 들여오지 않기 위한 것이다. 이 필드가 생기기 전에 저장한 항목은 nil 이므로,
    /// 그런 항목은 촬영 시각으로 대조한다(`MissedScreenshots`).
    var assetLocalIdentifier: String?
    /// 스크린샷 안에서 읽어 낸 글자. 적은 메모와 함께 검색에 쓴다.
    /// `nil` 은 **아직 색인하지 않음**, `""` 는 **색인했는데 글자가 없음** 이다.
    /// 둘을 섞으면 글자 없는 캡처를 영원히 다시 읽게 된다(`ScreenshotText`).
    var recognizedText: String?
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
        } else if let group = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier
        ) {
            root = group.appendingPathComponent("Captures", isDirectory: true)
        } else {
            // App Group 을 쓸 수 없는 빌드(무료 개인 팀 서명 등)에서는 앱 자체 컨테이너에 보관한다.
            // 이때는 공유 확장과 저장소를 공유하지 못하므로 공유 시트 경로를 쓸 수 없다.
            // App Group 이 가능한 빌드로 되돌리면 저장 위치가 달라져 기존 항목이 보이지 않으니,
            // 그 경우 이 경로의 Captures 폴더를 App Group 컨테이너로 옮겨야 한다.
            let support = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            root = support.appendingPathComponent("Captures", isDirectory: true)
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
    func save(
        imageData: Data,
        note: String,
        createdAt: Date = Date(),
        assetLocalIdentifier: String? = nil,
        recognizedText: String? = nil
    ) throws -> Capture {
        guard UIImage(data: imageData) != nil else {
            throw StoreError.invalidImageData
        }

        let id = UUID()
        let filename = "\(id.uuidString).image"
        let capture = Capture(
            id: id,
            createdAt: createdAt,
            note: note,
            imageFilename: filename,
            assetLocalIdentifier: assetLocalIdentifier,
            recognizedText: recognizedText
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

    /// 색인 결과만 갈아 끼운다. 메모와 달리 사용자가 쓴 값이 아니므로 덮어써도 된다.
    func updateRecognizedText(_ capture: Capture, text: String) throws {
        var updated = capture
        updated.recognizedText = text
        try writeMetadata(updated)
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
