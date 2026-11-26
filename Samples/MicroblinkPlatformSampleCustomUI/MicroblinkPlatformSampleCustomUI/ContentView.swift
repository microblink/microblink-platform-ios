import MicroblinkPlatformEngine
import SwiftUI

@MainActor
struct ContentView: View {
    @State private var sdkConfiguration = ""
    @State private var activeFlow: VerificationFlow?
    @State private var outcomeMessage: String?
    @State private var transactionId: String?
    @State private var scannedCardCount = 0
    @State private var isCreatingTransaction = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Create a test transaction below, or paste an sdkConfiguration token from your backend. Consent for an existing token must already have been collected when its transaction was created.")
                    Text("Use a new transaction token for each verification. If consent is declined, do not create a transaction or start the SDK.")
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Before you start")
                }

                AgentTransactionForm(isCreating: $isCreatingTransaction, isFieldFocused: $isInputFocused) { token in
                    sdkConfiguration = token
                }

                Section {
                    TextField("sdkConfiguration", text: $sdkConfiguration, axis: .vertical)
                        .lineLimit(4...8)
                        .font(.body.monospaced())
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                        .focused($isInputFocused)
                        .accessibilityLabel("SDK configuration token")
                        .privacySensitive()

                    Button("Start verification", action: startVerification)
                        .disabled(sdkConfiguration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } header: {
                    Text("Transaction token")
                } footer: {
                    Text("The token is used only for this flow and is not saved by the sample.")
                }
                .disabled(isCreatingTransaction)

                if let outcomeMessage {
                    Section("Last verification") {
                        Text(outcomeMessage)
                        if let transactionId {
                            Text("Transaction: \(transactionId)")
                                .textSelection(.enabled)
                        }
                        if scannedCardCount > 0 {
                            Text("Card scan events: \(scannedCardCount)")
                        }
                    }
                }
            }
            .navigationTitle("Custom UI sample")
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isInputFocused = false }
                }
            }
        }
        .fullScreenCover(item: $activeFlow) { flow in
            CustomFlowView(configuration: flow.configuration) { event in
                handle(event, flowId: flow.id)
            }
            .id(flow.id)
            .interactiveDismissDisabled()
        }
    }

    private func startVerification() {
        let token = sdkConfiguration.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty, activeFlow == nil, !isCreatingTransaction else { return }
        isInputFocused = false
        outcomeMessage = nil
        transactionId = nil
        scannedCardCount = 0
        activeFlow = VerificationFlow(configuration: EngineConfiguration(
            service: ServiceSettings(sdkConfiguration: token),
            scannerAppearance: StudioScannerAppearance.make()
        ))
        sdkConfiguration = ""
    }

    private func handle(_ event: StudioEvent, flowId: UUID) {
        guard activeFlow?.id == flowId else { return }
        switch event {
        case .finished(let identifier, let outcome):
            transactionId = identifier
            switch outcome {
            case .verification(let identifier, let state):
                transactionId = identifier
                outcomeMessage = verificationMessage(state)
            case .canceled(let outcome):
                transactionId = outcome.transactionId
                outcomeMessage = cancellationMessage(outcome.reason)
            @unknown default:
                outcomeMessage = "Verification finished with an unrecognized outcome."
            }
            activeFlow = nil
        case .canceled(let identifier, let reason):
            transactionId = identifier
            outcomeMessage = cancellationMessage(reason)
            activeFlow = nil
        case .cardScanned:
            // Intermediate output: keep the flow open. This sample does not retain card data.
            scannedCardCount += 1
        }
    }

    private func verificationMessage(_ state: VerificationState) -> String {
        switch state {
        case .accept: return "Verification accepted."
        case .reject: return "Verification rejected."
        case .review: return "Verification requires review."
        @unknown default: return "Verification returned an unrecognized state."
        }
    }

    private func cancellationMessage(_ reason: CancelReason) -> String {
        switch reason {
        case .userCanceled: return "Verification canceled."
        case .unsupportedWorkflowVersion: return "Update the workflow on the platform before starting a new transaction."
        @unknown default: return "Verification canceled with an unrecognized reason."
        }
    }
}

private struct VerificationFlow: Identifiable {
    let id = UUID()
    let configuration: EngineConfiguration
}

#Preview {
    ContentView()
}
