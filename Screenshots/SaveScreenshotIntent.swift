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

    // 캡처 직후 입력창은 단축어가 그리는 시스템 UI라 우리가 버튼을 넣을 수 없다.
    // 대신 optionsProvider 로 자주 쓴 이유를 그 입력창에 제안한다 — 고르면 끝이고,
    // 새로 칠 수도 있다. 단계가 늘지 않으므로 입력창이 안 뜨는 위험도 늘지 않는다.
    @Parameter(title: "저장한 이유", optionsProvider: FrequentReasonsProvider())
    var note: String?

    static var parameterSummary: some ParameterSummary {
        Summary("최근 스크린샷에 \(\.$note) 메모")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // 접근이 '전체 허용' 이 아니면 방금 찍은 캡처를 찾을 수 없다. 아직 존재하지도
        // 않는 사진을 사용자가 미리 선택해 둘 수는 없기 때문이다. 묻기 전에 끝내되,
        // 어디를 어떻게 바꿔야 하는지는 분명히 말한다.
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized:
            break
        case .limited:
            throw LatestScreenshotError.photoAccessLimited
        default:
            throw LatestScreenshotError.photoAccessRequired
        }

        // 이유를 먼저 묻는다. 사진 보관함 색인이 늦는 앱(인스타그램 등)에서 캡처를 찾느라
        // 시간이 걸려도 입력창은 즉시 떠야 한다. 찾기를 먼저 하면 실패했을 때
        // 입력창조차 뜨지 않아 사용자는 아무 반응도 보지 못한다.
        var text = Self.cleaned(note)
        if text == nil,
           let answered = try? await $note.requestValue(IntentDialog("왜 저장했나요?")) {
            text = Self.cleaned(answered)
        }

        let asset = try await Self.findRecentScreenshot()
        let imageData = try await Self.imageData(for: asset)
        let store = try CaptureStore()
        // 에셋 식별자를 함께 남긴다. 자동화가 건너뛴 캡처를 앱이 나중에 찾아 줄 때
        // 이미 보관한 장을 두 번 들여오지 않기 위한 표식이다(`MissedScreenshots`).
        _ = try store.save(
            imageData: imageData,
            note: text ?? "",
            assetLocalIdentifier: asset.localIdentifier
        )

        return .result(dialog: text == nil
            ? "메모 없이 저장했어요. 앱에서 나중에 적을 수 있어요."
            : "방금 스크린샷과 이유를 저장했어요.")
    }

    private static func cleaned(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }

    private static func findRecentScreenshot() async throws -> PHAsset {
        // The screenshot automation can fire before Photos finishes indexing the new asset.
        // Wait briefly instead of immediately pairing the note with an older screenshot.
        // 무거운 앱에서 캡처한 직후에는 사진 앱이 색인하는 데 몇 초가 걸린다.
        // 짧게 포기하면 캡처를 놓치므로 약 10초까지 기다린다.
        for attempt in 0..<14 {
            try await Task.sleep(nanoseconds: attempt == 0 ? 250_000_000 : 750_000_000)

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

/// 보관함에 이미 있는 메모에서 자주 쓴 것을 세어 제안한다. 따로 저장하는 목록이 없어
/// 쓰는 대로 따라오고, 관리할 상태가 늘지 않는다(`ReasonSuggestions`).
struct FrequentReasonsProvider: DynamicOptionsProvider {
    func results() async throws -> [String] {
        guard let store = try? CaptureStore(), let captures = try? store.all() else { return [] }
        return ReasonSuggestions.from(captures)
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
    case photoAccessLimited
    case screenshotNotFound
    case imageUnavailable

    var errorDescription: String? {
        switch self {
        case .photoAccessRequired:
            return "Shotchive 앱에서 사진 접근을 먼저 허용해 주세요."
        case .photoAccessLimited:
            return "사진 접근이 '제한됨' 으로 되어 있어요. 설정 > 앱 > Shotchive > 사진에서 '전체 접근 허용'을 선택해 주세요. 방금 찍은 스크린샷은 미리 선택해 둘 수 없어서 제한된 접근으로는 찾을 수 없어요."
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
