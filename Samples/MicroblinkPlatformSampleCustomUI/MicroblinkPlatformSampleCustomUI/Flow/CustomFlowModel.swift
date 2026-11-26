import MicroblinkPlatformEngine
import SwiftUI

enum StudioEvent: Equatable {
    case finished(transactionId: String?, outcome: SessionOutcome)
    case canceled(transactionId: String?, reason: CancelReason)
    case cardScanned(CardScanResult)
}

enum StudioActivity: Equatable {
    case hidden
    case working
    case uploading(Int)
}

enum StudioScreen: Equatable {
    case loading
    case journey(WorkflowProgress, step: Step, pending: InputRequest? = nil)
    case input(InputRequest)
    case cameraAccess(shouldShowRationale: Bool, step: Step)
    case issue(EngineError, recoverable: Bool, retry: RetryAction?)
    case outcome(SessionOutcome, transactionId: String?)

    static var unavailable: StudioScreen {
        .issue(
            .internal(message: "The sdk configuration token could not be read."),
            recoverable: false,
            retry: nil
        )
    }
}

/// Host-owned flow for one engine session.
///
/// Ready steps land on the case overview. Opening a form or upload does not call `next`.
/// Scanner steps call `next(.none)`, and the engine presents the vendor capture UI.
/// Leaving the case cancels the session. The final outcome is reported as finished instead.
@MainActor
final class CustomFlowModel: ObservableObject {
    @Published private(set) var screen: StudioScreen = .loading
    @Published private(set) var activity: StudioActivity = .hidden
    @Published private(set) var draft = CaseDraft()
    @Published private(set) var scannerPresentation = ScannerPresentation()

    let configuration: EngineConfiguration
    private let onEvent: (StudioEvent) -> Void
    private var session: (any Session)?
    private var startupCancelReason: CancelReason = .userCanceled
    /// The last ready screen. A recoverable failure may return only here.
    private var readyScreen: StudioScreen?
    private var journeyScreen: StudioScreen?
    private var didStart = false
    private var didFinish = false
    private var statusTask: Task<Void, Never>?
    private var isAdvancing = false

    init(configuration: EngineConfiguration, onEvent: @escaping (StudioEvent) -> Void) {
        self.configuration = configuration
        self.onEvent = onEvent
    }

    var canReturnToOverview: Bool {
        if case .input = screen, journeyScreen != nil { return true }
        return false
    }

    var canRetryIssue: Bool {
        guard case .issue(_, true, let action) = screen, let action else { return false }
        switch action {
        case .callNextWithoutInput, .resubmitHostInput:
            return true
        @unknown default:
            return false
        }
    }

    var issueRetryTitle: String {
        guard case .issue(_, _, let action) = screen, case .some(.resubmitHostInput) = action else {
            return "Try again"
        }
        return "Edit again"
    }

    var issueOffersReturn: Bool {
        guard case .issue(_, true, let action) = screen, case .some(.callNextWithoutInput) = action else { return false }
        return recoveryScreen(for: action) != nil
    }

    func startIfNeeded() async {
        guard didStart == false else { return }
        didStart = true
        switch await MicroblinkPlatformEngine.startSession(configuration) {
        case .success(let start):
            session = start.session
            if didFinish {
                _ = await start.session.cancel(.userCanceled)
                return
            }
            scannerPresentation = start.session.scannerPresentation
            observeStatus()
            apply(start.first)
        case .failure(let error):
            guard !didFinish else { return }
            if case .unsupportedWorkflowVersion = error { startupCancelReason = .unsupportedWorkflowVersion }
            screen = .unavailable
        }
    }

    func openCurrentStep() async {
        guard !isAdvancing, !didFinish else { return }
        switch screen {
        case .journey(_, _, let pending?):
            // Engine is already waiting. Opening the form or upload must not advance the session.
            let next = StudioScreen.input(pending)
            screen = next
            readyScreen = next
        case .journey, .cameraAccess:
            await advance(.none)
        default:
            break
        }
    }

    func returnToOverview() {
        guard !isAdvancing, !didFinish, let journeyScreen else { return }
        screen = journeyScreen
        readyScreen = journeyScreen
    }

    func submit(form values: [FormFieldValue]) async {
        await advance(.formSubmission(values))
    }

    func submitIdentity(front: UploadFile, back: UploadFile?) async {
        await advance(.uploadIdDocument(front: front, back: back))
    }

    func submitRecord(documentType: String?, file: UploadFile) async {
        await advance(.uploadNonIdDocument(documentType: documentType, file: file))
    }

    func retry() async {
        guard !didFinish, case .issue(_, true, let action) = screen else { return }
        switch action {
        case .callNextWithoutInput:
            await advance(.none)
        case .resubmitHostInput:
            if let recovery = recoveryScreen(for: action) {
                screen = recovery
            }
        case nil:
            break
        @unknown default:
            break
        }
    }

    /// Closes the visible screen. A recoverable failure returns to the case when that is still valid.
    func leave() async {
        guard !didFinish else { return }
        if case .outcome(let outcome, let transactionId) = screen {
            finish(transactionId: transactionId, outcome: outcome)
            return
        }
        if case .issue(_, true, let action) = screen, let recovery = recoveryScreen(for: action) {
            screen = recovery
            return
        }
        await abandon()
    }

    /// Cancels the backend transaction even when the visible error could return to an earlier screen.
    func abandon() async {
        guard !didFinish else { return }
        if case .outcome(let outcome, let transactionId) = screen {
            finish(transactionId: transactionId, outcome: outcome)
            return
        }
        didFinish = true
        draft = CaseDraft()
        statusTask?.cancel()
        guard let session else {
            onEvent(.canceled(transactionId: nil, reason: startupCancelReason))
            return
        }
        let outcome = await session.cancel(.userCanceled)
        onEvent(.canceled(transactionId: outcome.transactionId, reason: outcome.reason))
    }

    func confirmOutcome() {
        guard case .outcome(let outcome, let transactionId) = screen else { return }
        finish(transactionId: transactionId, outcome: outcome)
    }

    private func advance(_ input: StepInput) async {
        guard let session, !isAdvancing, !didFinish else { return }
        if case .outcome = screen { return }
        isAdvancing = true
        draft.uploadRejection = nil
        defer { isAdvancing = false }
        let result = await session.next(input)
        guard !didFinish else { return }
        apply(result)
    }

    private func finish(transactionId: String?, outcome: SessionOutcome) {
        guard didFinish == false else { return }
        didFinish = true
        statusTask?.cancel()
        onEvent(.finished(transactionId: transactionId, outcome: outcome))
    }

    private func observeStatus() {
        guard let updates = session?.statusUpdates() else { return }
        statusTask?.cancel()
        statusTask = Task { @MainActor [weak self] in
            for await status in updates {
                self?.activity = Self.activity(for: status)
            }
        }
    }

    private func recoveryScreen(for action: RetryAction?) -> StudioScreen? {
        switch (action, readyScreen) {
        case (.resubmitHostInput, .input), (.callNextWithoutInput, .journey):
            return readyScreen
        default:
            // Polling after host input must not reopen a form the service may already have accepted.
            return nil
        }
    }

    private static func activity(for status: EngineStatus) -> StudioActivity {
        switch status {
        case .uploadingFile(let percent):
            return .uploading(percent)
        case .communicatingWithBackend, .runningEngineStep, .cancelling:
            return .working
        case .idle, .waitingForHost, .terminal:
            return .hidden
        @unknown default:
            return .working
        }
    }

    private func apply(_ result: StepResult) {
        switch result {
        case .ready(_, let workflow, let action, let output):
            emitCard(output)
            applyReady(workflow: workflow, action: action)
        case .blocked(_, _, let blocker):
            applyBlocked(blocker)
        case .failed(_, _, let error, let recoverable, let retry):
            applyFailure(error, recoverable: recoverable, retry: retry)
        case .finished(let transactionId, _, let outcome, let output):
            emitCard(output)
            readyScreen = nil
            draft = CaseDraft()
            screen = .outcome(outcome, transactionId: transactionId)
        @unknown default:
            screen = .unavailable
        }
    }

    private func applyReady(workflow: WorkflowProgress, action: StepAction) {
        let next: StudioScreen
        switch action {
        case .engineStep(let step, _):
            draft = CaseDraft()
            next = .journey(workflow, step: step)
        case .inputStep(let step, let request):
            if draft.stepID != step.id || draft.request != request {
                draft = CaseDraft(stepID: step.id, request: request)
            }
            draft.formErrors = []
            draft.uploadRejection = nil
            next = .journey(workflow, step: step, pending: request)
        @unknown default:
            readyScreen = nil
            screen = .unavailable
            return
        }
        screen = next
        readyScreen = next
        journeyScreen = next
    }

    private func applyBlocked(_ blocker: StepBlocker) {
        guard case .permissionRequired(let permission, let step, _) = blocker,
              case .camera(let shouldShowRationale) = permission else {
            screen = .unavailable
            return
        }
        screen = .cameraAccess(shouldShowRationale: shouldShowRationale, step: step)
    }

    private func applyFailure(_ error: EngineError, recoverable: Bool, retry: RetryAction?) {
        let recovery = recoveryScreen(for: retry)
        if case .stepValidation = error, case .resubmitHostInput(let kind) = retry {
            draft.clearRejectedUploads(kind)
        }
        if case .invalidFormInput(let errors) = error, let recovery, case .input(.form) = recovery {
            draft.formErrors = errors
            screen = recovery
            return
        }
        if case .invalidUploadInput(let rejection) = error, let recovery, case .input = recovery {
            draft.uploadRejection = rejection
            screen = recovery
            return
        }
        if case .stepValidation(.stepCanceled, _) = error, let recovery, case .journey = recovery {
            screen = recovery
            return
        }
        screen = .issue(error, recoverable: recoverable, retry: retry)
    }

    private func emitCard(_ output: StepOutput?) {
        guard case .cardScan(_, let card) = output else { return }
        onEvent(.cardScanned(card))
    }
}
