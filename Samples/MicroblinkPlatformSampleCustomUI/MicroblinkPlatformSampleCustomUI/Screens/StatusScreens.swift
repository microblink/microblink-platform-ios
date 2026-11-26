import MicroblinkPlatformEngine
import SwiftUI
import UIKit

struct IssueScreen: View {
    let error: EngineError
    let canRetry: Bool
    let retryTitle: String
    let canReturn: Bool
    let onRetry: () -> Void
    let onReturn: () -> Void
    let onLeave: () -> Void

    var body: some View {
        let copy = IssueCopy(error)
        StudioPage {
            VStack(alignment: .leading, spacing: 16) {
                StudioEyebrow(text: "Stopped")
                Text(copy.title)
                    .font(.system(.largeTitle, design: .default))
                    .fixedSize(horizontal: false, vertical: true)
                Text(copy.message)
                    .font(.body)
                    .foregroundStyle(Studio.mute)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 24)
                if canRetry {
                    StudioCommand(retryTitle, action: onRetry)
                }
                if canReturn {
                    StudioCommand("Back to the case", tone: .secondary, action: onReturn)
                }
                StudioCommand("Leave the case", tone: .quiet, action: onLeave)
            }
        }
    }
}

struct OutcomeScreen: View {
    let outcome: SessionOutcome
    let transactionId: String?
    let onClose: () -> Void
    @ScaledMetric(relativeTo: .largeTitle) private var verdictSize = 44

    var body: some View {
        StudioPage {
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 12)
                VStack(alignment: .leading, spacing: 16) {
                    Text("Decision")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Studio.copper)
                        .textCase(.uppercase)
                    Text(verdict)
                        .font(.system(size: verdictSize, design: .default))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(explanation)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                    if let transactionId, !transactionId.isEmpty {
                        Text("Reference \(transactionId)")
                            .font(.system(.caption, design: .monospaced))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Button(action: onClose) {
                        Text("Close the case")
                            .font(.system(.headline, design: .default))
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .foregroundStyle(Studio.slip)
                            .background(Studio.ink)
                    }
                    .buttonStyle(StudioCommandStyle(tone: .secondary))
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Studio.slip)
                .foregroundStyle(Studio.ink)
                Spacer(minLength: 12)
            }
        }
    }

    private var verdict: String {
        switch outcome {
        case .verification(_, let state):
            switch state {
            case .accept: return "Accepted"
            case .reject: return "Declined"
            case .review: return "Held for review"
            @unknown default: return "Finished"
            }
        case .canceled:
            return "Closed"
        @unknown default:
            return "Finished"
        }
    }

    private var explanation: String {
        switch outcome {
        case .verification(_, let state):
            switch state {
            case .accept:
                return "The verification finished with an accept decision."
            case .reject:
                return "The verification finished with a decline decision."
            case .review:
                return "The verification finished and needs a person to review it."
            @unknown default:
                return "The verification finished without a decision this app can name."
            }
        case .canceled:
            return "The case was closed before a decision."
        @unknown default:
            return "The verification finished without a decision this app can name."
        }
    }
}

struct CameraAccessScreen: View {
    let shouldOfferSettings: Bool
    let onRetry: () -> Void
    let onLeave: () -> Void
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var wentToSettings = false

    var body: some View {
        StudioPage {
            VStack(alignment: .leading, spacing: 16) {
                StudioEyebrow(text: "Camera")
                aperture
                    .accessibilityHidden(true)
                Text("The camera is closed")
                    .font(.system(.largeTitle, design: .default))
                Text("Document, card, and portrait capture need the camera. Allow it for this app, then return here.")
                    .font(.body)
                    .foregroundStyle(Studio.mute)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 24)
                StudioCommand(shouldOfferSettings ? "Open Settings" : "Try the camera again", action: primary)
                StudioCommand("Leave the case", tone: .quiet, action: onLeave)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, wentToSettings else { return }
            wentToSettings = false
            onRetry()
        }
    }

    private var aperture: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            var ring = 18.0
            while ring < min(size.width, size.height) / 2 {
                let rect = CGRect(x: center.x - ring, y: center.y - ring, width: ring * 2, height: ring * 2)
                context.stroke(Path(ellipseIn: rect), with: .color(Studio.copper), lineWidth: 1)
                ring += 14
            }
        }
        .frame(height: 140)
        .frame(maxWidth: .infinity)
    }

    private func primary() {
        if shouldOfferSettings, let url = URL(string: UIApplication.openSettingsURLString) {
            wentToSettings = true
            openURL(url)
        } else {
            onRetry()
        }
    }
}
