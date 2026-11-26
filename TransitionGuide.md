# Transition Guide

## v2.0.0
This guide covers migration from Microblink Platform iOS v1.x.x to v2.0.0. Version 2 separates workflow execution from the standard UI and starts an existing transaction using an `sdkConfiguration` token.

### Key Differences
| Area | v1.x | v2.0.0 |
| --- | --- | --- |
| Architecture | `MicroblinkPlatform` with `MicroblinkPlatformSDK` | `MicroblinkPlatformEngine` for execution and scanners; `MicroblinkPlatform` for standard UI |
| Standard UI | `startSDK()` returns a `UIViewController`; SwiftUI needs a wrapper | Native SwiftUI view` |
| Custom UI | Limited customization through the SDK's supplied flow | Public async `Session` API for host-owned workflow screens, forms, and uploads |
| Startup | Workflow ID, proxy URL, consent, and optional headers | `EngineConfiguration` containing `ServiceSettings(sdkConfiguration:)` |
| Transaction and consent | SDK starts the transaction through a host proxy and can show consent UI | Host collects consent; backend creates the transaction before SDK startup |
| Host callbacks | `MicroblinkPlatformSDKDelegate` | `MicroblinkPlatformEvent` closure, or `StepResult` for custom hosts |
| Verification result | `MicroblinkPlatformResult.status` | `MicroblinkPlatformResult.outcome` with a typed `SessionOutcome` |
| Face capture | Previous face-capture integration | Biometrics guided capture and its appearance settings |
| Platform styling | UIKit colors, fonts, and images | SwiftUI `Color`, `Font`, and `Image`; configuration on the main actor |
| Requirements | iOS 16+ | iOS 17+ |

### Changes between old and new integration

#### 1. Update dependencies and imports
Update the [Microblink Platform Swift package](https://github.com/microblink/microblink-platform-ios) to **2.0.0**. In Xcode, open your project's **Package Dependencies**, select the package, and set its dependency rule to **Exact Version: 2.0.0**. For a new integration, use **File > Add Package Dependencies** with `https://github.com/microblink/microblink-platform-ios.git`.

If your app declares dependencies in `Package.swift`, update the package requirement:

```swift
.package(
    url: "https://github.com/microblink/microblink-platform-ios.git",
    exact: "2.0.0"
)
```

For the standard UI, add both `MicroblinkPlatformEngine` and `MicroblinkPlatform` to your app target. For custom UI, use `MicroblinkPlatformEngine` without the UI module. Both integrations still require scanner dependencies and resources: BlinkID Verify 4000.0.3 and BlinkCard 3001.0.2, including their UX products. Face workflows also require the Biometrics SDK and engine frameworks; remove the old `IDLiveFaceCamera`, `IDLiveFaceDetection`, and `IDLiveFaceIAD` dependencies.

For manual integration, replace the v1 framework with the v2 `MicroblinkPlatformEngine.xcframework` and, for standard UI, `MicroblinkPlatform.xcframework`. Link and embed the scanner frameworks and their resources as well, including `BiometricsSDK.xcframework` and `BiometricsEngine.xcframework` for face workflows. Copying only the Platform frameworks is insufficient.

**Before:**

```swift
import MicroblinkPlatform
import UIKit
```

**Now, for standard UI:**

```swift
import MicroblinkPlatformEngine
import MicroblinkPlatform
import SwiftUI
```

Keep `NSCameraUsageDescription` in the host app's Info.plist. Engine-only integration also presents scanner UI and needs camera permission and scanner runtime dependencies.

#### 2. Move transaction creation and consent to the host

**Before:** The app supplied consent and proxy settings to the SDK, which started the transaction. The SDK could collect consent when processing/storage permission was not already granted.

```swift
let consent = MicroblinkPlatformConsent(
    userId: userId,
    isProcessingStoringAllowed: true,
    isTrainingAllowed: false,
    isGivenOn: Date.now,
    note: nil
)

let serviceSettings = MicroblinkPlatformServiceSettings(
    workflowId: workflowId,
    url: "https://your-proxy.example.com/api/v1",
    consent: consent,
    additionalRequestHeaders: nil
)
```

**Now:** Collect consent in your app and have your backend create the Agent API transaction with the workflow ID, platform `"iOS"`, and consent, including `userId`, affirmative processing/storage permission, the training preference, and `givenOn`. If consent is declined, stop before creating the transaction. Keep Agent credentials on your backend.

Return the transaction's `sdkConfiguration` string to the app and pass it unchanged:

```swift
let configuration = EngineConfiguration(
    service: ServiceSettings(sdkConfiguration: sdkConfiguration)
)
```

The token supplies transaction identity, authorization, and the Edge URL. Remove SDK-side proxy endpoint overrides (`getWorkflowInfo`, `startTransaction`, and `cancelWorkflow`) and the old `additionalRequestHeaders` and `correlationId` startup arguments. Handle transaction setup and any required correlation in your backend integration.

Create a fresh flow for each transaction token. Update the workflow to v2 before requesting its token: startup rejects an explicitly older workflow major/minor version. Custom hosts receive `.unsupportedWorkflowVersion(workflowVersion:sdkVersion:)`; closing the standard UI's incompatibility screen emits `.canceled` with reason `.unsupportedWorkflowVersion`. Patch versions are ignored, and equal/newer or absent workflow versions pass this check.

#### 3. Replace SDK construction and presentation

**Before, from a UIKit controller implementing `MicroblinkPlatformSDKDelegate`:**

```swift
let sdk = MicroblinkPlatformSDK(
    serviceSettings: serviceSettings,
    delegate: self
)
present(sdk.startSDK(), animated: true)
```

**Now, in SwiftUI:** Present `MicroblinkPlatform.view(configuration:onEvent:)` directly. The following host receives a token created after consent and forwards results to your app:

```swift
struct VerificationHost: View {
    let sdkConfiguration: String
    let onFinished: (MicroblinkPlatformResult) -> Void
    let onCanceled: (MicroblinkPlatformCancelState) -> Void
    let onCardScanned: (CardScanResult) -> Void
    @State private var isPresented = false

    var body: some View {
        Button("Start verification") { isPresented = true }
            .fullScreenCover(isPresented: $isPresented) {
                MicroblinkPlatform.view(
                    configuration: EngineConfiguration(
                        service: ServiceSettings(sdkConfiguration: sdkConfiguration)
                    )
                ) { event in
                    switch event {
                    case .finished(let result):
                        isPresented = false
                        onFinished(result)
                    case .canceled(let state):
                        isPresented = false
                        onCanceled(state)
                    case .cardScanned(let card):
                        onCardScanned(card)
                    @unknown default:
                        break
                    }
                }
            }
    }
}
```

**Now, in UIKit:** Create the view on the main actor and present it in a `UIHostingController`. From your presenting controller:

```swift
let controller = UIHostingController(
    rootView: MicroblinkPlatform.view(configuration: configuration) { [weak self] event in
        switch event {
        case .finished(let result):
            // Deliver result.outcome to your app.
            self?.dismiss(animated: true)
        case .canceled(let state):
            // Handle state.reason in your app.
            self?.dismiss(animated: true)
        case .cardScanned(let card):
            // Deliver card to your app and keep the flow open.
            break
        @unknown default:
            break
        }
    }
)
controller.modalPresentationStyle = .fullScreen
present(controller, animated: true)
```

The standard UI owns the session and scanner presentation. It shows the workflow overview before each ready step, then opens the scanner, form, or upload after Start/Continue. Completion opens the result screen. Your app dismisses the presented flow when it receives a terminal event.

#### 4. Replace delegate callbacks and result handling
| v1.x callback or property | v2.0.0 replacement |
| --- | --- |
| `microblinkPlatformSDKDidFinish(viewController:result:)` | `.finished(MicroblinkPlatformResult)` |
| `microblinkPlatformSDKDidClose(viewController:cancelState:)` | `.canceled(MicroblinkPlatformCancelState)` |
| `microblinkPlatformSDKDidFinishCardScanStep(viewController:cardScanResult:)` | `.cardScanned(CardScanResult)` |
| `result.status` / `MicroblinkPlatformResultStatus` | `result.outcome` / `SessionOutcome`, with `VerificationState` for the verdict |
| `cancelState.cancelReason` / `MicroblinkPlatformCancelReason` | `cancelState.reason` / `CancelReason` |
| `MicroblinkPlatformResultCardScanResult` | `CardScanResult` |

**Before:** Read `result.status` for `.accept`, `.reject`, or `.review`.

**Now:** Inspect the outcome received in `.finished`:

```swift
switch result.outcome {
case .verification(let transactionId, let state):
    switch state {
    case .accept:
        // Handle accepted verification for transactionId.
        break
    case .reject:
        // Handle rejected verification for transactionId.
        break
    case .review:
        // Handle pending review for transactionId.
        break
    @unknown default:
        break
    }
case .canceled(let cancellation):
    // Handle cancellation.transactionId and cancellation.reason.
    break
@unknown default:
    break
}
```

`MicroblinkPlatformResult.transactionId` is now optional. Receiving `.finished` alone does not mean verification was accepted; the standard UI emits it when the user confirms or closes the result screen. `.cardScanned` is intermediate output: keep the flow open for later steps and the final result.

`CardScanResult.cardNumber` is now optional and `isCardNumberValid` is available. `owner`, `expiryDate`, and `cvv` remain optional; expiry uses `MM/yyyy`. Host card values are unmasked, including CVV. Handle each event even when two scans have equal values.

Replace `.consentDenied` handling with your host's pre-start consent decision. `CancelReason` contains `.userCanceled` and `.unsupportedWorkflowVersion`. Closing a scanner or a recoverable scanner error returns to the overview rather than ending the entire workflow.

#### 5. Migrate theme values to SwiftUI

Configure the theme on the main actor before constructing the SDK view.

**Before:**

```swift
MicroblinkPlatformTheme.shared.primaryColor = UIColor.systemBlue
MicroblinkPlatformTheme.shared.mainScreenTitleFont = UIFont.preferredFont(forTextStyle: .title1)
MicroblinkPlatformTheme.shared.mainScreenMainImage = UIImage(named: "VerificationHero")!
```

**Now:**

```swift
@MainActor
func configureVerificationTheme() {
    let theme = MicroblinkPlatformTheme.shared
    theme.primaryColor = Color.blue
    theme.mainScreenTitleFont = Font.title
    theme.mainScreenMainImage = Image("VerificationHero")
    theme.localizationBundle = .main
    theme.localizationTableName = "Localizable"
}
```

Existing Platform localization keys and the `localizationBundle` / `localizationTableName` overrides remain supported. Missing host strings fall back to the framework catalog and then the English fallback.

Use `documentScannerAppearance`, `cardScannerAppearance`, and `faceCaptureAppearance` on the theme for scanner styling. Existing `documentScan...` forwarding properties remain available but now accept optional values. Platform `primaryColor` does not automatically recolor the scanners.

For custom UI, pass `ScannerAppearance` in `EngineConfiguration`. The standard UI uses its theme only when a whole scanner appearance is nil; it does not merge individual fields into an explicitly supplied appearance. Face capture uses Biometrics guided UI rather than a Platform-owned face overlay.

#### 6. Use the engine for custom workflow UI
This is a new integration option. Import `MicroblinkPlatformEngine` and call `await MicroblinkPlatformEngine.startSession(configuration)` on the main actor. On success, retain `SessionStart.session` and render `SessionStart.first`; startup has already queried the workflow. The first result can be `.failed` even when a session was created successfully.

Bind `.scannerPresentation(session.scannerPresentation)` to a stable SwiftUI root before starting scanner steps. Use `StepResult` to decide what to show:

| Result | Host action |
| --- | --- |
| `.ready` with `.engineStep` | Show Continue, then call `await session.next(.none)` to run the scanner |
| `.ready` with `.inputStep` | Render the requested form/upload and submit the matching `StepInput` |
| `.blocked` | Show camera permission guidance; retry after permission changes |
| `.failed` | Inspect `recoverable` and `retryAction` before offering a retry |
| `.finished` | Deliver the actual `SessionOutcome` and finish the host flow |

Submit forms with `.formSubmission([FormFieldValue])`, ID uploads with `.uploadIdDocument(front:back:)`, and other documents with `.uploadNonIdDocument(documentType:file:)`. Match requested field names, types, document types, MIME types, and required sides. `UploadFile` accepts data or file URLs; keep file access valid until submission completes. Document uploads have a 20 MiB per-file limit; `recommendedMaxFileSizeKb` is an informational hint.

For recoverable failures, `.callNextWithoutInput` means retry with `.none`, while `.resubmitHostInput` means restore the matching draft for correction and resubmission. Do not resubmit input after an uncertain delivery unless the engine requests it. Consume `lastStepOutput` on both `.ready` and `.finished` for card results.

Use `session.statusUpdates()` for loading and upload indicators only. Allow one `next` call at a time. Explicitly call `await session.cancel(.userCanceled)` when abandoning an unfinished flow; canceling an awaiting task or releasing the session does not cancel the transaction. If startup finishes after the host has closed, cancel that late-arriving session too.

## v1.10.3
### Breaking changes
- Github organization and Swift package has been changed from `MicroblinkPlatform` to `microblink`:
#### Old url:
`https://github.com/MicroblinkPlatform/microblink-platform-ios`
#### New url:
`https://github.com/microblink/microblink-platform-ios` 

## v1.10.2
- No changes

## v1.10.1
- No changes

## v1.10.0
- No changes

## v1.9.0
- No changes

## v1.8.0
- No changes

## v1.7.0
### Breaking changes
- The `MicroblinkPlatformServiceSettings` parameter has been updated:
    - Previously, for `url`, you provided the full API transaction endpoint for your proxy, for example: `https://www.myproxy.com/api/v1/transaction`.
    - Now, `url` accepts your proxy's base domain + API suffix, **without** the final URL path. For example: `https://www.myproxy.com/api/v1`.

**Before**:
```
MicroblinkPlatformServiceSettings(
    workflowId: "myWorkflow",
    url: "https://www.myapi.com/api/v1/transaction",
    consent: consent,
    additionalRequestHeaders: nil
)
```

**Now**:
```
MicroblinkPlatformServiceSettings(
    workflowId: "myWorkflow",
    url: "https://www.myproxy.com/api/v1",
    consent: consent,
    additionalRequestHeaders: nil
)
```

- `MicroblinkPlatformConsent` now **requires** `givenOn`. This value (a `Date`) represents when the consent is given.

**Before**:
```
MicroblinkPlatformConsent(
    userId: userId,
    isProcessingStoringAllowed: true,
    isTrainingAllowed: true,
    note: nil
)
```

**Now**:
```
MicroblinkPlatformConsent(
    userId: userId,
    isProcessingStoringAllowed: true,
    isTrainingAllowed: true,
    isGivenOn: Date.now,
    note: nil
)
```

- In `MicroblinkPlatformSDKDelegate`, the function `microblinkPlatformSDKDidClose` is expanded with `cancelState`.

**Before**:
```
func microblinkPlatformSDKDidClose(viewController: UIViewController)
```

**Now**:
```
func microblinkPlatformSDKDidClose(viewController: UIViewController, cancelState: MicroblinkPlatformCancelState)
```

## v1.5.0
- No changes

## v1.4.2
- Before:
```
MicroblinkPlatformServiceSettings(
    workflowId: "myWorkflow",
    url: "https://www.myapi.com",
    consent: consent,
    additionalRequestHeaders: nil
)
```

- Now:
```
MicroblinkPlatformServiceSettings(
    workflowId: "myWorkflow",
    url: "https://www.myapi.com/api/v1/transaction",
    consent: consent,
    additionalRequestHeaders: nil
)
```

⚠️ This is a breaking change. All integrations must update to use the new url parameter with the full endpoint.

## v1.4.1
- No changes

## v1.4.0
- No changes

## v1.3.0
- No changes

## v1.2.0
- No changes

## v1.1.0
- No changes

## v1.0.0
- MicroblinkPlatform iOS SDK initial release
