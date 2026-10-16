import Foundation

/// 자주 쓴 이유를 모아 버튼으로 다시 꺼내 쓸 수 있게 한다.
///
/// 캡처 직후는 타이핑하기 제일 귀찮은 순간이다 — 하던 일 중간이니까. 그런데 실제로
/// 적는 이유는 사람마다 몇 가지로 수렴한다. `레이아웃 레퍼런스`, `나중에 읽기`,
/// `영수증` 같은 것들. 그래서 새로 치는 대신 눌러서 고를 수 있게 한다.
///
/// 따로 저장하는 목록은 없다. 보관함에 이미 있는 메모에서 그때그때 센다 — 쓰는 대로
/// 목록이 따라오고, 관리할 상태가 늘지 않는다.
enum ReasonSuggestions {
    /// 한 번만 쓴 이유는 제안하지 않는다. 눌러서 쓸 만한 것은 되풀이되는 것뿐이다.
    static let minimumUses = 2
    static let maximumCount = 6

    /// 많이 쓴 순서. 같은 횟수면 최근에 쓴 것이 앞에 온다.
    static func from(_ captures: [Capture]) -> [String] {
        var counts: [String: Int] = [:]
        var lastUsed: [String: Date] = [:]
        // 표기만 다른 같은 이유를 따로 세지 않도록 접어서 센다. 보여 줄 때는 사용자가
        // 실제로 쓴 표기를 그대로 쓴다.
        var display: [String: String] = [:]

        for capture in captures {
            let note = capture.note.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !note.isEmpty, note.count <= 40 else { continue }
            let key = note.lowercased()
            counts[key, default: 0] += 1
            if let seen = lastUsed[key] {
                if capture.createdAt > seen { lastUsed[key] = capture.createdAt }
            } else {
                lastUsed[key] = capture.createdAt
                display[key] = note
            }
        }

        return counts
            .filter { $0.value >= minimumUses }
            .sorted {
                if $0.value != $1.value { return $0.value > $1.value }
                return (lastUsed[$0.key] ?? .distantPast) > (lastUsed[$1.key] ?? .distantPast)
            }
            .prefix(maximumCount)
            .compactMap { display[$0.key] }
    }
}
