# Apple 공식 디자인 기준

사용자가 지정한 디자인 기준은 Apple 개발자 사이트의 Apple Design Resources 및 Human Interface Guidelines(HIG)입니다. 별도 로컬 UI Kit 경로를 받아야 작업할 수 있는 것으로 해석하지 않습니다.

## 공식 원본

- Apple Design Resources: https://developer.apple.com/design/resources/
  - Apple 공식 iOS/iPadOS UI Kit(Figma·Sketch), 앱 아이콘 템플릿, 서체, SF Symbols 등.
  - 디자인 도구용 템플릿과 실행 코드의 시스템 컴포넌트는 역할이 다릅니다. Figma·Sketch 원본을 가져왔다고 주장하지 않습니다.
- Human Interface Guidelines: https://developer.apple.com/design/human-interface-guidelines/
- Materials: https://developer.apple.com/design/human-interface-guidelines/materials
- Typography: https://developer.apple.com/design/human-interface-guidelines/typography

## 현재 코드 적용 점검

- 탐색·편집: SwiftUI NavigationStack, toolbar, sheet, Form, List 및 PhotosPicker를 사용.
- 타이포그래피: title/headline/body/caption 등 시스템 텍스트 스타일과 Dynamic Type 사용. 한국어는 시스템의 언어별 서체 선택을 따름.
- 아이콘: SF Symbols 사용. 앱 아이콘은 프로젝트에서 직접 그린 별도 자산이며 Apple 로고가 아님.
- 색상: systemGroupedBackground, secondarySystemGroupedBackground 및 primary/secondary 텍스트 색상으로 라이트·다크 모드 대응.
- 재질: 내비게이션·툴바 등 시스템 컴포넌트가 OS에 맞는 외관을 제공하도록 유지. HIG Materials에 따라 스크린샷 콘텐츠 카드에는 Liquid Glass를 추가하지 않음.
- 이미지·메모 카드의 간격과 둥근 모서리는 이 앱의 레이아웃 선택이며 Apple UI Kit의 수치를 그대로 추출한 것으로 표시하지 않음.
- iOS 16 이상에서 실행되도록 구성하며, 최신 디자인 자료의 새로운 OS 전용 기능을 최소 지원 버전에 무조건 적용하지 않음.

## 검증 범위

iOS 26.5 시뮬레이터에서 라이트·다크 화면, 카드 레이아웃, 상세 편집, 메모 검색, 공유 확장 저장을 확인했습니다. 모든 접근성 글자 크기, VoiceOver, iPad 레이아웃까지 HIG 준수가 검증된 상태는 아닙니다.


## 이번 UI 수정 기준

공식 자료를 실제 화면 변경의 기준으로 사용합니다. UI Kit 원본을 앱에 삽입하거나 Figma 파일을 복제한 작업은 아닙니다.

| 공식 기준 | 앱에서 적용하는 방식 |
| --- | --- |
| [Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets) | 작성 화면의 취소는 왼쪽, 저장은 오른쪽에 배치. 미저장 입력이 있으면 취소 시 확인. |
| [Typography](https://developer.apple.com/design/human-interface-guidelines/typography) | 시스템 텍스트 스타일, 접근성 글자 크기에서 세로 배치·줄바꿈. |
| [Materials](https://developer.apple.com/design/human-interface-guidelines/materials) | 시스템 탐색·툴바가 OS 외관을 제공. 이미지와 메모 콘텐츠는 불투명한 의미 기반 배경 사용. |
| [Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons) | 기본 시스템 버튼과 충분한 터치 영역, 화면별 주요 저장 동작 한 곳. |

콘텐츠 우선순위는 이 제품의 목적에 맞춰 정합니다. 저장 이유를 목록과 상세 상단에 배치하고 이미지는 참고용 썸네일 및 상세 원본으로 제공합니다. 이는 Apple이 스크린샷 앱에 규정한 전용 레이아웃이 아니라 HIG를 바탕으로 한 제품 설계입니다.

앱의 주황색 브랜드 색은 라이트 모드에서 진하게, 다크 모드에서 밝게 조정한 Asset Catalog의 AccentColor를 사용합니다.
