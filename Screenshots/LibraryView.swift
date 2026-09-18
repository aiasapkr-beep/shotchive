import AVFoundation
import AVKit
import PhotosUI
import Photos
import SwiftUI
import UIKit

struct LibraryView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var model: LibraryModel
    @State private var searchText = ""
    @State private var filter: LibraryFilter = .all
    @State private var showingComposer = false
    @State private var showingHelp = false
    @State private var exportArchive: ExportArchive?
    @State private var isExporting = false
    @AppStorage("automationSetupAcknowledged") private var automationSetupAcknowledged = false
    @AppStorage("automationLandingDismissed") private var automationLandingDismissed = false

    private var showsAutomationOnboarding: Bool {
        !automationSetupAcknowledged && !automationLandingDismissed
    }

    private var visibleCaptures: [Capture] {
        model.captures.filter { capture in
            let matchesFilter = filter == .all || capture.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let matchesSearch = searchText.isEmpty || capture.note.localizedCaseInsensitiveContains(searchText)
            return matchesFilter && matchesSearch
        }
    }

    /// 사진·메모 앱처럼 달 단위로 묶는다. 올해 것은 ‘5월’, 지난 해 것은 ‘2025년 5월’.
    private var monthlyGroups: [CaptureMonth] {
        let calendar = Calendar.current
        let thisYear = calendar.component(.year, from: Date())
        let buckets = Dictionary(grouping: visibleCaptures) { capture in
            calendar.date(from: calendar.dateComponents([.year, .month], from: capture.createdAt)) ?? capture.createdAt
        }
        return buckets.keys.sorted(by: >).map { month in
            let parts = calendar.dateComponents([.year, .month], from: month)
            let year = parts.year ?? thisYear
            let title = year == thisYear ? "\(parts.month ?? 1)월" : "\(year)년 \(parts.month ?? 1)월"
            return CaptureMonth(id: month, title: title, captures: buckets[month] ?? [])
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if model.captures.isEmpty {
                    EmptyLibraryView(addAction: { showingComposer = true }, helpAction: { showingHelp = true })
                } else {
                    List {
                        Section {
                            if dynamicTypeSize.isAccessibilitySize {
                                Picker("보기", selection: $filter) {
                                    ForEach(LibraryFilter.allCases) { item in
                                        Text(item.title).tag(item)
                                    }
                                }
                                .pickerStyle(.menu)
                                .accessibilityLabel("보관함 필터")
                            } else {
                                Picker("필터", selection: $filter) {
                                    ForEach(LibraryFilter.allCases) { item in
                                        Text(item.title).tag(item)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .accessibilityLabel("보관함 필터")
                            }
                        } footer: {
                            Text("\(visibleCaptures.count)개 · 저장한 이유를 기준으로 다시 찾을 수 있어요.")
                        }

                        if visibleCaptures.isEmpty {
                            Section {
                                SearchEmptyView(query: searchText)
                                    .listRowBackground(Color.clear)
                                    .listRowInsets(EdgeInsets(top: 40, leading: 16, bottom: 40, trailing: 16))
                            }
                        } else {
                            ForEach(monthlyGroups) { group in
                                Section {
                                    ForEach(group.captures) { capture in
                                        NavigationLink {
                                            CaptureDetailView(capture: capture)
                                        } label: {
                                            CaptureRow(capture: capture, imageURL: model.imageURL(for: capture))
                                        }
                                        .accessibilityIdentifier("library.capture.\(capture.id.uuidString)")
                                    }
                                } header: {
                                    Text(group.title)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("보관함")
            .searchable(text: $searchText, prompt: "메모 검색")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showingHelp = true } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .accessibilityLabel("사용 방법")
                    .accessibilityIdentifier("library.help")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showingComposer = true } label: {
                        Label("추가", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        startExport()
                    } label: {
                        if isExporting {
                            ProgressView()
                        } else {
                            Image(systemName: "square.and.arrow.up.on.square")
                        }
                    }
                    .disabled(model.captures.isEmpty || isExporting)
                    .accessibilityLabel("내보내기")
                    .accessibilityIdentifier("library.export")
                }
            }
            .sheet(item: $exportArchive) { archive in
                ActivityView(items: [archive.url])
            }
            .sheet(isPresented: $showingComposer) {
                CaptureComposer()
            }
            .sheet(isPresented: $showingHelp) {
                HelpView(automationSetupAcknowledged: $automationSetupAcknowledged)
            }
            .fullScreenCover(isPresented: Binding(
                get: { showsAutomationOnboarding },
                set: { _ in }
            )) {
                SetupOnboardingView(
                    automationSetupAcknowledged: $automationSetupAcknowledged,
                    laterAction: { automationLandingDismissed = true }
                )
                .interactiveDismissDisabled()
            }
            .alert("문제가 생겼어요", isPresented: Binding(
                get: { model.presentedError != nil },
                set: { if !$0 { model.presentedError = nil } }
            )) {
                Button("확인", role: .cancel) { model.presentedError = nil }
            } message: {
                Text(model.presentedError ?? "")
            }
        }
    }
}

extension LibraryView {
    fileprivate func startExport() {
        guard !isExporting else { return }
        isExporting = true
        Task {
            let url = await model.makeExport()
            isExporting = false
            if let url { exportArchive = ExportArchive(url: url) }
        }
    }
}

private struct ExportArchive: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

private struct SetupOnboardingView: View {
    @Binding var automationSetupAcknowledged: Bool
    let laterAction: () -> Void
    @AppStorage("shortcutOnboardingStep") private var step = 0
    @State private var photoAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    static let demoVideoURL = Bundle.main.url(forResource: "automation-demo", withExtension: "mp4")

    @State private var showingDemo = false


    var body: some View {
        Group {
            if step == 0 {
                introduction
            } else {
                setupWizard
            }
        }
        .animation(.snappy, value: step)
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            photoAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        }
    }

    private var introduction: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    Spacer(minLength: 28)

                    Image(systemName: "rectangle.and.pencil.and.ellipsis")
                        .font(.system(size: 54, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 112, height: 112)
                        .background(Color("AccentColor"), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .accessibilityHidden(true)

                    VStack(spacing: 12) {
                        Text("버튼 한 번으로\n캡처하고 이유까지")
                            .font(.suitLargeTitleBold)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("동작 버튼이나 뒷면 탭에 단축어를 걸면 한 번의 동작으로 캡처와 메모 입력이 이어집니다.")
                            .font(.suitBody)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: 8) {
                        FlowBadge(icon: "camera.fill", title: "캡처")
                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        FlowBadge(icon: "text.bubble.fill", title: "메모")
                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        FlowBadge(icon: "tray.full.fill", title: "보관")
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("캡처, 메모, 보관 순서")

                    VStack(spacing: 10) {
                        Button {
                            step = 1
                        } label: {
                            Text("설정 시작 · 2단계")
                                .font(.suitBodySemibold)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .accessibilityIdentifier("setupLanding.setup")

                        Button(action: laterAction) {
                            Text("나중에")
                                .font(.suitBodySemibold)
                                .foregroundStyle(Color("AccentColor"))
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("setupLanding.later")
                    }

                    Text("설정 없이 쓰려면 캡처 미리보기의 공유 버튼에서 Shotchive를 선택하면 됩니다. 설정하는 동안 앱을 오가도 보던 단계가 유지돼요.")
                        .font(.suitFootnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 12)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
        }
    }

    private var setupWizard: some View {
        let safeStep = min(max(step, 1), AutomationSetupStep.steps.count)
        let current = AutomationSetupStep.steps[safeStep - 1]

        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ProgressView(value: Double(safeStep), total: Double(AutomationSetupStep.steps.count))
                        .tint(Color("AccentColor"))
                        .accessibilityLabel("설정 진행률")
                        .accessibilityValue("\(safeStep)단계 중 \(AutomationSetupStep.steps.count)단계")

                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: current.icon)
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(Color("AccentColor"))
                            .frame(width: 64, height: 64)
                            .background(Color("AccentColor").opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .accessibilityHidden(true)

                        Text(current.title)
                            .font(.suitLargeTitleBold)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(current.detail)
                            .font(.suitBody)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if safeStep == 2, let demoURL = Self.demoVideoURL {
                        AutomationDemoCard(url: demoURL) {
                            withAnimation(.easeOut(duration: 0.2)) { showingDemo = true }
                        }
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(current.actions.enumerated()), id: \.offset) { index, action in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.suitSubheadlineBold)
                                    .foregroundStyle(.white)
                                    .frame(width: 28, height: 28)
                                    .background(Color("AccentColor"), in: Circle())

                                Text(action)
                                    .font(.suitBody)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.vertical, 14)

                            if index < current.actions.count - 1 {
                                Divider().padding(.leading, 40)
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .background(.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))


                    if let tip = current.tip {
                        Label(tip, systemImage: "lightbulb.fill")
                            .font(.suitSubheadline)
                            .foregroundStyle(.secondary)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color("AccentColor").opacity(0.09), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .padding(24)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("설정 \(safeStep)/\(AutomationSetupStep.steps.count)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(safeStep == 1 ? "처음으로" : "이전") { step = safeStep - 1 }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("나중에", action: laterAction)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    if safeStep == 1 {
                        if photoAuthorizationStatus == .authorized {
                            Label("사진 접근 허용됨", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .frame(maxWidth: .infinity, minHeight: 44)

                            Button {
                                step = 2
                            } label: {
                                Text("다음")
                                    .font(.suitBodySemibold)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .accessibilityIdentifier("onboarding.next")
                        } else if photoAuthorizationStatus == .denied || photoAuthorizationStatus == .restricted || photoAuthorizationStatus == .limited {
                            Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                                Label("설정에서 모든 사진 허용", systemImage: "gear")
                                    .font(.suitBodySemibold)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .accessibilityIdentifier("onboarding.openSettings")
                        } else {
                            Button {
                                Task {
                                    photoAuthorizationStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
                                    if photoAuthorizationStatus == .authorized { step = 2 }
                                }
                            } label: {
                                Label("사진 접근 허용", systemImage: "photo.badge.checkmark")
                                    .font(.suitBodySemibold)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .accessibilityIdentifier("onboarding.allowPhotos")
                        }

                        Button {
                            laterAction()
                        } label: {
                            Text("사진 권한 없이 사용")
                                .font(.suitSubheadline)
                                .foregroundStyle(Color("AccentColor"))
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("공유 메뉴를 이용하는 기본 보관함으로 이동합니다")
                    } else {
                        Button {
                            openURL(URL(string: "shortcuts://automations")!)
                        } label: {
                            Label("단축어 ‘자동화’ 탭 열기", systemImage: "arrow.up.forward.app")
                                .font(.suitBodySemibold)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .accessibilityIdentifier("onboarding.openShortcuts")

                        Button {
                            step = 0
                            automationSetupAcknowledged = true
                        } label: {
                            Text("설정 완료")
                                .font(.suitBodySemibold)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .accessibilityIdentifier("onboarding.next")
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(.bar)
            }
        }
        .overlay {
            if showingDemo, let demoURL = Self.demoVideoURL {
                AutomationDemoPopup(url: demoURL) {
                    withAnimation(.easeOut(duration: 0.18)) { showingDemo = false }
                }
                .transition(.opacity)
            }
        }
    }
}

/// 온보딩 2단계의 실제 조작 데모. 소리 없이 반복 재생하고, 누르면 전체 화면으로 키운다.
private struct AutomationDemoCard: View {
    let url: URL
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(spacing: 10) {
                LoopingVideoView(url: url)
                    .frame(height: 320)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                Label("눌러서 크게 보기", systemImage: "arrow.up.left.and.arrow.down.right")
                    .font(.suitSubheadline)
                    .foregroundStyle(Color("AccentColor"))
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityLabel("설정 과정 동영상. 눌러서 크게 보기")
        .accessibilityIdentifier("onboarding.demoVideo")
    }
}

/// 전체 화면 대신 어두워진 배경 위에 뜨는 팝업. 뒤 화면이 비쳐 보여 맥락을 잃지 않는다.
private struct AutomationDemoPopup: View {
    let url: URL
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.62)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)

            VStack(spacing: 16) {
                LoopingVideoView(url: url)
                    .aspectRatio(540.0 / 1108.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .black.opacity(0.4), radius: 24, y: 10)

                Button(action: onClose) {
                    Text("닫기")
                        .font(.suitBodySemibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 28)
                        .frame(minHeight: 44)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .accessibilityIdentifier("onboarding.demoClose")
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 32)
        }
    }
}

private struct LoopingVideoView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> LoopingPlayerUIView { LoopingPlayerUIView(url: url) }
    func updateUIView(_ uiView: LoopingPlayerUIView, context: Context) {}
    static func dismantleUIView(_ uiView: LoopingPlayerUIView, coordinator: ()) { uiView.pause() }
}

final class LoopingPlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    private let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?

    init(url: URL) {
        super.init(frame: .zero)
        backgroundColor = .black
        let layer = self.layer as? AVPlayerLayer
        layer?.player = player
        layer?.videoGravity = .resizeAspect
        player.isMuted = true
        // 오디오 세션을 건드리지 않도록 무음 재생만 한다. 다른 앱 음악을 끊지 않는다.
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        player.play()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func pause() { player.pause() }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { player.play() }
    }
}

private struct FlowBadge: View {
    let icon: String
    let title: String

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: icon)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color("AccentColor"))
                .frame(width: 52, height: 52)
                .background(.background, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            Text(title).font(.suitCaptionSemibold)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct AutomationSetupStep {
    let icon: String
    let title: String
    let detail: String
    let actions: [String]
    let tip: String?

    static let steps: [AutomationSetupStep] = {
        var photoActions = [
            "아래 버튼을 누르고 ‘전체 접근 허용’을 선택하세요.",
            "앱은 가장 최근 스크린샷 한 장만 복사해 메모와 함께 보관합니다."
        ]
        #if targetEnvironment(simulator)
        photoActions.append("시뮬레이터 캡처는 Mac에 저장됩니다. 테스트할 이미지는 사진 앱으로 먼저 드래그해 넣어 주세요.")
        #endif

        return [
        AutomationSetupStep(
            icon: "photo.badge.checkmark",
            title: "최근 스크린샷만 찾도록 허용해요",
            detail: "자동화가 방금 저장된 스크린샷을 가져올 때 사용합니다. 사진은 기기 밖으로 전송되지 않아요.",
            actions: photoActions,
            tip: "‘접근 제한…’을 고르면 다음 스크린샷을 자동으로 찾을 수 없어요."
        ),
        AutomationSetupStep(
            icon: "bolt.fill",
            title: "‘자동화’ 탭에 동작 하나만 추가해요",
            detail: "보관함에 만든 단축어는 직접 눌러야 실행됩니다. 캡처 버튼에 반응하려면 반드시 자동화로 만들어야 해요.",
            actions: [
                "맨 아래 가운데 ‘+’를 누르세요.",
                "오른쪽 위 ‘편집’을 누르세요.",
                "검색창의 ‘자동화’ 칩을 누르고 ‘스크린샷’을 고르세요.",
                "‘최근 스크린샷에 메모’를 찾아 추가하면 끝이에요."
            ],
            tip: nil
        )
        ]
    }()
}

private struct CaptureMonth: Identifiable {
    let id: Date
    let title: String
    let captures: [Capture]
}

private enum LibraryFilter: String, CaseIterable, Identifiable {
    case all, unnoted
    var id: Self { self }
    var title: String { self == .all ? "전체" : "메모 없음" }
}

private struct CaptureRow: View {
    let capture: Capture
    let imageURL: URL?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    thumbnail
                    rowText
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    thumbnail
                    rowText
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var thumbnail: some View {
        LocalCaptureImage(url: imageURL, contentMode: .fill)
            .frame(width: 72, height: 72, alignment: .top)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityHidden(true)
    }

    private var rowText: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(capture.note.isEmpty ? "저장한 이유 없음" : capture.note)
                .font(capture.note.isEmpty ? .suitBody : .suitBodySemibold)
                .foregroundStyle(capture.note.isEmpty ? .secondary : .primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Text(capture.createdAt, format: .dateTime.year().month().day().hour().minute())
                .font(.suitCaption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct LocalCaptureImage: View {
    let url: URL?
    var contentMode: ContentMode = .fill

    var body: some View {
        Group {
            if let url, let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                ZStack {
                    Color(uiColor: .tertiarySystemFill)
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct EmptyLibraryView: View {
    let addAction: () -> Void
    let helpAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color("AccentColor"))
            Text("기억할 이유를 남겨요")
                .font(.suitTitle2Bold)
            Text("스크린샷과 함께 ‘왜 저장했는지’를 적어두면 나중에 바로 찾을 수 있어요.")
                .font(.suitBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            VStack(spacing: 12) {
                Button("첫 스크린샷 추가", action: addAction)
                    .buttonStyle(.borderedProminent)
                Button("빠르게 저장하는 방법", action: helpAction)
                    .font(.suitSubheadline)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

private struct SearchEmptyView: View {
    let query: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("찾는 항목이 없어요")
                .font(.suitHeadline)
            Text(query.isEmpty ? "다른 필터를 선택해 보세요." : "‘\(query)’와 일치하는 메모가 없어요.")
                .font(.suitSubheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct CaptureComposer: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var model: LibraryModel
    @State private var selectedItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var isLoading = false
    @State private var note = ""
    @State private var importError: String?
    @State private var saveError: String?
    @State private var confirmingDiscard = false
    @FocusState private var noteFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("예: 다음 회의에서 다시 보기", text: $note, axis: .vertical)
                        .lineLimit(3...7)
                        .focused($noteFocused)
                        .accessibilityIdentifier("composer.note")
                } header: {
                    Text("왜 저장하나요?")
                } footer: {
                    Text("메모는 비워두고 나중에 작성해도 돼요.")
                }

                Section {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        if let imageData, let image = UIImage(data: imageData) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: 220)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .accessibilityLabel("선택한 스크린샷")
                        } else {
                            Label(isLoading ? "불러오는 중…" : "사진에서 스크린샷 선택", systemImage: "photo.badge.plus")
                                .frame(maxWidth: .infinity, minHeight: 100)
                        }
                    }
                    .disabled(isLoading)
                    .accessibilityIdentifier("composer.import")
                }

            }
            .navigationTitle("스크린샷 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { requestDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        guard let imageData else { return }
                        if model.save(imageData: imageData, note: note) {
                            dismiss()
                        } else {
                            saveError = model.presentedError ?? "스크린샷을 저장하지 못했어요."
                            model.presentedError = nil
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(imageData == nil || isLoading)
                    .accessibilityIdentifier("composer.save")
                }
            }
            .interactiveDismissDisabled(hasDraft)
            .onChange(of: selectedItem) { _, item in
                guard let item else { return }
                isLoading = true
                Task {
                    do {
                        guard let data = try await item.loadTransferable(type: Data.self), UIImage(data: data) != nil else {
                            throw ImportError.invalidImage
                        }
                        imageData = data
                        noteFocused = true
                    } catch {
                        importError = "다른 사진을 선택해 주세요."
                    }
                    isLoading = false
                }
            }
            .alert("이미지를 불러올 수 없어요", isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )) {
                Button("확인", role: .cancel) { importError = nil }
            } message: {
                Text(importError ?? "")
            }
            .alert("저장할 수 없어요", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("확인", role: .cancel) { saveError = nil }
            } message: {
                Text(saveError ?? "")
            }
            .confirmationDialog("작성 중인 내용을 버릴까요?", isPresented: $confirmingDiscard, titleVisibility: .visible) {
                Button("버리기", role: .destructive) { dismiss() }
                Button("계속 작성", role: .cancel) {}
            }
        }
    }

    private var hasDraft: Bool { imageData != nil || !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private func requestDismiss() { hasDraft ? (confirmingDiscard = true) : dismiss() }

    private enum ImportError: Error { case invalidImage }
}

private struct CaptureDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var model: LibraryModel
    let capture: Capture
    @State private var confirmingDelete = false
    @State private var showingNoteEditor = false
    @State private var displayedNote: String
    @State private var shareItem: ShareItem?

    init(capture: Capture) {
        self.capture = capture
        _displayedNote = State(initialValue: capture.note)
    }

    var body: some View {
        List {
            Section("저장한 이유") {
                Button { showingNoteEditor = true } label: {
                    HStack(alignment: .firstTextBaseline) {
                        Text(displayedNote.isEmpty ? "이유를 추가하세요" : displayedNote)
                            .foregroundStyle(displayedNote.isEmpty ? .secondary : .primary)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 12)
                        Image(systemName: "pencil")
                            .foregroundStyle(Color("AccentColor"))
                    }
                    .contentShape(Rectangle())
                }
                // .plain 이 아니면 List 안의 Button 이 라벨 전체를 강조색으로 덮어써
                // 본문 색 지정이 무시된다.
                .buttonStyle(.plain)
                .accessibilityIdentifier("detail.note")
            }
            Section("스크린샷") {
                LocalCaptureImage(url: model.imageURL(for: capture), contentMode: .fit)
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("저장된 스크린샷")
            }
            Section("저장 정보") {
                Label {
                    Text(capture.createdAt, format: .dateTime.year().month().day().hour().minute())
                } icon: {
                    Image(systemName: "calendar")
                }
                .font(.suitSubheadline)
                .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("스크린샷")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive) {
                    confirmingDelete = true
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("삭제")
                .accessibilityIdentifier("detail.delete")
            }
            ToolbarItem(placement: .primaryAction) {
                Button { share() } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("공유")
                .accessibilityIdentifier("detail.share")
            }
        }
        .sheet(item: $shareItem) { item in
            ActivityView(items: item.items)
        }
        .sheet(isPresented: $showingNoteEditor) {
            NoteEditor(capture: capture, initialNote: displayedNote) { displayedNote = $0 }
        }
        .confirmationDialog("이 스크린샷을 삭제할까요?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("삭제", role: .destructive) {
                if model.delete(capture) { dismiss() }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("이미지와 메모가 이 앱의 보관함에서 삭제됩니다.")
        }
    }

    /// 저장소의 이미지는 확장자 없이 보관하므로, 공유 전에 원래 형식의 임시 파일로 꺼낸다.
    /// 그래야 사진 앱·메시지 등 받는 쪽에서 이미지로 인식한다.
    private func share() {
        guard let url = model.imageURL(for: capture),
              let data = try? Data(contentsOf: url) else {
            model.presentedError = "이미지를 불러오지 못했어요."
            return
        }

        let stamp = Self.fileStamp.string(from: capture.createdAt)
        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent("Shotchive-\(stamp).\(CaptureExporter.fileExtension(for: data))")

        do {
            try? FileManager.default.removeItem(at: temporary)
            try data.write(to: temporary, options: .atomic)
        } catch {
            model.presentedError = "공유할 파일을 만들지 못했어요.\n\(error.localizedDescription)"
            return
        }

        var items: [Any] = [temporary]
        let note = displayedNote.trimmingCharacters(in: .whitespacesAndNewlines)
        if !note.isEmpty { items.append(note) }
        shareItem = ShareItem(items: items)
    }

    private static let fileStamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()
}

private struct ShareItem: Identifiable {
    let id = UUID()
    let items: [Any]
}

private struct NoteEditor: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var model: LibraryModel
    let capture: Capture
    let onSaved: (String) -> Void
    private let initialNote: String
    @State private var note: String
    @State private var confirmingDiscard = false
    @State private var saveError: String?
    @FocusState private var focused: Bool

    init(capture: Capture, initialNote: String, onSaved: @escaping (String) -> Void) {
        self.capture = capture
        self.initialNote = initialNote
        self.onSaved = onSaved
        _note = State(initialValue: initialNote)
    }

    private var changed: Bool { note != initialNote }

    var body: some View {
        NavigationStack {
            Form {
                Section("저장한 이유") {
                    TextField("이 스크린샷을 왜 저장했나요?", text: $note, axis: .vertical)
                        .lineLimit(3...10)
                        .focused($focused)
                        .accessibilityIdentifier("detail.note")
                }
            }
            .navigationTitle("메모 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { changed ? (confirmingDiscard = true) : dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        if model.update(capture, note: note) {
                            onSaved(note.trimmingCharacters(in: .whitespacesAndNewlines))
                            dismiss()
                        } else {
                            saveError = model.presentedError ?? "메모를 저장하지 못했어요."
                            model.presentedError = nil
                        }
                    }
                        .fontWeight(.semibold)
                        .disabled(!changed)
                        .accessibilityIdentifier("detail.save")
                }
            }
            .interactiveDismissDisabled(changed)
            .confirmationDialog("변경한 메모를 버릴까요?", isPresented: $confirmingDiscard, titleVisibility: .visible) {
                Button("버리기", role: .destructive) { dismiss() }
                Button("계속 편집", role: .cancel) {}
            }
            .alert("저장할 수 없어요", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("확인", role: .cancel) { saveError = nil }
            } message: {
                Text(saveError ?? "")
            }
            .onAppear { focused = true }
        }
    }
}

/// 도움말의 실행 행. 글자는 본문색, 아이콘만 강조색으로 통일한다.
private struct HelpActionLabel: View {
    let title: String
    let icon: String

    var body: some View {
        Label {
            Text(title).foregroundStyle(.primary)
        } icon: {
            Image(systemName: icon).foregroundStyle(Color("AccentColor"))
        }
        .frame(minHeight: 44)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

private struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Binding var automationSetupAcknowledged: Bool
    @AppStorage("automationLandingDismissed") private var automationLandingDismissed = false
    @AppStorage("shortcutOnboardingStep") private var onboardingStep = 0

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HelpStep(
                        icon: "1.circle",
                        title: "사진 접근 허용",
                        detail: "설정에서 Shotchive가 모든 사진에 접근하도록 허용하세요. 방금 저장된 스크린샷 한 장을 찾는 데 사용합니다."
                    )
                    HelpStep(
                        icon: "2.circle",
                        title: "‘자동화’ 탭에 동작 하나 추가",
                        detail: "단축어 앱 ‘자동화’ 탭 → 아래 가운데 ‘+’ → 검색창의 ‘자동화’ 칩 → ‘스크린샷’ 순서입니다. 그다음 아래 검색창에서 ‘최근 스크린샷에 메모’를 추가하면 줄 두 개짜리 자동화가 완성됩니다. 보관함에 만들면 캡처 버튼에 반응하지 않습니다."
                    )

                    // Link 는 라벨 색 지정을 무시하므로 Button + openURL 로 연다.
                    Button {
                        openURL(URL(string: "shortcuts://automations")!)
                    } label: {
                        HelpActionLabel(title: "단축어 ‘자동화’ 탭 열기", icon: "arrow.up.forward.app")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("help.openShortcuts")

                    Button {
                        automationSetupAcknowledged = true
                        dismiss()
                    } label: {
                        HelpActionLabel(
                            title: automationSetupAcknowledged ? "설정 완료됨" : "설정했어요",
                            icon: "checkmark.circle"
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(automationSetupAcknowledged)
                    .accessibilityIdentifier("help.automationComplete")

                    Button {
                        onboardingStep = 0
                        automationSetupAcknowledged = false
                        automationLandingDismissed = false
                        dismiss()
                    } label: {
                        HelpActionLabel(title: "설정 다시 하기", icon: "arrow.counterclockwise")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("help.restartSetup")
                } header: {
                    Text("캡처 직후 메모")
                } footer: {
                    Text("처음 한 번만 연결하면 이후에는 평소 스크린샷 버튼을 눌렀을 때 자동으로 메모 입력이 시작됩니다. 잠금 상태에서는 입력창이 바로 나타나지 않을 수 있어요. 캡처해도 아무 반응이 없다면 단축어 앱의 ‘자동화’ 탭이 비어 있는지 먼저 확인하세요.")
                }

                Section {
                    HelpStep(icon: "rectangle.and.pencil.and.ellipsis", title: "스크린샷 공유", detail: "캡처 미리보기의 공유 버튼에서 ‘Shotchive’를 선택하고 이유를 적어 저장하세요.")
                } header: {
                    Text("공유 시트로 저장")
                } footer: {
                    Text("자동화가 보이지 않거나 실행되지 않을 때 사용할 수 있는 기본 방법입니다.")
                }
            }
            .navigationTitle("자동 저장 설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
        }
    }
}

private struct HelpStep: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color("AccentColor"))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.suitHeadline)
                Text(detail).font(.suitSubheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 5)
    }
}
