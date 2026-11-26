import MicroblinkPlatformEngine
import SwiftUI

/// Exercises every public scanner styling property using only the engine's host API.
/// Fonts use semantic sizes so the custom scanner text still follows Dynamic Type.
enum StudioScannerAppearance {
    static func make() -> ScannerAppearance {
        ScannerAppearance(
            documentScannerAppearance: document(),
            cardScannerAppearance: card(),
            faceCaptureAppearance: face()
        )
    }

    /// BlinkID extraction and DocVer intentionally share this configuration.
    private static func document() -> DocumentScanAppearance {
        var appearance = DocumentScanAppearance()
        appearance.documentScanAlertTitleColor = Studio.copper
        appearance.documentScanAlertTitleFont = .system(.title2, design: .serif, weight: .bold)
        appearance.documentScanAlertDescriptionColor = Studio.cream
        appearance.documentScanAlertDescriptionFont = .system(.body, design: .rounded)
        appearance.documentScanAlertButtonColor = Studio.moss
        appearance.documentScanAlertButtonFont = .system(.headline, design: .monospaced, weight: .bold)
        appearance.documentScanAlertBackgroundColor = Studio.ink

        appearance.documentScanOnboardingSheetTitleColor = Studio.copper
        appearance.documentScanOnboardingSheetTitleFont = .system(.title, design: .serif, weight: .bold)
        appearance.documentScanOnboardingSheetDescriptionColor = Studio.cream
        appearance.documentScanOnboardingSheetDescriptionFont = .system(.body, design: .rounded)
        appearance.documentScanOnboardingSheetButtonColor = Studio.moss
        appearance.documentScanOnboardingSheetButtonFont = .system(.headline, design: .monospaced, weight: .bold)
        appearance.documentScanOnboardingSheetPageIndicatorColor = Studio.copper
        appearance.documentScanOnboardingSheetBackgroundColor = Studio.panel

        appearance.documentScanReticleTooltipFont = .system(.title3, design: .rounded, weight: .semibold)
        appearance.documentScanHelpButtonForegroundColor = Studio.ink
        appearance.documentScanHelpButtonBackgroundColor = Studio.copper
        return appearance
    }

    private static func card() -> CardScanAppearance {
        let midnight = Color(red: 0.03, green: 0.13, blue: 0.19)
        let ocean = Color(red: 0.05, green: 0.23, blue: 0.28)
        let mint = Color(red: 0.46, green: 0.96, blue: 0.79)
        let lemon = Color(red: 1.00, green: 0.88, blue: 0.42)
        let frost = Color(red: 0.88, green: 0.98, blue: 0.96)

        var appearance = CardScanAppearance()
        appearance.alertTitleColor = lemon
        appearance.alertTitleFont = .system(.title2, design: .monospaced, weight: .bold)
        appearance.alertDescriptionColor = frost
        appearance.alertDescriptionFont = .system(.body, design: .rounded)
        appearance.alertButtonColor = mint
        appearance.alertButtonFont = .system(.headline, design: .monospaced, weight: .bold)
        appearance.alertBackgroundColor = midnight

        appearance.onboardingSheetTitleColor = lemon
        appearance.onboardingSheetTitleFont = .system(.title, design: .monospaced, weight: .bold)
        appearance.onboardingSheetDescriptionColor = frost
        appearance.onboardingSheetDescriptionFont = .system(.body, design: .rounded)
        appearance.onboardingSheetButtonColor = mint
        appearance.onboardingSheetButtonFont = .system(.headline, design: .monospaced, weight: .bold)
        appearance.onboardingSheetPageIndicatorColor = lemon
        appearance.onboardingSheetBackgroundColor = ocean

        appearance.reticleTooltipFont = .system(.title3, design: .monospaced, weight: .semibold)
        appearance.helpButtonForegroundColor = midnight
        appearance.helpButtonBackgroundColor = mint
        appearance.helpButtonTooltipForegroundColor = midnight
        appearance.helpButtonTooltipBackgroundColor = lemon
        appearance.toastBackgroundColor = ocean

        // Demonstrate all three card localization overrides with a dedicated host table.
        // English is deliberate for this showcase; other hosts can follow the device language.
        appearance.localizationBundle = .main
        appearance.localizationTableName = "StudioCardScanner"
        appearance.language = "en"
        return appearance
    }

    private static func face() -> FaceCaptureAppearance {
        let plum = Color(red: 0.21, green: 0.06, blue: 0.25)
        let lavender = Color(red: 0.89, green: 0.79, blue: 1.00)
        let peach = Color(red: 1.00, green: 0.77, blue: 0.61)

        var appearance = FaceCaptureAppearance()
        // Instruction colors are controlled by Biometrics for contrast over the camera.
        appearance.instruction = .init(
            font: .system(.title2, design: .rounded, weight: .bold),
            lineSpacing: 5
        )
        appearance.successIcon = .init(
            image: Image(systemName: "checkmark.seal.fill"),
            color: plum,
            background: peach
        )
        appearance.helpButton = .init(
            image: Image(systemName: "lightbulb.fill"),
            color: plum,
            background: lavender
        )
        appearance.helpTooltip = .init(
            font: .system(.callout, design: .rounded, weight: .semibold),
            color: plum,
            lineSpacing: 3
        )
        appearance.helpTooltipBackground = lavender
        applyFaceDialogs(to: &appearance, background: plum, accent: peach, secondary: lavender)
        return appearance
    }

    private static func applyFaceDialogs(
        to appearance: inout FaceCaptureAppearance,
        background plum: Color,
        accent peach: Color,
        secondary lavender: Color
    ) {
        appearance.onboarding.background = plum
        appearance.onboarding.title = .init(
            font: .system(.title, design: .serif, weight: .bold),
            color: peach,
            lineSpacing: 5
        )
        appearance.onboarding.message = .init(
            font: .system(.body, design: .rounded),
            color: Studio.cream,
            lineSpacing: 4
        )
        appearance.onboarding.button = .init(
            font: .system(.headline, design: .monospaced, weight: .bold),
            color: lavender,
            lineSpacing: 2
        )

        appearance.helpSheet.background = Studio.ink
        appearance.helpSheet.title = .init(
            font: .system(.title2, design: .serif, weight: .bold),
            color: peach,
            lineSpacing: 5
        )
        appearance.helpSheet.message = .init(
            font: .system(.body, design: .rounded),
            color: Studio.cream,
            lineSpacing: 4
        )
        appearance.helpSheet.button = .init(
            font: .system(.headline, design: .rounded, weight: .medium),
            color: lavender,
            lineSpacing: 2
        )
        appearance.helpSheet.primaryButton = .init(
            font: .system(.headline, design: .monospaced, weight: .bold),
            color: peach,
            lineSpacing: 2
        )
        appearance.helpSheet.pageIndicator = lavender
    }
}
