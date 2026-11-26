import SwiftUI

@MainActor
struct AgentTransactionForm: View {
    @Binding var isCreating: Bool
    @FocusState.Binding var isFieldFocused: Bool
    let onTokenCreated: (String) -> Void

    @State private var agentURL = ""
    @State private var clientId = ""
    @State private var clientSecret = ""
    @State private var workflowId = ""
    @State private var userId = UUID().uuidString
    @State private var processingStoringAllowed = true
    @State private var trainingAllowed = true
    @State private var statusMessage: String?

    private var canCreate: Bool {
        processingStoringAllowed && !isCreating && !clientSecret.isEmpty
            && [agentURL, clientId, workflowId, userId].allSatisfy {
                !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
    }

    var body: some View {
        Group {
            Section {
                field("Agent API base URL", text: $agentURL)
                    .keyboardType(.URL)
                field("Client ID", text: $clientId)
                VStack(alignment: .leading) {
                    Text("Client secret")
                    SecureField("Client secret", text: $clientSecret)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($isFieldFocused)
                        .privacySensitive()
                }
                field("Workflow ID", text: $workflowId)
                field("User ID", text: $userId)
            } header: {
                Text("Create a test transaction")
            } footer: {
                Text("Enter the Agent API base URL ending in /agent/api/v2. This development sample keeps credentials in memory only. Production apps create transactions on their backend.")
            }
            .disabled(isCreating)

            Section {
                Toggle("Allow processing and storage (required)", isOn: $processingStoringAllowed)
                Toggle("Allow training (optional)", isOn: $trainingAllowed)
            } header: {
                Text("Consent")
            } footer: {
                Text("Consent applies to the transaction you create below. Without processing and storage consent, no transaction is created. Training permission is optional.")
            }
            .disabled(isCreating)

            Section {
                Button("Create transaction") {
                    guard canCreate else { return }
                    isFieldFocused = false
                    statusMessage = nil
                    isCreating = true
                    Task { await createTransaction() }
                }
                .disabled(!canCreate)
                if isCreating {
                    ProgressView("Creating transaction…")
                }
                if let statusMessage {
                    Text(statusMessage)
                }
            }
        }
    }

    private func field(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading) {
            Text(title)
            TextField(title, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isFieldFocused)
        }
    }

    private func createTransaction() async {
        defer {
            isCreating = false
        }
        do {
            let token = try await AgentTokenClient.create(
                agentURL: agentURL,
                credentials: .init(clientId: clientId, clientSecret: clientSecret),
                workflowId: workflowId,
                userId: userId,
                consent: .init(
                    isProcessingStoringAllowed: processingStoringAllowed,
                    isTrainingAllowed: trainingAllowed,
                    givenOn: Date()
                )
            )
            try Task.checkCancellation()
            processingStoringAllowed = false
            trainingAllowed = false
            onTokenCreated(token)
            statusMessage = "Transaction created. Tap Start verification below."
        } catch {
            guard !Task.isCancelled else { return }
            statusMessage = error.localizedDescription
        }
    }
}
