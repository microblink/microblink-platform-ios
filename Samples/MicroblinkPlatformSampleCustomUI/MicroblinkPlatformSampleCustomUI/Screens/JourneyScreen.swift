import MicroblinkPlatformEngine
import SwiftUI

struct WaitingView: View {
    let onLeave: () -> Void

    var body: some View {
        StudioPage {
            VStack(alignment: .leading, spacing: 16) {
                StudioEyebrow(text: "Opening")
                Text("Opening the case")
                    .font(.system(.largeTitle, design: .default))
                Text("The service is preparing the first step. Capture screens from the scanners appear on their own.")
                    .font(.body)
                    .foregroundStyle(Studio.mute)
                    .fixedSize(horizontal: false, vertical: true)
                ProgressView()
                    .tint(Studio.copper)
                    .padding(.top, 8)
                    .accessibilityLabel("Opening the case")
                Spacer(minLength: 24)
                StudioCommand("Leave the case", tone: .quiet, action: onLeave)
            }
        }
    }
}

struct JourneyScreen: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let workflow: WorkflowProgress
    let step: Step
    let pending: InputRequest?
    let onProceed: () -> Void
    let onLeave: () -> Void

    var body: some View {
        StudioPage {
            VStack(alignment: .leading, spacing: 20) {
                StudioEyebrow(text: "Capabilities")
                Text(progressLabel)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Studio.mute)
                Text(title)
                    .font(.system(.largeTitle, design: .default))
                    .fixedSize(horizontal: false, vertical: true)
                if let name = step.name, !name.isEmpty {
                    Text(name)
                        .font(.title3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(StudioCopy.capabilityDetail(step.type))
                    .font(.body)
                    .foregroundStyle(Studio.mute)
                    .fixedSize(horizontal: false, vertical: true)
                if let description = step.description, !description.isEmpty {
                    Text(description)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if step.attemptCount > 0 {
                    Text("Attempts already recorded: \(step.attemptCount)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Studio.mute)
                }
                capabilityRail
                if workflow.hasConditionalInteractiveStep {
                    note("More steps can appear after this one.")
                }
                if workflow.isKioskModeEnabled {
                    note("Kiosk mode is on. Capture uses this device's shared-camera setup.")
                }
                StudioCommand(proceedTitle, action: onProceed)
                StudioCommand("Leave the case", tone: .quiet, action: onLeave)
            }
        }
    }

    private var title: String {
        StudioCopy.capabilityTitle(step.type, secondDocument: isSecondDocument(step))
    }

    private var proceedTitle: String {
        StudioCopy.proceedTitle(
            type: step.type,
            hasFinishedStep: !workflow.completedStepIds.isEmpty,
            hasPendingInput: pending != nil
        )
    }

    private var progressLabel: String {
        let finished = "\(workflow.completedStepIds.count) finished"
        guard let index = step.interactiveIndex else { return finished }
        if workflow.hasConditionalInteractiveStep || workflow.steps.isEmpty {
            return "\(finished) · interactive step \(index)"
        }
        return "\(finished) · interactive step \(index) of \(workflow.steps.count)"
    }

    @ViewBuilder
    private var capabilityRail: some View {
        let markers = workflow.steps.enumerated().map { index, item in
            CapabilityMarker(
                step: item,
                position: index + 1,
                isSecondDocument: workflow.steps.prefix(index).contains {
                    $0.type == .documentScan || $0.type == .verifyDocument
                }
            )
        }
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(markers) { marker in
                    CapabilityTile(marker: marker, isCurrent: marker.step.id == step.id, expands: true)
                }
            }
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(markers) { marker in
                        CapabilityTile(marker: marker, isCurrent: marker.step.id == step.id)
                    }
                }
            }
        }
    }

    private func isSecondDocument(_ item: Step) -> Bool {
        guard let index = workflow.steps.firstIndex(where: { $0.id == item.id }) else {
            return item.isSecondOfSameKind
        }
        return workflow.steps.prefix(index).contains { $0.type == .documentScan || $0.type == .verifyDocument }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(Studio.copper)
            .fixedSize(horizontal: false, vertical: true)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Studio.panel)
    }
}

private struct CapabilityMarker: Identifiable {
    let step: Step
    let position: Int
    let isSecondDocument: Bool
    var id: Int { step.id }
}

private struct CapabilityTile: View {
    let marker: CapabilityMarker
    let isCurrent: Bool
    var expands = false

    var body: some View {
        let title = StudioCopy.capabilityTitle(marker.step.type, secondDocument: marker.isSecondDocument)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: StudioCopy.symbol(marker.step.type))
                    .accessibilityHidden(true)
                Spacer(minLength: 8)
                Text(stateWord)
                    .font(.system(.caption2, design: .monospaced))
            }
            Text(title)
                .font(.system(.subheadline, design: .default))
                .fixedSize(horizontal: false, vertical: true)
            Text(String(format: "%02d", marker.position))
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Studio.mute)
        }
        .foregroundStyle(marker.step.isCompleted ? Studio.moss : Studio.cream)
        .padding(12)
        .frame(maxWidth: expands ? .infinity : 156, alignment: .leading)
        .frame(width: expands ? nil : 156, alignment: .leading)
        .background(isCurrent ? Studio.panel : Color.clear)
        .overlay(Rectangle().stroke(isCurrent ? Studio.copper : Studio.line, lineWidth: isCurrent ? 2 : 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(stateWord)")
    }

    private var stateWord: String {
        if marker.step.isCompleted { return "Done" }
        if isCurrent { return "Now" }
        return "Later"
    }
}
