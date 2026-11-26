<p align="center">
  <img src="https://raw.githubusercontent.com/wiki/blinkid/blinkid-ios/Images/logo-microblink.png" alt="Microblink Logo" title="Microblink Logo">
</p>

[![Platform iOS](https://img.shields.io/badge/Platform-iOS-blue)](https://img.shields.io/badge/Platform-iOS-blue)
[![Swift Package Manager Compatible](https://img.shields.io/badge/Swift_Package_Manager-compatible-orange)](https://img.shields.io/badge/Swift_Package_Manager-compatible-orange)

# MicroblinkPlatform SDK for iOS
Microblink Platform iOS SDK runs identity verification workflows with document scanning, guided face capture, payment card scanning, forms, and document uploads. V2 provides two integration options: the default SwiftUI experience in `MicroblinkPlatform`, or your own screens backed by `MicroblinkPlatformEngine`.

## Table of Contents
- [Requirements](#requirements)
- [MicroblinkPlatform Server compatibility](#microblinkplatform-server-compatibility)
- [SDK integration](#sdk-integration)
  - [Swift Package Manager](#swift-package-manager)
  - [Clone](#clone)
  - [UIKit](#uikit)
  - [SwiftUI](#swiftui)
  - [Engine only (custom UI)](#engine-only-custom-ui)
    - [Own the session](#own-the-session)
    - [Bind scanner presentation](#bind-scanner-presentation)
    - [Render results and submit input](#render-results-and-submit-input)
    - [Retry and cancellation](#retry-and-cancellation)
- [Sample apps](#sample-apps)
- [Changing default strings](#changing-default-strings)
- [Customizing the look](#customizing-the-look)

## Requirements

- iOS 17.0 or later.
-  `NSCameraUsageDescription` in your app's Info.plist, explaining why the app needs camera access. Both integration options require this. 

## MicroblinkPlatform Server compatibility

Your app collects consent, and your backend creates the transaction through the Microblink Platform Agent API before the SDK starts. Keep Agent credentials on your backend. Transaction creation includes the `workflowId`, `platform: "iOS"`, and consent: `userId`, affirmative processing/storage permission, the user's training preference, and `givenOn`. If the user declines consent, do not create a transaction or start the SDK.

Return the transaction's `sdkConfiguration` string to your app and pass it unchanged to `ServiceSettings`. The token supplies transaction identity, authorization, and the Edge API URL. The SDK uses that configuration to execute the existing workflow; it does not create transactions or collect consent. Create a fresh flow for each transaction token.

> [!IMPORTANT]
> You need a configured workflow and access to the Microblink Platform API. [Contact Microblink](https://microblink.com/contact-us/) to obtain access.

## SDK integration

Choose the modules your app needs:

| Integration | Platform modules | Your app provides |
| --- | --- | --- |
| Default UI | `MicroblinkPlatform` and `MicroblinkPlatformEngine` | Consent, a transaction token, presentation/dismissal, and event handling |
| Engine only | `MicroblinkPlatformEngine` | The above, plus workflow, form, upload, permission, error, and result screens, and session lifecycle handling |

Both options use the engine's vendor scanner UI, including Biometrics guided face capture. Engine-only integration still needs scanner dependencies and a SwiftUI presentation host; UIKit apps can use `UIHostingController`.

### Swift Package Manager

1. In Xcode, choose **File > Add Package Dependencies**.
2. Enter [the package repository](https://github.com/microblink/microblink-platform-ios.git).
3. Select **Exact Version**, add latest released version
4. For using default UI, link `MicroblinkPlatform`, `MicroblinkPlatformEngine` and dependencies. For custom UI link `MicroblinkPlatformEngine` and dependencies. 

### Clone

If you prefer manual integration, clone [this repository](https://github.com/microblink/microblink-platform-ios.git) and use artifacts.

For v2, link and embed `MicroblinkPlatformEngine.xcframework`; also link and embed `MicroblinkPlatform.xcframework` for default UI. Include the matching scanner dependencies and their resources:

- BlinkID Verify `4000.0.3`: `BlinkIDVerifyUX` and its dependencies from the [BlinkID Verify repository](https://github.com/microblink/blinkid-verify-ios).
- BlinkCard `3001.0.2`: `BlinkCardUX` and its dependencies from the [BlinkCard repository](https://github.com/microblink/blinkcard-ios).
- For face capture: `BiometricsSDK.xcframework` and `BiometricsEngine.xcframework` from the matching SDK distribution. Missing Biometrics frameworks cause face steps to fail.

Embed and sign dynamic frameworks in the host app and retain dependency resource bundles and privacy manifests. Use compatible dependency versions from the same release.

### SwiftUI

Present a new `VerificationFlow` in a `fullScreenCover` after obtaining the transaction token. V2 does not need a `UIViewControllerRepresentable` wrapper.

```swift
import MicroblinkPlatform
import MicroblinkPlatformEngine
import SwiftUI

@MainActor
struct VerificationFlow: View {
    let sdkConfiguration: String
    let onFinished: (MicroblinkPlatformResult) -> Void
    let onCanceled: (MicroblinkPlatformCancelState) -> Void
    let onCardScanned: (CardScanResult) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        MicroblinkPlatform.view(
            configuration: EngineConfiguration(
                service: ServiceSettings(sdkConfiguration: sdkConfiguration)
            )
        ) { event in
            switch event {
            case .finished(let result):
                dismiss()
                onFinished(result)
            case .canceled(let state):
                dismiss()
                onCanceled(state)
            case .cardScanned(let card):
                onCardScanned(card)
            @unknown default:
                break
            }
        }
        .interactiveDismissDisabled()
    }
}
```

Both default UI examples handle the same events:

| Event | Host behavior |
| --- | --- |
| `.finished(MicroblinkPlatformResult)` | Dismiss and inspect `result.outcome`. `.verification(transactionId:state:)` provides `.accept`, `.reject`, or `.review`; an outcome can also be `.canceled`. The event alone does not mean acceptance. |
| `.canceled(MicroblinkPlatformCancelState)` | Dismiss and handle `state.reason` and the optional `state.transactionId`. |
| `.cardScanned(CardScanResult)` | Handle the intermediate card output and leave the flow open for subsequent steps or the final result. |

The default UI shows Home before each ready step, including forms and uploads. Start/Continue opens the input screen or runs its scanner; workflow completion opens Result. `.finished` is emitted when the user confirms or closes Result. Closing a scanner or a recoverable scanner error returns Home; closing a recoverable form/upload error restores its input draft. Terminal events are emitted once.

`CardScanResult` contains `isCardNumberValid`, optional `cardNumber`, `owner`, `expiryDate` (`MM/yyyy`), and `cvv`. Host card values are unmasked; image redaction and backend text masking do not mask these values. Separate accepted scans can return identical values, so handle each event.

### Engine only (custom UI)

Import `MicroblinkPlatformEngine` without `MicroblinkPlatform`. Your app renders the workflow and collects host input; the engine handles Edge requests, validation, scanner capture, and feedback submission. Use `StepResult` for navigation and `EngineStatus` only for transient activity, including upload percentage. Sessions and the adapter below are main-actor isolated.

#### Own the session

This adapter retains one session, handles the initial result, observes activity, forwards card output, and prevents a late startup/advance result from reopening a closed flow. It is host code to adapt, not a type supplied by the SDK.

```swift
import Combine
import MicroblinkPlatformEngine
import SwiftUI

@MainActor
final class EngineVerificationModel: ObservableObject {
    @Published private(set) var result: StepResult?
    @Published private(set) var status: EngineStatus = .idle
    @Published private(set) var startError: SessionStartError?
    @Published private(set) var isAdvancing = false
    @Published private(set) var scannerPresentation = ScannerPresentation()

    private var session: (any Session)?
    private var statusTask: Task<Void, Never>?
    private var didStart = false
    private var isClosed = false
    private let onCardScanned: (CardScanResult) -> Void

    init(onCardScanned: @escaping (CardScanResult) -> Void) {
        self.onCardScanned = onCardScanned
    }

    deinit { statusTask?.cancel() }

    func start(token: String) async {
        guard !didStart, !isClosed else { return }
        didStart = true
        let configuration = EngineConfiguration(
            service: ServiceSettings(sdkConfiguration: token)
        )
        switch await MicroblinkPlatformEngine.startSession(configuration) {
        case .failure(let error):
            if !isClosed { startError = error }
        case .success(let start):
            guard !isClosed else {
                _ = await start.session.cancel(.userCanceled)
                return
            }
            session = start.session
            scannerPresentation = start.session.scannerPresentation
            status = start.session.status
            let updates = start.session.statusUpdates()
            statusTask = Task { @MainActor [weak self] in
                for await status in updates {
                    guard !Task.isCancelled else { return }
                    self?.status = status
                }
            }
            apply(start.first)
        }
    }

    func advance(_ input: StepInput) async {
        guard let session, !isAdvancing, !isClosed else { return }
        if case .finished = result { return }
        isAdvancing = true
        defer { isAdvancing = false }
        let next = await session.next(input)
        guard !isClosed else { return }
        apply(next)
    }

    // Await this before dismissing an unfinished custom flow.
    @discardableResult
    func close() async -> CanceledOutcome? {
        guard !isClosed else { return nil }
        isClosed = true
        statusTask?.cancel()
        if case .finished = result { return nil }
        return await session?.cancel(.userCanceled)
    }

    private func apply(_ next: StepResult) {
        result = next
        let output: StepOutput?
        switch next {
        case .ready(_, _, _, let lastStepOutput):
            output = lastStepOutput
        case .finished(_, _, let outcome, let lastStepOutput):
            statusTask?.cancel()
            status = .terminal(outcome)
            output = lastStepOutput
        default:
            output = nil
        }
        if case .cardScan(_, let card) = output {
            onCardScanned(card)
        }
    }
}
```

`startSession` already performs the first Edge resume. Process `SessionStart.first`; do not call `next(.none)` immediately just because startup succeeded. Invalid tokens return `SessionStartError`; network/workflow failures after startup arrive as `StepResult.failed` on the returned session.

#### Bind scanner presentation

Keep the model and `.scannerPresentation(_:)` on a stable root view for the entire flow. The generic container below accepts your screen renderer as `content`; implement that renderer using the result/input tables below. It does not supply forms or other Platform screens.

```swift
@MainActor
struct EngineVerificationHost<Content: View>: View {
    let token: String
    private let content: (EngineVerificationModel) -> Content
    @StateObject private var model: EngineVerificationModel

    init(
        token: String,
        onCardScanned: @escaping (CardScanResult) -> Void,
        @ViewBuilder content: @escaping (EngineVerificationModel) -> Content
    ) {
        self.token = token
        self.content = content
        _model = StateObject(wrappedValue: EngineVerificationModel(onCardScanned: onCardScanned))
    }

    var body: some View {
        content(model)
            .scannerPresentation(model.scannerPresentation)
            .task { await model.start(token: token) }
            .interactiveDismissDisabled()
    }
}
```

In your Close button, await `model.close()` before dismissing the custom flow and handle its optional cancellation outcome. Closing during startup is also handled: a session that arrives later is canceled. For a finished result, deliver `SessionOutcome` and dismiss when your result UI is acknowledged. Route every exit through this lifecycle; simply releasing the model or cancelling the task awaiting `next` does not cancel the backend session. Do not cancel on every `onDisappear`, because presenting a scanner can temporarily cover the host view. Disable submission/continue actions while `isAdvancing` is true, but keep an explicit cancellation action available.

#### Render results and submit input

While `result` and `startError` are both `nil`, show your startup UI. If `startError` is set, show an initialization failure. Once a result arrives:

| `StepResult` | Custom UI behavior | Next action |
| --- | --- | --- |
| `.ready` with `.engineStep(step:type:)` | Show the workflow overview and the pending scanner step | On Continue, `await model.advance(.none)`; Engine presents the scanner |
| `.ready` with `.inputStep(step:request:)` | Show the overview, then your form/upload view using `InputRequest` | Open input locally; submit its matching `StepInput` when the user is ready |
| `.blocked` with `.permissionRequired` | Show camera permission guidance and a Settings action when needed | After permission changes, `await model.advance(.none)` |
| `.failed` | Show validation, transport, or workflow feedback | Follow `recoverable` and `retryAction` as described below |
| `.finished` | Show/deliver the actual `SessionOutcome` (`accept`, `reject`, `review`, or cancellation) | Acknowledge and dismiss; do not call `next` again |

Use `workflow.steps`, `currentStepId`, and `completedStepIds` to update your overview after each ready result. Go directly to your result screen on `.finished`. Engine does not render HomeScreen or ResultScreen for custom hosts. Consume `lastStepOutput` from both `.ready` and `.finished`; the adapter forwards `.cardScan` once per returned result, without deduplicating separate scans with identical card values.

| `InputRequest` | Build this UI | Submit through `model.advance` |
| --- | --- | --- |
| `.form(fields:isKioskModeEnabled:)` | Controls matching each field's `kind`, name, required flag, and default value | `.formSubmission([FormFieldValue])` |
| `.uploadIdDocument(...)` | Front-side picker and a back-side picker when `isOnlyFrontSide` is false | `.uploadIdDocument(front: UploadFile, back: UploadFile?)` |
| `.uploadNonIdDocument(...)` | Allowed-document selector and a picker honoring its `allowedFileTypes` | `.uploadNonIdDocument(documentType: selectedDocument.documentType, file: UploadFile)` |

For example, these host helpers submit a text field from the returned form request and ID images already encoded as JPEG:

```swift
extension EngineVerificationModel {
    func submitTextField(named fieldName: String, value: String?) async {
        // For a multi-field form, collect and submit all field values together.
        await advance(.formSubmission([.text(fieldName: fieldName, value: value)]))
    }

    func submitIDImages(frontJPEG: Data, backJPEG: Data?) async {
        let front = UploadFile(contentType: "image/jpeg", fileName: "front.jpg", source: .data(frontJPEG))
        let back = backJPEG.map {
            UploadFile(contentType: "image/jpeg", fileName: "back.jpg", source: .data($0))
        }
        await advance(.uploadIdDocument(front: front, back: back))
    }

    func submitDocument(_ document: AllowedDocument, file: UploadFile) async {
        await advance(.uploadNonIdDocument(documentType: document.documentType, file: file))
    }
}
```

Forms also support `.integer`, `.decimal`, `.bool`, `.date`, `.time`, `.dateTime`, and `.file` values. Match the field names/types in the request. Preserve unanswered Boolean fields as `nil`, distinct from `false`; retain drafts per step and request. Preserve defaults and optional empty values, and reject invalid or overflowing numbers. For dates/times, the default UI submits `yyyy-MM-dd`, `HH:mm:ss`, and `yyyy-MM-dd'T'HH:mm:ss` in the current time zone. Form attachments accept PDF for PDF fields and JPEG/PNG for image fields, with a 20 MiB per-file limit.

`UploadFile` accepts `.data(Data)` or `.file(URL)` sources. Keep file URLs readable, including any security-scoped access, until submission completes. Encode camera/library images as JPEG or PNG; ID uploads accept those image types, and non-ID uploads may also accept PDF when the selected document permits it. Use `UploadValidation.rejection(...)` for picker preflight; it checks against `UploadValidation.maximumByteCount`, the service's 20 MiB per-file limit. A step's `recommendedMaxFileSizeKb` is an informational hint that neither the service nor Engine enforces. Engine validates submissions again.

#### Retry and cancellation

- With `recoverable == true` and `.callNextWithoutInput`, offer Retry and call `await model.advance(.none)`. Engine decides whether to capture again, resend an unsent capture, or poll an uncertain submission. Do not resubmit form/upload data during polling.
- With `recoverable == true` and `.resubmitHostInput`, reopen the matching input draft, allow correction, and submit its typed input again. Display `.invalidFormInput` by field and `.invalidUploadInput` with the selected upload. Keep drafts/files after network failures; a backend upload rejection should clear the rejected files and request new ones.
- A canceled scanner can return a recoverable `.stepValidation(reason: .stepCanceled, ...)`; return to the overview and let the user continue again. This is different from cancelling the entire session.
- If a failure is nonrecoverable or has no retry action, present the failure and offer Close. Await `model.close()` when abandoning the session. Never infer an accepted/rejected verification verdict from an error or HTTP status.

The engine requests camera permission when it is undetermined. For denied/restricted access, offer Settings and retry after access changes. Only one `next` operation may run at a time; concurrent calls fail instead of queuing. Cancel status observation when your host is done. Explicit session cancellation releases capture and finishes status streams without waiting for the network; repeated cancellation returns the cached outcome.

## Sample apps

The [Samples](Samples) folder contains default SwiftUI and Custom UI apps.

> [!WARNING]
> For device testing, configure your signing team and obtain a transaction token for your workflow. Production apps should obtain tokens from their backend; transaction creation and consent remain host responsibilities.

## Changing default strings

Use the `mb-mp-` keys from the `Localizable.xcstrings` catalog to override default UI text in your app. You can override only the keys you need; missing host keys fall back to the framework catalog, then to the English fallback.

Configure the theme on the main actor before creating the SDK view:

```swift
import MicroblinkPlatform
import SwiftUI

@MainActor
func configurePlatformStrings() {
    MicroblinkPlatformTheme.shared.localizationBundle = .main
    // Optional; omit when using the standard Localizable table.
    MicroblinkPlatformTheme.shared.localizationTableName = "VerificationStrings"
}
```

Scanner localization is separate. `ScannerAppearance.localizationTableName` is forwarded to the scanner SDKs. BlinkCard supports `CardScanAppearance.localizationBundle`, `localizationTableName`, and `language`; its table override takes precedence over the shared table. The current document and face integrations do not expose a host localization bundle, so a shared table name alone does not activate host translations for those scanners. Engine-only hosts localize their own workflow screens.

## Customizing the look

The default UI supports colors, fonts, images, and corner radii through `MicroblinkPlatformTheme.shared`. To rearrange screens or add/remove UI elements, use the engine-only integration and build your own workflow screens.

Configure the theme on the main actor before constructing the SDK view. V2 uses SwiftUI `Color`, `Image`, and `Font` values:

```swift
import MicroblinkPlatform
import MicroblinkPlatformEngine
import SwiftUI

@MainActor
func configurePlatformAppearance() {
    let theme = MicroblinkPlatformTheme.shared
    theme.primaryColor = .purple
    theme.mainScreenMainImage = Image(systemName: "person.text.rectangle")
    theme.mainScreenTitleFont = .title.bold()
    theme.buttonCornerRadius = 12

    theme.documentScannerAppearance.documentScanAlertButtonColor = .purple
    theme.cardScannerAppearance.alertButtonColor = .purple
    theme.faceCaptureAppearance.onboarding.button.color = .purple
}
```

`primaryColor` styles Platform screens; scanner colors are configured separately. `DocumentScanAppearance` is shared by BlinkID and document verification, `CardScanAppearance` styles BlinkCard, and `FaceCaptureAppearance` styles Biometrics guided capture. Both face instruction kinds use the Biometrics UI.

For engine-only integration, pass scanner styling directly in `EngineConfiguration`. The same configuration also works with the default UI:

```swift
import MicroblinkPlatformEngine
import SwiftUI

@MainActor
func makeConfiguration(token: String) -> EngineConfiguration {
    var document = DocumentScanAppearance()
    document.documentScanAlertButtonColor = .purple

    var card = CardScanAppearance()
    card.alertButtonColor = .purple

    var face = FaceCaptureAppearance()
    face.onboarding.button.color = .purple

    return EngineConfiguration(
        service: ServiceSettings(sdkConfiguration: token),
        scannerAppearance: ScannerAppearance(
            documentScannerAppearance: document,
            cardScannerAppearance: card,
            faceCaptureAppearance: face
        )
    )
}
```
