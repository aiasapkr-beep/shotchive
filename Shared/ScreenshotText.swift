import Foundation
import UIKit
import Vision

/// 스크린샷 안의 글자를 읽어 검색에 쓸 수 있게 만든다.
///
/// 이 앱의 약속은 "나중에 그 이유로 찾는다" 인데, 정작 뭔가를 찾을 때 기억나는 것은
/// 내가 뭐라고 적었는지가 아니라 **그 화면에 뭐가 있었는지**인 경우가 많다. 가격,
/// 주소, 이름 같은 것들. 그래서 적은 메모와 함께 화면의 글자도 색인한다.
///
/// 전부 기기 안에서 돈다. Vision 은 네트워크를 타지 않으므로 "계정도 서버도 없다"는
/// 약속이 그대로 유지되고, 새로 요구할 권한도 없다.
enum ScreenshotText {
    /// Vision 에 넘기기 전에 긴 변을 이 크기로 줄인다. 스크린샷의 글자는 대체로 커서
    /// 정확도 손해가 거의 없는 반면, 원본 해상도로 넘기면 눈에 띄게 느리다.
    static let maxDimension: CGFloat = 2000

    /// 읽고 싶은 언어. 기기가 지원하지 않는 것은 걸러 낸다 — 지원 목록에 없는 값을
    /// 그대로 넘기면 요청 자체가 실패한다.
    static let preferredLanguages = ["ko-KR", "en-US"]

    /// - Returns: 찾은 글자. 글자가 없으면 빈 문자열, 읽기 자체가 실패하면 nil.
    ///   호출하는 쪽에서 "아직 색인 안 함(nil)" 과 "색인했는데 글자가 없음("")" 을
    ///   구분해야 하므로 이 둘을 섞지 않는다.
    static func recognize(imageData: Data) -> String? {
        guard let image = UIImage(data: imageData),
              let cgImage = downscaled(image)?.cgImage
        else { return nil }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        if let supported = try? request.supportedRecognitionLanguages() {
            let wanted = preferredLanguages.filter(supported.contains)
            if !wanted.isEmpty { request.recognitionLanguages = wanted }
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        return normalized(lines.joined(separator: "\n"))
    }

    /// 검색은 공백·줄바꿈이 뒤섞인 원문을 그대로 쓰기 어렵다. 줄은 살리되 연속 공백은
    /// 하나로 줄여 둔다.
    private static func normalized(_ text: String) -> String {
        text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    private static func downscaled(_ image: UIImage) -> UIImage? {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxDimension else { return image }
        let scale = maxDimension / longest
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
