# Release notes

## v2.0.0

2.0.0 is a new major version. See the [v2.0.0 transition guide](TransitionGuide.md#v200) for old/new integration examples and migration steps.

### What's new
- New SDK architecture with two modules: `MicroblinkPlatformEngine` runs workflows and presents scanners, while `MicroblinkPlatform` provides the standard SwiftUI experience.
- Native SwiftUI integration through `MicroblinkPlatform.view(configuration:onEvent:)`. UIKit apps can present the same flow in a `UIHostingController`.
- Custom UI integration through `MicroblinkPlatformEngine.startSession(_:)`. Hosts can build their own workflow screens, forms, and uploads using `Session`, `StepResult`, and typed `StepInput` values while retaining the SDK's scanner UI.
- Token-based startup for existing Agent API transactions. The host supplies the `sdkConfiguration` returned by its backend, and the engine handles workflow execution through Edge API v2.
- Biometrics guided face capture replaces the previous face-capture integration.
- Updated scanner dependencies to BlinkID Verify 4000.0.3 and BlinkCard 3001.0.2.
- Session activity and upload progress are available through `EngineStatus` and `Session.statusUpdates()`. Recoverable failures include an explicit retry action for polling or correcting host input.
- SwiftUI appearance customization, with separate `DocumentScanAppearance`, `CardScanAppearance`, and `FaceCaptureAppearance` settings. The standard UI includes scalable text and form/upload draft recovery.

### Breaking API changes
- Minimum deployment target increased from iOS 16 to iOS 17
- Removed `MicroblinkPlatformSDK`, `startSDK()`, and `MicroblinkPlatformSDKDelegate`. 
    - Use `MicroblinkPlatform.view(configuration:onEvent:)` for the standard UI
    - Use `MicroblinkPlatformEngine.startSession(_:)` for custom UI.
- Replaced `MicroblinkPlatformServiceSettings` with `EngineConfiguration` and `ServiceSettings(sdkConfiguration:)`. The SDK no longer accepts the workflow ID, proxy URL, additional request headers, correlation ID, or proxy endpoint overrides as startup parameters. Transaction setup belongs to the host/backend.
- Removed `MicroblinkPlatformConsent` and the SDK consent screen. Collect consent and create the transaction before starting the SDK. If the user declines consent, do not create a transaction or present the SDK.
- Delegate callbacks are replaced by `MicroblinkPlatformEvent.finished`, `.canceled`, and `.cardScanned`. The host owns presentation and dismissal.
- `MicroblinkPlatformResult.status` is replaced by `outcome: SessionOutcome`, which distinguishes `.verification(transactionId:state:)` from `.canceled`. `MicroblinkPlatformResult.transactionId` is now optional. `VerificationState` replaces `MicroblinkPlatformResultStatus`.
- `MicroblinkPlatformCancelState.cancelReason` is renamed to `reason` and uses `CancelReason`. The cases are `.userCanceled` and `.unsupportedWorkflowVersion`; consent denial is handled by the host before startup.
- `CardScanResult` replaces `MicroblinkPlatformResultCardScanResult`. `cardNumber` is now optional, and `isCardNumberValid` is available. Card results remain intermediate output and do not indicate workflow completion.
- Platform theme properties that used `UIColor`, `UIFont`, and `UIImage` now use SwiftUI `Color`, `Font`, and `Image`. Configure `MicroblinkPlatformTheme.shared` on the main actor before creating the UI. Existing document scanner theme forwarding properties now accept optional values.
- Startup rejects a token whose workflow major/minor version is older than the SDK's version, returning `SessionStartError.unsupportedWorkflowVersion` for custom hosts. Update the workflow before requesting a new token. Patch versions are ignored; equal/newer or absent workflow versions pass this check.

## v1.10.3
### Improvements
- Improved accessibility support
- Added optional `correlationId` in `MicroblinkPlatformServiceSettings`

### Breaking changes
- Github organization and Swift package has been changed from `MicroblinkPlatform` to `microblink`:
#### Old url:
`https://github.com/MicroblinkPlatform/microblink-platform-ios`
#### New url:
`https://github.com/microblink/microblink-platform-ios` 

## v1.10.2
### Improvements
- Improved support for setting a custom localization in `MicroblinkPlatformTheme`:
	- `localizationBundle` - A bundle from the host app containing translations that override the SDK's built-in strings.
	- `localizationTableName` - Optional strings table name. Leave `nil` to use the default `Localizable` table.

## v1.10.1
### Bugfixes
- Fixed issue with BlinkCard integration

## v1.10.0
### Updates

We've updated our **BlinkID Verify** and **BlinkCard** dependencies:

- The Scan & Verify ID capability now uses BlinkID Verify v3.21.0.
- The Scan Payment Card capability now uses BlinkCard v3000.0.1.

To read more about the new features supported by these upgrades, see the release notes for [BlinkID Verify](https://docs.microblink.com/verify/release-notes#version-3210) and [BlinkCard](https://docs.microblink.com/blinkcard/release-notes#v300000).

## v1.9.0
### New features
- Added support for the Upload Non-ID and Upload & Verify ID capabilities

## v1.8.0
### New features
- Added support for overriding `scanUnsupportedBack` and `scanPassportDataPageOnly` on the Scan ID step

## v1.7.0
### Breaking changes
- The `MicroblinkPlatformServiceSettings` parameter has been updated:
    - Previously, for `url`, you provided the full API transaction endpoint for your proxy, for example: `https://www.myproxy.com/api/v1/transaction`.
    - Now, `url` accepts your proxy's base domain + API suffix, **without** the final URL path. For example: `https://www.myproxy.com/api/v1`.
- `MicroblinkPlatformConsent` now **requires** `givenOn`. This value (a `Date`) represents when the consent is given.
- In `MicroblinkPlatformSDKDelegate`, the function `microblinkPlatformSDKDidClose` is expanded with `cancelState`. This type (`MicroblinkPlatformCancelState`) has two values:
	- optional `transactionId`
	- `cancelReason` enum which returns `userCanceled` or `consentDenied`

### New features
- Added a consent screen which is shown if `isProcessingStoringAllowed` in `MicroblinkPlatformConsent` is `false`. This means that, if you haven't collected consent from your users and provided it to us, we will collect it ourselves.
- In `MicroblinkPlatformServiceSettings`, added new string properties for overriding proxy endpoints:
	- `getWorkflowInfo`
	- `startTransaction`
	- `cancelWorkflow`

## v1.5.0
### What's new
- We've added kiosk mode support. This is helpful in applications where a tablet device is mounted on a wall, and your users are expected to scan their documents using the front camera only. 
- You can now upload PDF files when using the manual input capability.

### Updates
We've updated our BlinkID Verify and BlinkCard dependencies:
- The "Scan & Verify ID" capability now uses BlinkID Verify 3.14.1.
- The "Scan Payment Card" capability now uses BlinkCard 2.12.0.

To read more about the new features supported by these upgrades, see the release notes for [BlinkID Verify](https://blinkidverify.docs.microblink.com/docs/docver/release-notes/release-notes) and [BlinkCard](https://blinkcard.docs.microblink.com/category/release-notes/).

## v1.4.2
### Breaking changes
- `MicroblinkPlatformServiceSettings` parameter update
    - The field `authProviderHost` has been renamed to `url`.
    - Previously, `authProviderHost` accepted only the base domain (e.g. `https://www.myapi.com`).
    - Now, url must include the full API transaction endpoint, for example: `https://www.myapi.com/api/v1/transaction`

## v1.4.1
### Improvements
- Improved extraction of first and middle names for certain ID types

## v1.4.0
### Improvements
- Face capture now performs additional validation checks:
	- Eyes closed
	- Image too dark
	- Face blurry
	- Mouth open
	- Sunglasses detected

- Improved card scanning performance and reliability
- Enhanced document extraction with additional extracted fields

## v1.3.0

### New features
- Added support for payment card scan capability
  - Result of payment card scan capability is returned via `func microblinkPlatformSDKDidFinishCardScanStep(viewController: UIViewController, cardScanResult: MicroblinkPlatformResultCardScanResult)` in `MicroblinkPlatformSDKDelegate`
  - `MicroblinkPlatformResultCardScanResult` includes the following fields: `cardNumber`, `expiryDate`, `owner`, `cvv`
- Added support for multiple steps of the same type

### Improvements
- Optimized internal request handling for improved performance

## v1.2.0
- Added support for Manual User input

## v1.1.0
- Added support for BlinkID

## v1.0.0
- MicroblinkPlatform iOS SDK initial release
