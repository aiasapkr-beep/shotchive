# Screenshot capture compatibility

## Supported product flow

### Screenshot automation availability

Apple's WWDC26 session explicitly documents an iOS 26 Shortcuts screenshot automation that runs when a screenshot is saved. This is the supported path for preserving the physical screenshot gesture and immediately starting note capture.

**2026-09-19 correction.** The Shortcuts app *is* present on the iOS Simulator (`com.apple.shortcuts`); an earlier note in this project claiming otherwise was wrong. The Automation tab and the `shortcuts://automations` deep link both work there. However, on the iOS 26.5 Simulator the trigger picker's app group lists only `앱` and `지갑` — there is **no `스크린샷` trigger**. On the iOS 27 physical device the same group lists `앱`, `지갑`, `스크린샷`, `알림`. Other entries in that group render normally on 26.5, so this is unlikely to be a simulator omission. Current best reading: the screenshot automation trigger ships in **iOS 27**, not iOS 26. This has not been confirmed on an iOS 26 physical device.

The Simulator capture command saves to the Mac rather than the simulated Photos library. A captured PNG must be dragged into Photos or imported with `xcrun simctl addmedia booted <path>` before the recent-photo path can be tested.

The user must configure the personal automation once in Shortcuts. Apps cannot silently create or enable a personal automation.

The simplified automation is:

1. Screenshot automation fires after the screenshot is saved.
2. Run the app's `최근 스크린샷에 메모` App Intent.
3. The intent retrieves the newest screenshot through PhotoKit, asks for a note through its required parameter, and stores both in the App Group.

PhotoKit can finish indexing slightly after the automation starts. The intent retries briefly before reporting a missing screenshot and only accepts an asset created within the last ten minutes. In Simulator builds only, it also accepts a recent ordinary image because `simctl addmedia` does not preserve the screenshot media subtype.

The WWDC26 material describes the trigger and timing, but does not document that the screenshot is passed as automation input. The simplified intent therefore queries PhotoKit and requires full Photos read access so newly created screenshots remain visible to it. Direct trigger input remains a possible future optimization that requires device testing.

An interactive prompt may be delayed or unavailable while the phone is locked or when the system cannot present Shortcuts UI. The app should accept an empty note and surface an inbox for uncategorized captures.

### Runtime and fallback behavior

`UIApplication.userDidTakeScreenshotNotification` is delivered within the running app; it cannot let a third-party app monitor screenshots taken over other apps or present UI over those apps. The iOS 26 Shortcuts trigger, rather than an app background listener, provides the system-wide integration.

Available fallbacks:

- Screenshot preview, Share, then the app's Share Extension. This keeps the physical capture gesture but adds explicit taps.
- A shortcut assigned to Back Tap or the Action Button that takes a screenshot, asks for a note, and invokes the App Intent. This keeps a short flow but changes the capture gesture.

The physical-button-to-note interaction depends on a user-created personal automation. The app cannot create or enable that automation automatically.

## App architecture

- SwiftUI app for inbox, search, editing, and screenshot detail.
- App Shortcut and App Intent that retrieve the newest screenshot and request a required note, reducing automation setup to one action.
- Compatibility App Intent with an `IntentFile` image and optional `String` note for explicit Shortcuts ingestion.
- Share Extension for the compatibility flow.
- App Group container shared by the app, App Intent execution, and Share Extension.
- Per-record atomic JSON metadata and copied image files inside the App Group container; no retained temporary provider URLs.
- Future automation integration should deduplicate by content hash and capture time. Current explicit imports each create a separate record.
- Keep the original screenshot in Photos. Store an app-private copy with the note.

The simplified automation requires full Photos read access. The compatibility `IntentFile` action avoids library scanning when the caller can supply the image directly.

## Deployment guidance

App Intents are available from iOS 16. The app targets iOS 16 or later, shows screenshot-automation onboarding on iOS 26, and keeps the Share Extension plus a manually run shortcut or Back Tap/Action Button shortcut as fallbacks.

## Official references

- [What's new in Shortcuts, WWDC26](https://developer.apple.com/videos/play/wwdc2026/310/) — Apple documents the iOS 26 screenshot automation; physical-device integration remains untested in this project
- [App Intents: IntentFile](https://developer.apple.com/documentation/appintents/intentfile)
- [Ask for Input in Shortcuts](https://support.apple.com/guide/shortcuts/use-the-ask-for-input-action-apd68b5c9161/ios)
- [Launch a shortcut from another app](https://support.apple.com/guide/shortcuts/launch-a-shortcut-from-another-app-apd163eb9f95/ios)
- [Run shortcuts with Back Tap](https://support.apple.com/guide/shortcuts/run-shortcuts-tapping-iphone-apd897693606/ios)
- [UIApplication userDidTakeScreenshotNotification](https://developer.apple.com/documentation/uikit/uiapplication/userdidtakescreenshotnotification)
