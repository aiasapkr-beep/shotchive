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
                .task { await model.prepareIfNeeded() }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    model.reload()
                }
        }
    }
}

@MainActor
final class LibraryModel: ObservableObject {
    @Published private(set) var captures: [Capture] = []
    @Published var presentedError: String?

    private var store: CaptureStore?
    private var hasPrepared = false

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
