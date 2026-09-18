import Foundation

/// 보관함 전체를 폴더 하나로 빼낸다. 이미지 원본 + 사람이 읽는 메모 목록 + 기계가 읽는 JSON.
/// 앱을 지워도 남도록, 그리고 다른 도구로 옮겨갈 수 있도록 하는 것이 목적이다.
enum CaptureExporter {
    enum ExportError: LocalizedError {
        case nothingToExport
        case archiveFailed(String)

        var errorDescription: String? {
            switch self {
            case .nothingToExport:
                return "내보낼 항목이 없어요."
            case .archiveFailed(let reason):
                return "내보내기 파일을 만들지 못했어요.\n\(reason)"
            }
        }
    }

    /// 이미지 데이터의 매직 바이트로 실제 확장자를 고른다.
    /// 저장소는 확장자 없이 `.image`로 보관하므로, 내보낼 때 원래 형식을 되살려야 다른 앱에서 열린다.
    static func fileExtension(for data: Data) -> String {
        let bytes = [UInt8](data.prefix(12))
        if bytes.count >= 3, bytes[0] == 0xFF, bytes[1] == 0xD8, bytes[2] == 0xFF { return "jpg" }
        if bytes.count >= 8, Array(bytes[0..<8]) == [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A] { return "png" }
        if bytes.count >= 12, Array(bytes[4..<8]) == Array("ftyp".utf8) {
            let brand = String(decoding: bytes[8..<12], as: UTF8.self)
            if brand.hasPrefix("hei") || brand.hasPrefix("mif") || brand.hasPrefix("msf") { return "heic" }
        }
        return "img"
    }

    /// 공유 시트에 바로 넘길 수 있는 zip 하나를 만들어 URL을 돌려준다.
    static func makeArchive(captures: [Capture], store: CaptureStore) throws -> URL {
        guard !captures.isEmpty else { throw ExportError.nothingToExport }

        let fileManager = FileManager.default
        let stamp = Self.stampFormatter.string(from: Date())
        let folderName = "Shotchive-\(stamp)"
        let work = fileManager.temporaryDirectory
            .appendingPathComponent("export-\(UUID().uuidString)", isDirectory: true)
        let root = work.appendingPathComponent(folderName, isDirectory: true)
        let imagesDirectory = root.appendingPathComponent("images", isDirectory: true)
        try fileManager.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)

        let ordered = captures.sorted { $0.createdAt < $1.createdAt }
        var records: [Record] = []
        var markdown = "# Shotchive 내보내기\n\n"
        markdown += "\(Self.readableFormatter.string(from: Date())) · 항목 \(ordered.count)개\n\n"

        for (index, capture) in ordered.enumerated() {
            let sourceURL = store.imageURL(for: capture)
            guard let data = try? Data(contentsOf: sourceURL) else { continue }

            let name = String(format: "%04d-%@.%@",
                              index + 1,
                              Self.fileStampFormatter.string(from: capture.createdAt),
                              fileExtension(for: data))
            try data.write(to: imagesDirectory.appendingPathComponent(name), options: .atomic)

            let note = capture.note.trimmingCharacters(in: .whitespacesAndNewlines)
            records.append(Record(id: capture.id.uuidString,
                                  createdAt: capture.createdAt,
                                  note: note,
                                  image: "images/\(name)"))

            markdown += "## \(Self.readableFormatter.string(from: capture.createdAt))\n\n"
            markdown += note.isEmpty ? "_저장한 이유 없음_\n\n" : "\(note)\n\n"
            markdown += "![](images/\(name))\n\n"
        }

        guard !records.isEmpty else { throw ExportError.nothingToExport }

        try Data(markdown.utf8).write(to: root.appendingPathComponent("메모.md"), options: .atomic)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(records).write(to: root.appendingPathComponent("captures.json"), options: .atomic)

        return try zip(root, named: folderName)
    }

    /// 별도 라이브러리 없이 폴더를 zip으로 만든다. `.forUploading`이 이 용도로 제공되는 시스템 기능이다.
    private static func zip(_ directory: URL, named name: String) throws -> URL {
        var coordinatorError: NSError?
        var produced: URL?
        var copyError: Error?

        NSFileCoordinator().coordinate(
            readingItemAt: directory,
            options: [.forUploading],
            error: &coordinatorError
        ) { zipped in
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(name).zip")
            do {
                try? FileManager.default.removeItem(at: destination)
                try FileManager.default.copyItem(at: zipped, to: destination)
                produced = destination
            } catch {
                copyError = error
            }
        }

        if let coordinatorError { throw ExportError.archiveFailed(coordinatorError.localizedDescription) }
        if let copyError { throw ExportError.archiveFailed(copyError.localizedDescription) }
        guard let produced else { throw ExportError.archiveFailed("알 수 없는 오류") }
        return produced
    }

    private struct Record: Codable {
        let id: String
        let createdAt: Date
        let note: String
        let image: String
    }

    private static let stampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmm"
        return formatter
    }()

    private static let fileStampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()

    private static let readableFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter
    }()
}
