import AppIntents
import Photos
import UniformTypeIdentifiers

struct SaveScreenshotIntent: AppIntent {
    static var title: LocalizedStringResource = "스크린샷과 메모 저장"
    static var description = IntentDescription("전달받은 이미지와 저장 이유를 Shotchive에 함께 보관합니다.")
    static var openAppWhenRun = false

    @Parameter(title: "스크린샷")
    var screenshot: IntentFile

    @Parameter(title: "저장한 이유")
    var note: String?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = try CaptureStore()
        _ = try store.save(imageData: screenshot.data, note: note ?? "")
        return .result(dialog: "스크린샷과 메모를 저장했어요.")
    }
}

struct SaveLatestScreenshotIntent: AppIntent {
    static var title: LocalizedStringResource = "최근 스크린샷에 메모"
    static var description = IntentDescription("방금 저장된 스크린샷을 Shotchive에 보관하고 저장한 이유를 묻습니다. 이유를 적지 않아도 캡처는 저장됩니다.")
    static var openAppWhenRun = false

    @Parameter(title: "저장한 이유")
    var note: String?

    static var parameterSummary: some ParameterSummary {
        Summary("최근 스크린샷에 \(\.$note) 메모")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized else {
            throw LatestScreenshotError.photoAccessRequired
        }

        let asset = try await Self.findRecentScreenshot()
        let imageData = try await Self.imageData(for: asset)
        let store = try CaptureStore()

        // 이유를 묻기 전에 먼저 저장한다. 입력을 취소하거나 놓쳐도 캡처 자체는 남아야 한다.
        let capture = try store.save(imageData: imageData, note: Self.cleaned(note) ?? "")

        if Self.cleaned(note) != nil {
            return .result(dialog: "방금 스크린샷과 이유를 저장했어요.")
        }

        if let answered = try? await $note.requestValue(IntentDialog("왜 저장했나요?")),
           let text = Self.cleaned(answered) {
            try? store.update(capture, note: text)
            return .result(dialog: "방금 스크린샷과 이유를 저장했어요.")
        }

        return .result(dialog: "메모 없이 저장했어요. 앱에서 나중에 적을 수 있어요.")
    }

    private static func cleaned(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }

    private static func findRecentScreenshot() async throws -> PHAsset {
        // The screenshot automation can fire before Photos finishes indexing the new asset.
        // Wait briefly instead of immediately pairing the note with an older screenshot.
        for attempt in 0..<6 {
            try await Task.sleep(nanoseconds: attempt == 0 ? 250_000_000 : 500_000_000)

            if let screenshot = fetchNewestScreenshot(), isRecent(screenshot) {
                return screenshot
            }

            #if targetEnvironment(simulator)
            // Simulator screenshots are normally saved to the Mac. `simctl addmedia` imports
            // them as ordinary images, so accept a very recent image only in simulator builds.
            if let image = fetchNewestImage(), isRecent(image) {
                return image
            }
            #endif
        }

        throw LatestScreenshotError.screenshotNotFound
    }

    private static func fetchNewestScreenshot() -> PHAsset? {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 1
        fetchOptions.predicate = NSPredicate(
            format: "(mediaSubtype & %d) != 0",
            PHAssetMediaSubtype.photoScreenshot.rawValue
        )
        return PHAsset.fetchAssets(with: .image, options: fetchOptions).firstObject
    }

    #if targetEnvironment(simulator)
    private static func fetchNewestImage() -> PHAsset? {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 1
        return PHAsset.fetchAssets(with: .image, options: fetchOptions).firstObject
    }
    #endif

    private static func isRecent(_ asset: PHAsset) -> Bool {
        guard let creationDate = asset.creationDate else { return false }
        return creationDate >= Date().addingTimeInterval(-10 * 60)
    }

    private static func imageData(for asset: PHAsset) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.version = .current
            options.isNetworkAccessAllowed = true

            PHImageManager.default().requestImageDataAndOrientation(
                for: asset,
                options: options
            ) { data, _, _, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                } else if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: LatestScreenshotError.imageUnavailable)
                }
            }
        }
    }
}

struct ScreenshotsAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SaveLatestScreenshotIntent(),
            phrases: [
                "\(.applicationName)에 최근 스크린샷 저장",
                "\(.applicationName)에 스크린샷 메모"
            ],
            shortTitle: "최근 스크린샷 메모",
            systemImageName: "rectangle.and.pencil.and.ellipsis"
        )
    }

    static var shortcutTileColor: ShortcutTileColor = .navy
}

private enum LatestScreenshotError: LocalizedError {
    case photoAccessRequired
    case screenshotNotFound
    case imageUnavailable

    var errorDescription: String? {
        switch self {
        case .photoAccessRequired:
            return "Shotchive 앱에서 사진 접근을 먼저 허용해 주세요."
        case .screenshotNotFound:
            #if targetEnvironment(simulator)
            return "시뮬레이터의 사진 앱에 최근 이미지가 없어요. 시뮬레이터 캡처는 Mac에 저장되므로 사진 앱에 이미지를 먼저 추가해 주세요."
            #else
            return "사진 보관함에서 최근 스크린샷을 찾지 못했어요."
            #endif
        case .imageUnavailable:
            return "최근 스크린샷 이미지를 불러오지 못했어요."
        }
    }
}
