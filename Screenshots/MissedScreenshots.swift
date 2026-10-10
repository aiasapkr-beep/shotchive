import Foundation
import Photos

/// 자동화가 건너뛴 스크린샷을 사진 보관함에서 되찾는다.
///
/// 캡처 직후 메모 입력창이 뜨지 않는 경우가 간헐적으로 있다. 원인은 세 가지인데
/// 어느 쪽이든 앱이 손쓸 수 있는 단계를 이미 지나 있다.
///
/// 1. iOS 가 단축어 자동화를 아예 실행하지 않는다. 저전력 모드, 메모리 압박,
///    백그라운드 실행 예산 소진 등. 앱 코드로 막을 방법이 없다.
/// 2. 자동화는 돌았지만 `requestValue` 가 입력창을 띄우지 못한다.
///    이때 캡처는 메모 없이 저장된다.
/// 3. 사진 접근이 `전체 허용` 이 아니라 인텐트가 시작하자마자 throw 한다.
///
/// 그래서 원인을 쫓는 대신 결과를 회수한다. **세 경우 모두 스크린샷 자체는
/// 사진 보관함에 남아 있다.** 마지막으로 보관한 캡처 이후에 찍힌 스크린샷 중
/// 아직 보관함에 없는 것을 찾아 주면, 원인이 무엇이든 사용자가 복구할 수 있다.
enum MissedScreenshots {
    struct Item: Identifiable, Equatable {
        let id: String
        let asset: PHAsset
        let createdAt: Date

        static func == (lhs: Item, rhs: Item) -> Bool { lhs.id == rhs.id }
    }

    /// 새로 설치했거나 오래 안 썼을 때 수백 장이 쏟아지지 않도록 하는 상한.
    static let lookbackDays = 14
    static let maxItems = 60

    /// 이 시각 이전은 사용자가 이미 "무시"한 것으로 본다.
    static let ignoredBeforeKey = "missedScreenshotsIgnoredBefore"

    /// 아직 보관함에 없는 최근 스크린샷. 최신이 앞에 온다.
    ///
    /// - Parameters:
    ///   - captures: 현재 보관함의 전체 항목. 중복 제외에 쓴다.
    ///   - ignoredBefore: 사용자가 "무시"를 누른 시각. 없으면 nil.
    static func find(captures: [Capture], ignoredBefore: Date?) -> [Item] {
        guard PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized else { return [] }

        let floor = Date().addingTimeInterval(-Double(lookbackDays) * 24 * 60 * 60)
        // 보관함의 `createdAt` 은 저장한 시각이지 촬영 시각이 아니다. 둘은 보통
        // 몇 초 차이지만 같지는 않으므로, 가장 최근 저장분보다 조금 앞에서부터
        // 훑고 실제 중복 판정은 식별자·촬영 시각으로 한다.
        let newestSaved = captures.map(\.createdAt).max()?.addingTimeInterval(-matchTolerance)
        let since = [floor, newestSaved, ignoredBefore].compactMap { $0 }.max() ?? floor

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = maxItems
        #if targetEnvironment(simulator)
        // 시뮬레이터 캡처는 Mac에 저장되고 `simctl addmedia` 로 넣은 것은 평범한
        // 이미지로 들어와 photoScreenshot 이 아니다. 인텐트도 같은 이유로 같은
        // 예외를 둔다. 실기기 빌드에는 들어가지 않는다.
        options.predicate = NSPredicate(format: "creationDate > %@", since as NSDate)
        #else
        options.predicate = NSPredicate(
            format: "(mediaSubtype & %d) != 0 AND creationDate > %@",
            PHAssetMediaSubtype.photoScreenshot.rawValue,
            since as NSDate
        )
        #endif

        let knownIdentifiers = Set(captures.compactMap(\.assetLocalIdentifier))
        // 식별자를 남기기 전에 저장한 항목은 촬영 시각으로 대조할 수밖에 없다.
        let legacyDates = captures.filter { $0.assetLocalIdentifier == nil }.map(\.createdAt)

        var found: [Item] = []
        PHAsset.fetchAssets(with: .image, options: options).enumerateObjects { asset, _, _ in
            guard let createdAt = asset.creationDate else { return }
            guard !knownIdentifiers.contains(asset.localIdentifier) else { return }
            guard !legacyDates.contains(where: { abs($0.timeIntervalSince(createdAt)) <= matchTolerance })
            else { return }
            found.append(Item(id: asset.localIdentifier, asset: asset, createdAt: createdAt))
        }
        return found
    }

    /// 촬영과 저장 사이의 시간차 허용폭. 인텐트는 사진 앱 색인을 최대 10초까지
    /// 기다리므로 그보다 넉넉해야 같은 장을 두 번 들여오지 않는다.
    static let matchTolerance: TimeInterval = 20

    static func imageData(for asset: PHAsset) async throws -> Data {
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
                    continuation.resume(throwing: MissedScreenshotError.imageUnavailable)
                }
            }
        }
    }
}

enum MissedScreenshotError: LocalizedError {
    case imageUnavailable

    var errorDescription: String? {
        switch self {
        case .imageUnavailable:
            return "사진 보관함에서 이미지를 불러오지 못했어요."
        }
    }
}
