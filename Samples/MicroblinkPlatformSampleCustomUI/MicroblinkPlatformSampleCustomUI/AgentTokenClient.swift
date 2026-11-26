import Foundation

/// Development-only transaction creation. Production apps obtain tokens from their backend.
enum AgentTokenClient {
    struct Credentials: Sendable {
        let clientId: String
        let clientSecret: String
    }

    struct Consent: Sendable {
        let isProcessingStoringAllowed: Bool
        let isTrainingAllowed: Bool
        let givenOn: Date
    }

    struct Failure: LocalizedError {
        let message: String

        var errorDescription: String? { message }
    }

    static func create(
        agentURL: String,
        credentials: Credentials,
        workflowId: String,
        userId: String,
        consent: Consent,
        session: URLSession = .shared
    ) async throws -> String {
        guard consent.isProcessingStoringAllowed else {
            throw Failure(message: "Processing and storage consent is required. No transaction was created.")
        }
        let workflowId = workflowId.trimmingCharacters(in: .whitespacesAndNewlines)
        let userId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        let clientId = credentials.clientId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !workflowId.isEmpty, !userId.isEmpty, !clientId.isEmpty, !credentials.clientSecret.isEmpty else {
            throw Failure(message: "Enter a client ID, client secret, workflow ID, and user ID.")
        }
        let base = agentURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let root = URL(string: base),
              root.scheme == "https" || root.scheme == "http",
              let host = root.host, !host.isEmpty else {
            throw Failure(message: "Enter a valid Agent API base URL.")
        }
        var request = URLRequest(url: root.appendingPathComponent("transaction"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let encodedCredentials = Data("\(clientId):\(credentials.clientSecret)".utf8).base64EncodedString()
        request.setValue("Basic \(encodedCredentials)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "workflowId": workflowId,
            "platform": "iOS",
            "consent": [
                "userId": userId,
                "isProcessingStoringAllowed": consent.isProcessingStoringAllowed,
                "isTrainingAllowed": consent.isTrainingAllowed,
                "givenOn": ISO8601DateFormatter().string(from: consent.givenOn)
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        try Task.checkCancellation()
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw Failure(message: "Agent API returned HTTP \(status). Check the URL, credentials, and workflow ID.")
        }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw Failure(message: "The Agent response was not a JSON object.")
        }
        let token = (object["sdkConfiguration"] as? String) ?? (object["SdkConfiguration"] as? String)
        guard let token, !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Failure(message: "The Agent response did not include sdkConfiguration.")
        }
        return token
    }
}
