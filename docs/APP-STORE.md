# App Store 제출 자료 (초안)

App Store Connect에 그대로 붙여넣기 위한 문구 모음입니다. 사실관계는 `docs/VALIDATION.md`의 실기기 검증 결과에 맞췄습니다.

---

## 1. 심사 노트 (App Review Information → Notes)

> 심사자는 한국어를 읽지 못할 수 있으므로 **영문**으로 넣습니다. 앱 화면에 보이는 한국어 문구는 따옴표로 그대로 인용했습니다.

```
WHAT THIS APP DOES
Shotchive saves a screenshot together with the reason you saved it, so you can
find it later by that reason. Everything is stored on-device in an App Group.
There is no account, no sign-in, no server, and no network access at all.

WHY THE APP ASKS FOR FULL PHOTO LIBRARY ACCESS
The main feature runs from a Shortcuts "Screenshot" automation. When the user
takes a screenshot, the automation runs our App Intent "최근 스크린샷에 메모"
(Note the latest screenshot). The intent must locate the single screenshot that
was just saved to the photo library, so it fetches the newest asset whose
mediaSubtype is .photoScreenshot. Limited ("Selected Photos") access cannot work
here, because the user cannot pre-select a screenshot that does not exist yet.
The app copies only that one image into its own storage. Nothing is uploaded.

HOW TO TEST — FASTEST PATH (no setup required)
1. Launch the app. On the onboarding screen tap "나중에" (Later).
2. Tap "+" in the top right of the library.
3. Pick any image, type a reason, and save.
4. The entry appears in the library, grouped by month. Tap it to view, edit the
   reason, share it, or delete it.
This path needs no Shortcuts setup and no photo permission.

HOW TO TEST — MAIN FEATURE (Shortcuts automation, iOS 27+)
Apps cannot create a personal automation on the user's behalf (Apple does not
provide an API), so this one-time setup must be done manually:
1. Open the Shortcuts app and go to the "자동화" (Automation) tab.
2. Tap "+" at the bottom center.
3. Tap "편집" (Edit) in the top right.
4. Tap the "자동화" chip in the search field, then choose "스크린샷" (Screenshot).
5. In the search field below, find and add the action "최근 스크린샷에 메모".
   The automation should now show two rows.
6. Leave Shortcuts, take any screenshot.
7. A prompt appears asking "왜 저장했나요?" (Why did you save this?). Type
   anything and confirm — or cancel it; the capture is saved either way.
8. Open Shotchive. The screenshot is in the library with the reason attached.
The same 4 steps are shown inside the app with a short screen recording:
onboarding step 2, or Help (?) → "설정 다시 하기".

SHARE EXTENSION
From any screenshot preview, tap Share → "Shotchive" to save an image with a
reason. This works on every supported OS version and needs no automation.

PRIVACY
No data is collected and no tracking occurs; both targets ship a
PrivacyInfo.xcprivacy declaring this. Deleting an item removes only this app's
own copy — the original photo in the user's library is never modified or deleted.
```

---

## 2. 앱 스토어 설명 (한국어)

### 프로모션 텍스트 (170자)

```
스크린샷은 쌓이는데 왜 찍었는지는 기억이 안 나죠. 캡처한 직후 이유 한 줄만 남기면,
나중에 그 이유로 바로 찾을 수 있습니다. 모든 기록은 기기 안에만 저장됩니다.
```

### 설명

```
스크린샷을 찍어두고 나중에 보면, 왜 저장했는지가 기억나지 않습니다.
Shotchive는 캡처한 바로 그 순간에 이유 한 줄을 남겨둡니다.

■ 캡처하면 바로 메모
단축어 자동화를 한 번만 연결해두면, 평소처럼 스크린샷을 찍은 직후
"왜 저장했나요?" 입력창이 뜹니다. 한 줄 적으면 스크린샷과 함께 보관됩니다.
급할 때 그냥 넘겨도 캡처는 저장되고, 이유는 나중에 채울 수 있습니다.

■ 이유로 다시 찾기
저장한 이유로 검색합니다. 월별로 정리되고, 이유를 안 적은 항목만 따로 볼 수도
있습니다.

■ 공유 시트로도 저장
자동화를 쓰지 않아도, 캡처 미리보기의 공유 버튼에서 Shotchive를 선택하면
이유를 적어 저장할 수 있습니다.

■ 기기 안에만
계정도 서버도 없습니다. 사진과 메모는 기기 밖으로 나가지 않습니다.
앱에서 삭제해도 사진 앱의 원본은 그대로입니다.

■ 통째로 내보내기
언제든 보관함 전체를 이미지 + 메모(Markdown, JSON)로 묶어 내보낼 수 있습니다.

알아두실 점
· 캡처 직후 메모 기능은 iOS 27 이상의 단축어 자동화를 사용합니다. 자동화는
  Apple 정책상 앱이 대신 만들 수 없어, 처음 한 번은 직접 연결해야 합니다.
  앱 안에 영상과 4단계 안내가 들어 있습니다.
· 아직 iCloud 동기화와 자동 백업이 없습니다. 백업은 '내보내기'를 사용하세요.
· 검색은 직접 적은 메모를 기준으로 동작합니다. 스크린샷 이미지 안의 글자는
  검색되지 않습니다.
```

### 키워드 (100자)

```
스크린샷,캡처,메모,저장,보관함,아카이브,단축어,자동화,정리,기록
```

---

## 3. 제출 전 체크리스트

- [x] `PrivacyInfo.xcprivacy` — 앱·공유 확장 both, 추적 없음/수집 없음
- [ ] **Deployment target `iOS 27.0`** — Xcode 업데이트 필요 (아래 4번). 현재 26.0
- [x] iPhone 전용, 세로 고정
- [x] 빌드 경고 0
- [ ] 개인정보 보호 세부사항(Privacy Nutrition Label) — "데이터가 수집되지 않음"으로 응답
- [ ] 1024×1024 앱 아이콘 (현재 에셋 사용 가능)
- [ ] 스크린샷 (6.9"·6.5" 필수) — 보관함, 상세, 온보딩 2단계 권장
- [ ] 연령 등급 설문
- [ ] 지원 URL (필수) / 마케팅 URL (선택)
- [x] iOS 26 확인 — 26.5 시뮬레이터에 `스크린샷` 트리거 **없음**. 27 전용으로 판단

## 4. ⚠️ 제출 전 필수: iOS 27 SDK 로 전환

**현재 배포 타깃은 `iOS 26.0`이지만, 이대로 제출하면 안 됩니다.**

iOS 26.5 시뮬레이터에는 단축어 `스크린샷` 자동화 트리거가 존재하지 않습니다(`docs/VALIDATION.md` 참고).
26.0으로 출시하면 iOS 26 사용자가 설치할 수 있는데 핵심 기능이 없습니다.

타깃을 27.0으로 올리려면 **iOS 27 SDK가 포함된 Xcode**가 필요합니다. 현재 설치본은 Xcode 26.6 /
iOS 26.5 SDK 라서 27.0을 지정하면 다음 경고와 함께 빌드가 잘못됩니다.

```
The iOS deployment target 'IPHONEOS_DEPLOYMENT_TARGET' is set to 27.0,
but the range of supported deployment target versions is 12.0 to 26.5.99.
```

### 순서

1. Xcode 업데이트 (App Store 또는 https://developer.apple.com/download/ — macOS 최소 요구 버전 확인 필요. 현재 이 Mac은 macOS 26.3.1)
2. SDK 확인:
   ```sh
   xcodebuild -showsdks | grep iphoneos
   ```
   `iphoneos27.x` 가 보여야 합니다.
3. 배포 타깃 변경:
   ```sh
   cd /Users/kim/Desktop/screenshots
   sed -i '' 's/    iOS: "26.0"/    iOS: "27.0"/' project.yml
   xcodegen generate
   ```
4. 경고 없이 빌드되는지 확인:
   ```sh
   xcodebuild -project Screenshots.xcodeproj -scheme Screenshots \
     -destination 'generic/platform=iOS' -derivedDataPath build-device \
     -allowProvisioningUpdates DEVELOPMENT_TEAM=HSGY74FQXS build 2>&1 | grep -E "error:|warning:|BUILD"
   ```
5. 번들 확인: `MinimumOSVersion` 이 `27.0` 인지
   ```sh
   /usr/libexec/PlistBuddy -c "Print :MinimumOSVersion" \
     build-device/Build/Products/Debug-iphoneos/Screenshots.app/Info.plist
   ```

## 5. 아직 검증되지 않은 것

`docs/VALIDATION.md` 참고.

- **iOS 26 실기기**에서 `스크린샷` 트리거가 정말 없는지는 실기기로 확인하지 못했습니다.
  26.5 시뮬레이터에 없다는 것까지만 확인했고, 그 근거로 27 전용이라고 판단했습니다.
- **iPad** 레이아웃은 확인하지 않았습니다(1.0은 iPhone 전용으로 제출).
- 온보딩 데모 영상은 **iOS 27 화면을 그대로 담고 있습니다.** Apple이 단축어 UI를 바꾸면
  영상이 먼저 낡습니다. 화면이 달라지면 새 화면 녹화로 다시 만들어야 합니다
  (탭 표시 합성 방법은 이 세션 기록 참고).
