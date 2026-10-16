import SwiftUI

/// 메모 입력 칸 아래에 붙는 버튼 줄. 눌러서 바로 넣는다.
///
/// 캡처 직후 입력창은 단축어가 그리는 시스템 UI라 우리가 버튼을 넣을 수 없다. 대신
/// 그쪽은 App Intent 의 `optionsProvider` 로 같은 목록을 제안하고, 우리가 직접 그리는
/// 화면에서는 이 칩을 쓴다 — 놓친 캡처 처리, 메모 편집, 직접 추가.
struct ReasonChips: View {
    let suggestions: [String]
    @Binding var note: String

    var body: some View {
        if !suggestions.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { reason in
                        Button {
                            note = reason
                        } label: {
                            Text(reason)
                                .font(.suitSubheadline)
                                .lineLimit(1)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    Color("AccentColor").opacity(note == reason ? 0.22 : 0.10),
                                    in: Capsule()
                                )
                                .foregroundStyle(Color("AccentColor"))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("reason.chip")
                    }
                }
                .padding(.vertical, 2)
            }
            // List 의 행 여백을 그대로 두면 칩이 잘려 보인다.
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 0))
        }
    }
}
