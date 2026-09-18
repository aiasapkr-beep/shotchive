import SwiftUI
import UIKit

enum SUITFontWeight {
    case regular
    case medium
    case semibold
    case bold
    case extrabold

    var postScriptName: String {
        switch self {
        case .regular: "SUITVariable-Regular"
        case .medium: "SUITVariable-Medium"
        case .semibold: "SUITVariable-SemiBold"
        case .bold: "SUITVariable-Bold"
        case .extrabold: "SUITVariable-ExtraBold"
        }
    }
}

extension Font {
    static let suitLargeTitle = suit(size: 34, relativeTo: .largeTitle)
    static let suitLargeTitleBold = suit(size: 34, relativeTo: .largeTitle, weight: .bold)
    static let suitTitle2 = suit(size: 22, relativeTo: .title2)
    static let suitTitle2Semibold = suit(size: 22, relativeTo: .title2, weight: .semibold)
    static let suitTitle2Bold = suit(size: 22, relativeTo: .title2, weight: .bold)
    static let suitHeadline = suit(size: 17, relativeTo: .headline, weight: .semibold)
    static let suitBody = suit(size: 17, relativeTo: .body)
    static let suitBodySemibold = suit(size: 17, relativeTo: .body, weight: .semibold)
    static let suitCallout = suit(size: 16, relativeTo: .callout)
    static let suitSubheadline = suit(size: 15, relativeTo: .subheadline)
    static let suitSubheadlineBold = suit(size: 15, relativeTo: .subheadline, weight: .bold)
    static let suitFootnote = suit(size: 13, relativeTo: .footnote)
    static let suitCaption = suit(size: 12, relativeTo: .caption)
    static let suitCaptionSemibold = suit(size: 12, relativeTo: .caption, weight: .semibold)

    static func suit(
        size: CGFloat,
        relativeTo textStyle: Font.TextStyle,
        weight: SUITFontWeight = .regular
    ) -> Font {
        .custom(weight.postScriptName, size: size, relativeTo: textStyle)
    }
}

extension UIFont {
    static func suit(size: CGFloat, weight: SUITFontWeight = .regular) -> UIFont {
        UIFont(name: weight.postScriptName, size: size) ?? .systemFont(ofSize: size)
    }
}
