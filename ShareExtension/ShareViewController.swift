import SwiftUI
import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let model = ShareComposeModel()

    override func viewDidLoad() {
        super.viewDidLoad()

        let composeView = ShareComposeView(
            model: model,
            onSave: { [weak self] in self?.save() },
            onCancel: { [weak self] in self?.cancel() }
        )
        let host = UIHostingController(rootView: composeView)
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)

        loadSharedImage()
    }

    private func loadSharedImage() {
        let providers = (extensionContext?.inputItems as? [NSExtensionItem])?
            .flatMap { $0.attachments ?? [] } ?? []

        guard let provider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.image.identifier)
        }) else {
            model.show(error: "공유된 이미지가 없습니다.")
            return
        }

        provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self] data, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.model.show(error: "이미지를 불러오지 못했습니다: \(error.localizedDescription)")
                    return
                }
                guard let data, let image = UIImage(data: data) else {
                    self.model.show(error: "공유된 항목이 올바른 이미지가 아닙니다.")
                    return
                }
                self.model.imageData = data
                self.model.image = image
                self.model.isLoading = false
            }
        }
    }

    private func save() {
        save(note: model.note)
    }

    private func save(note: String) {
        guard !model.isSaving else { return }
        guard let imageData = model.imageData else {
            model.show(error: "이미지를 불러올 때까지 기다려 주세요.")
            return
        }

        model.isSaving = true
        do {
            let store = try CaptureStore()
            try store.save(imageData: imageData, note: note.trimmingCharacters(in: .whitespacesAndNewlines))
            finish()
        } catch {
            model.isSaving = false
            model.show(error: error.localizedDescription)
        }
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: nil)
    }

    private func cancel() {
        extensionContext?.cancelRequest(withError: NSError(
            domain: NSCocoaErrorDomain,
            code: NSUserCancelledError,
            userInfo: [NSLocalizedDescriptionKey: "공유가 취소되었습니다."]
        ))
    }
}

private final class ShareComposeModel: ObservableObject {
    @Published var note = ""
    @Published var image: UIImage?
    @Published var imageData: Data?
    @Published var isLoading = true
    @Published var isSaving = false
    @Published var errorMessage: String?

    func show(error: String) {
        errorMessage = error
        isLoading = false
    }
}

private struct ShareComposeView: View {
    @ObservedObject var model: ShareComposeModel
    let onSave: () -> Void
    let onCancel: () -> Void
    @FocusState private var noteIsFocused: Bool
    @State private var confirmingDiscard = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("예: 다음 회의에서 이 화면 참고", text: $model.note, axis: .vertical)
                        .font(.suitBody)
                        .lineLimit(3...8)
                        .focused($noteIsFocused)
                        .accessibilityLabel("저장한 이유")
                        .accessibilityIdentifier("share.note")
                } header: {
                    Text("왜 저장했나요?")
                } footer: {
                    Text("한 줄이면 충분해요. 비워두고 저장해도 괜찮아요.")
                }

                Section("스크린샷") {
                    Group {
                        if let image = model.image {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .accessibilityLabel("저장할 스크린샷 미리보기")
                        } else if model.isLoading {
                            ProgressView("이미지 불러오는 중…")
                        } else {
                            Label("이미지를 불러올 수 없어요", systemImage: "photo.badge.exclamationmark")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 220)
                    .padding(.vertical, 8)
                }

                if let error = model.errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(.suitCallout)
                            .foregroundStyle(.red)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("메모 남기기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        if model.note.isEmpty { onCancel() }
                        else { confirmingDiscard = true }
                    }
                    .disabled(model.isSaving)
                    .accessibilityIdentifier("share.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: onSave) {
                        if model.isSaving { ProgressView() }
                        else { Text("저장").fontWeight(.semibold) }
                    }
                    .disabled(model.imageData == nil || model.isSaving)
                    .accessibilityIdentifier("share.save")
                }
            }
            .confirmationDialog("작성한 메모를 버릴까요?", isPresented: $confirmingDiscard, titleVisibility: .visible) {
                Button("메모 버리기", role: .destructive, action: onCancel)
                Button("계속 작성", role: .cancel) {}
            }
            .onChange(of: model.image) { _, image in
                if image != nil { noteIsFocused = true }
            }
        }
        .interactiveDismissDisabled(!model.note.isEmpty || model.isSaving)
        .font(.suitBody)
        .tint(Color("AccentColor"))
    }
}
