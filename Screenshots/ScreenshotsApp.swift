import SwiftUI
import UIKit

@main
struct ScreenshotsApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = LibraryModel()

    init() {
        UINavigationBar.appearance().largeTitleTextAttributes = [
            .font: UIFont.suit(size: 34, weight: .bold)
        ]
        UINavigationBar.appearance().titleTextAttributes = [
            .font: UIFont.suit(size: 17, weight: .semibold)
        ]
        UIBarButtonItem.appearance().setTitleTextAttributes(
            [.font: UIFont.suit(size: 17, weight: .medium)],
            for: .normal
        )
        UISegmentedControl.appearance().setTitleTextAttributes(
            [.font: UIFont.suit(size: 13, weight: .medium)],
            for: .normal
        )
    }

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environmentObject(model)
                .font(.suitBody)
                .tint(Color("AccentColor"))
                .task {
                    await model.prepareIfNeeded()
                    model.indexPendingTextIfNeeded()
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    model.reload()
                    model.indexPendingTextIfNeeded()
                }
        }
    }
}

@MainActor
final class LibraryModel: ObservableObject {
    @Published private(set) var captures: [Capture] = []
    @Published private(set) var missed: [MissedScreenshots.Item] = []
    /// 아직 글자를 읽지 않은 캡처 수. 0 이면 색인이 끝난 것이다.
    @Published private(set) var pendingTextIndex = 0
    @Published var presentedError: String?

    private var store: CaptureStore?
    private var hasPrepared = false
    private var indexingTask: Task<Void, Never>?

    init() {
        do {
            store = try CaptureStore()
        } catch {
            presentedError = "보관함을 열 수 없어요.\n\(error.localizedDescription)"
        }
    }

    func prepareIfNeeded() async {
        guard !hasPrepared else { return }
        hasPrepared = true
        if ProcessInfo.processInfo.arguments.contains("--demo") {
            seedDemoIfEmpty()
        }
        reload()
    }

    func reload() {
        guard let store else { return }
        do {
            captures = try store.all().sorted { $0.createdAt > $1.createdAt }
        } catch {
            presentedError = "저장된 스크린샷을 불러오지 못했어요.\n\(error.localizedDescription)"
        }
        rescanMissed()
        suggestions = ReasonSuggestions.from(captures)
        pendingTextIndex = captures.filter { $0.recognizedText == nil }.count
    }

    /// 자주 쓴 이유. 메모 입력 화면에서 버튼으로 꺼내 쓴다.
    @Published private(set) var suggestions: [String] = []

    // MARK: - 화면 속 글자 색인

    /// 아직 읽지 않은 캡처의 글자를 한 장씩 읽어 둔다.
    ///
    /// 저장할 때가 아니라 나중에 읽는다. 캡처 경로(App Intent)는 단축어 자동화의
    /// 실행 예산 안에서 돌고 이미 사진 색인을 최대 10초 기다리므로, 거기에 OCR 까지
    /// 얹으면 캡처를 잃을 위험이 커진다. 저장은 빠르게 끝내고 읽기는 앱이 맡는다.
    /// 이 필드가 생기기 전에 저장한 항목도 같은 경로로 소급해서 읽힌다.
    func indexPendingTextIfNeeded() {
        guard indexingTask == nil else { return }
        let targets = captures.filter { $0.recognizedText == nil }
        guard !targets.isEmpty else { return }

        indexingTask = Task { [weak self] in
            for capture in targets {
                if Task.isCancelled { break }
                guard let url = self?.imageURL(for: capture),
                      let data = try? Data(contentsOf: url)
                else { continue }
                // 한 장 읽는 데 수백 ms 가 걸린다. 메인 스레드 밖에서 읽고 결과만 올린다.
                let text = await Task.detached(priority: .utility) {
                    ScreenshotText.recognize(imageData: data)
                }.value
                guard let text else { continue }
                self?.storeRecognizedText(text, for: capture)
            }
            self?.finishIndexing()
        }
    }

    private func storeRecognizedText(_ text: String, for capture: Capture) {
        guard let store else { return }
        try? store.updateRecognizedText(capture, text: text)
        if let index = captures.firstIndex(where: { $0.id == capture.id }) {
            captures[index].recognizedText = text
            pendingTextIndex = max(0, pendingTextIndex - 1)
        }
    }

    private func finishIndexing() {
        indexingTask = nil
        reload()
    }

    // MARK: - 자동화가 건너뛴 캡처

    /// 사진 보관함을 훑어 아직 보관함에 없는 최근 스크린샷을 찾는다.
    /// `reload()` 안에서 불리므로 앱이 앞으로 올 때마다 갱신된다.
    func rescanMissed() {
        let ignoredBefore = UserDefaults.standard.object(
            forKey: MissedScreenshots.ignoredBeforeKey
        ) as? Date
        missed = MissedScreenshots.find(captures: captures, ignoredBefore: ignoredBefore)
    }

    /// 놓친 캡처 한 장을 메모와 함께 보관함에 넣는다.
    /// `createdAt` 은 저장 시각이 아니라 **촬영 시각**으로 둔다. 몇 시간 전에 찍은
    /// 것을 지금 들여왔을 때 월 묶음에서 엉뚱한 자리에 끼지 않게 하려는 것이다.
    @discardableResult
    func importMissed(_ item: MissedScreenshots.Item, note: String) async -> Bool {
        guard let store else {
            presentedError = "보관함을 사용할 수 없어요."
            return false
        }
        do {
            let data = try await MissedScreenshots.imageData(for: item.asset)
            _ = try store.save(
                imageData: data,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                createdAt: item.createdAt,
                assetLocalIdentifier: item.id
            )
            reload()
            return true
        } catch {
            presentedError = "스크린샷을 가져오지 못했어요.\n\(error.localizedDescription)"
            return false
        }
    }

    /// 지금 보이는 것들을 모두 넘긴다. 이 시각 이전은 다시 묻지 않는다.
    func ignoreAllMissed() {
        UserDefaults.standard.set(Date(), forKey: MissedScreenshots.ignoredBeforeKey)
        missed = []
    }

    @discardableResult
    func save(imageData: Data, note: String) -> Bool {
        guard let store else {
            presentedError = "보관함을 사용할 수 없어요."
            return false
        }
        do {
            _ = try store.save(imageData: imageData, note: note.trimmingCharacters(in: .whitespacesAndNewlines))
            reload()
            return true
        } catch {
            presentedError = "스크린샷을 저장하지 못했어요.\n\(error.localizedDescription)"
            return false
        }
    }

    @discardableResult
    func update(_ capture: Capture, note: String) -> Bool {
        guard let store else { return false }
        do {
            try store.update(capture, note: note.trimmingCharacters(in: .whitespacesAndNewlines))
            reload()
            return true
        } catch {
            presentedError = "메모를 저장하지 못했어요.\n\(error.localizedDescription)"
            return false
        }
    }

    @discardableResult
    func delete(_ capture: Capture) -> Bool {
        guard let store else { return false }
        do {
            try store.delete(capture)
            reload()
            return true
        } catch {
            presentedError = "항목을 삭제하지 못했어요.\n\(error.localizedDescription)"
            return false
        }
    }

    func imageURL(for capture: Capture) -> URL? {
        store?.imageURL(for: capture)
    }

    /// 보관함 전체를 zip 하나로 만든다. 파일 복사가 많으므로 메인 스레드 밖에서 처리한다.
    func makeExport() async -> URL? {
        guard store != nil else {
            presentedError = "보관함을 사용할 수 없어요."
            return nil
        }
        let items = captures
        do {
            return try await Task.detached(priority: .userInitiated) {
                let store = try CaptureStore()
                return try CaptureExporter.makeArchive(captures: items, store: store)
            }.value
        } catch {
            presentedError = error.localizedDescription
            return nil
        }
    }

    private func seedDemoIfEmpty() {
        guard let store, (try? store.all().isEmpty) == true else { return }
        let samples: [(String, String, UIColor)] = [
            ("읽고 싶은 문장", "주말에 다시 읽고 노트에 옮기기", .systemOrange),
            ("작업 아이디어", "다음 회의에서 온보딩 첫 화면에 적용", .systemIndigo),
            ("예약 정보", "금요일 오후 7시, 도착 10분 전 확인", .systemTeal)
        ]
        for (title, note, color) in samples {
            if let data = Self.demoImage(title: title, color: color) {
                _ = try? store.save(imageData: data, note: note)
            }
        }
    }

    private static func demoImage(title: String, color: UIColor) -> Data? {
        let size = CGSize(width: 780, height: 1_420)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.jpegData(withCompressionQuality: 0.88) { context in
            let cg = context.cgContext
            UIColor.systemBackground.setFill()
            cg.fill(CGRect(origin: .zero, size: size))
            color.withAlphaComponent(0.16).setFill()
            cg.fill(CGRect(x: 0, y: 0, width: size.width, height: 430))

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            (title as NSString).draw(
                in: CGRect(x: 70, y: 160, width: 640, height: 100),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 46, weight: .bold),
                    .foregroundColor: UIColor.label,
                    .paragraphStyle: paragraph
                ]
            )
            for index in 0..<5 {
                let width = index == 4 ? 360.0 : 610.0
                UIColor.secondarySystemFill.setFill()
                UIBezierPath(
                    roundedRect: CGRect(x: 70, y: 540 + CGFloat(index) * 110, width: width, height: 28),
                    cornerRadius: 14
                ).fill()
            }
        }
    }
}
