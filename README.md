# Shotchive

스크린샷에 ‘왜 저장했는지’를 함께 남기는 iPhone 네이티브 앱입니다.

## 현재 구현

- 이미지와 메모를 기기 내 App Group에 저장
- 공유 확장에서 저장 이유를 먼저 입력하고 이미지 미리보기 확인 후 저장
- PhotosPicker로 선택한 이미지만 가져오기
- 보관함, 메모 검색, 메모 없는 항목 필터, 메모 수정·삭제
- 단축어의 `최근 스크린샷에 메모` 액션: 최근 캡처 찾기 + 메모 질문 + 앱 저장을 한 동작에서 처리
- iOS 26 이상에서 자동화가 아직 설정되지 않았을 때 앱 시작과 함께 열리는 2단계 설정 마법사
- SwiftUI 시스템 컴포넌트, SUIT Variable 서체, SF Symbols, 다크 모드
- Apple 공식 Human Interface Guidelines의 Sheets, Typography, Materials, Buttons 기준을 화면 구조에 반영
- iOS 26.0 이상, iPhone 전용

## 중요한 동작 범위

Apple은 iOS 26 이상 단축어에 스크린샷이 저장될 때 실행되는 자동화 트리거를 제공합니다. 사용자가 최초 한 번 사진 접근을 허용하고 `스크린샷 자동화 → 최근 스크린샷에 메모`를 연결하면 이후에는 기존 버튼으로 캡처한 직후 메모 입력을 시작할 수 있습니다.

앱은 첫 실행 때 전체 화면 온보딩으로 이 기능을 소개합니다. `설정 시작`을 누르면 사진 접근 허용과 단축어 동작 추가만 안내하는 2단계 설정 마법사가 시작됩니다. 단축어 앱에서 별도의 `사진 찾기`, `입력 요청`, 변수 연결을 만들 필요가 없습니다. 앱으로 돌아오면 보던 단계가 유지되며 도움말 버튼에서 요약 안내를 언제든 다시 확인할 수 있습니다.

개인용 자동화는 앱이 대신 설치할 수 없으므로 최초 설정은 단축어 앱에서 직접 해야 합니다. 이 Mac의 iOS 26.5 시뮬레이터에서는 트리거가 표시되지 않았기 때문에 최종 동작은 실물 iPhone에서 확인해야 합니다. 자동화가 없는 버전에서는 `캡처 → 공유 → Shotchive → 메모 저장` 흐름을 사용합니다. 상세 근거와 검증 항목은 [호환성 문서](docs/COMPATIBILITY.md)에 있습니다.

## 직접 빌드하기

이 저장소는 특정 Apple Developer 계정에 맞춰져 있습니다. 포크해서 실기기에 올리려면
**본인 값으로 네 곳을 바꿔야 합니다.**

| 바꿀 것 | 현재 값 | 위치 |
|---|---|---|
| Team ID | `HSGY74FQXS` | 빌드 시 `DEVELOPMENT_TEAM=` |
| Bundle ID | `com.kimminsu.screenshotsmemo` | `project.yml` (앱·공유 확장 2곳) |
| App Group | `group.com.kimminsu.screenshotsmemo` | 두 entitlement 파일 + `CaptureStore.appGroupIdentifier` |

바꾼 뒤 `xcodegen generate` 를 실행하세요. App Group 을 안 바꾸면 앱과 공유 확장이
서로 다른 저장소를 보게 되어 공유 확장으로 저장한 항목이 앱에 나타나지 않습니다.

시뮬레이터만 쓸 거라면 서명 없이 바로 빌드됩니다(아래 명령의 `CODE_SIGN_IDENTITY=-`).

## 실행

`Screenshots.xcodeproj`를 Xcode에서 열고 `Screenshots` scheme을 실행하세요. 표시 이름은 `Shotchive`이고, Xcode 프로젝트·타깃·Bundle ID는 기존 이름을 유지합니다(App Group과 설치된 앱의 데이터를 끊지 않기 위해).

시뮬레이터 빌드:

```sh
xcodebuild -project Screenshots.xcodeproj -scheme Screenshots \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath build CODE_SIGN_IDENTITY=- build
```

시뮬레이터의 캡처 버튼은 이미지를 Mac에 저장하므로 PhotoKit 자동화 테스트 전에 이미지를 시뮬레이터 사진 앱에 넣어야 합니다.

```sh
xcrun simctl io booted screenshot /tmp/screenshots-test.png
xcrun simctl addmedia booted /tmp/screenshots-test.png
```

실물 iPhone의 물리 버튼으로 찍은 스크린샷은 사진 보관함에 자동 저장되므로 이 추가 단계가 필요 없습니다.

실기기 개발 빌드는 Apple Developer Team `HSGY74FQXS`, Bundle ID `com.kimminsu.screenshotsmemo`, App Group `group.com.kimminsu.screenshotsmemo`로 맞춰져 있습니다. 다른 계정으로 서명할 때는 두 타깃의 Bundle ID와 두 entitlement 파일, `CaptureStore.appGroupIdentifier`를 함께 변경하세요.

프로젝트 설정을 바꿀 때는 `project.yml`을 수정하고 `xcodegen generate`를 실행합니다. 생성된 xcodeproj도 포함되어 있어 열기만 할 때 XcodeGen 설치는 필요 없습니다.

## iOS 26 이상(27 포함): 기존 캡처 버튼과 연결

1. 앱 온보딩에서 사진 접근을 허용하고 **전체 접근 허용**을 선택합니다.
2. 단축어 앱 **자동화** 탭에서 맨 아래 가운데 **`+`** → 오른쪽 위 **`편집`** → 검색창의 **`자동화`** 칩 → **`스크린샷`** 순서로 누릅니다.
3. 이어서 **`최근 스크린샷에 메모`** 를 찾아 추가하면 끝입니다. 자동화 탭에 `스크린샷을 저장할 때 · 최근 스크린샷에 메모` 줄이 생기고 토글이 켜져 있으면 완료입니다. 스크린샷 저장 위치에는 **사진**이 포함돼 있어야 합니다.

이 앱 동작이 최근 스크린샷 찾기, `왜 저장했나요?` 입력 요청, 보관함 저장을 모두 처리합니다. 기존 `스크린샷과 메모 저장` 동작은 이미지를 직접 전달하는 고급·호환 흐름을 위해 유지합니다.

반드시 **자동화** 탭에 만들어야 합니다. 앱을 설치하면 `최근 스크린샷에 메모` App Shortcut이 **보관함** 탭에 자동으로 나타나는데, 보관함의 단축어는 직접 누르거나 뒷면 탭·동작 버튼에 연결했을 때만 실행되며 캡처 버튼에는 반응하지 않습니다. 자동화에는 `스크린샷 찍기` 동작을 넣지 마세요. 이미 찍힌 캡처를 가져오는 흐름입니다. 설정 후 스크린샷을 한 장 찍어 메모 입력이 뜨는지 확인하고, 반응이 없다면 자동화 탭이 비어 있는지 먼저 확인하세요.

## 이전 버전용 단축어

1. 단축어 앱에서 새 단축어를 만듭니다.
2. `스크린샷 찍기` 동작을 추가합니다.
3. `입력 요청`을 추가하고 질문을 `왜 저장했나요?`로 설정합니다.
4. Shotchive 앱의 `스크린샷과 메모 저장` 동작을 추가합니다.
5. 스크린샷 매개변수에는 2단계의 **이미지 출력**, 저장한 이유에는 3단계의 **입력 텍스트 출력**을 각각 지정합니다. 마지막 출력만 자동 연결하면 이미지 대신 텍스트가 전달될 수 있습니다.
6. 단축어를 뒷면 탭 또는 지원 기기의 동작 버튼에 연결합니다.

이 방법은 최초 설정 후 캡처와 메모를 한 흐름으로 실행하지만, 기존 측면+볼륨 버튼 조합과는 다른 실행 방법입니다. 실제 기기의 잠금 상태·키보드 표시·권한 허용 및 공유 확장 실행은 별도 확인이 필요합니다.

## 데이터 및 테스트

이미지는 App Group의 `Captures/Images`, 메모는 `Captures/Metadata`에 항목별로 저장됩니다. 스크린샷 자동화는 방금 저장된 스크린샷을 찾기 위해 사진 읽기 권한을 사용합니다. 사진과 메모의 서버 전송이나 계정 가입은 없으며 앱 내 삭제는 이 앱의 복사본과 메모만 삭제합니다. 별도 내보내기·동기화는 아직 없습니다.

`--demo` 실행 인수는 직접 그린 샘플 이미지 3개를 빈 보관함에 넣습니다. 실제 사용자의 사진은 사용하지 않습니다. 일반 실행은 빈 보관함에서 시작합니다.

검증 결과는 [VALIDATION.md](docs/VALIDATION.md)에 기록합니다.

SUIT는 SIL Open Font License 1.1로 배포되며 상업용 앱에 포함할 수 있습니다. 포함한 파일, 체크섬, 재배포 조건은 [폰트 라이선스 기록](docs/FONT-LICENSE.md)에 보존합니다.

## 라이선스

MIT. 자세한 내용은 [LICENSE](LICENSE).

SUIT Variable 서체만 예외로 SIL Open Font License 1.1 을 따릅니다 —
[폰트 라이선스 기록](docs/FONT-LICENSE.md) 참고.
