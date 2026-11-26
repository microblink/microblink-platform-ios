import MicroblinkPlatformEngine
import SwiftUI

struct CustomFlowView: View {
    @StateObject private var model: CustomFlowModel

    init(configuration: EngineConfiguration, onEvent: @escaping (StudioEvent) -> Void) {
        _model = StateObject(wrappedValue: CustomFlowModel(configuration: configuration, onEvent: onEvent))
    }

    var body: some View {
        ZStack {
            screen
                .disabled(model.activity != .hidden)
                .accessibilityHidden(model.activity != .hidden)
            ActivityDock(activity: model.activity, onLeave: abandon)
        }
        .scannerPresentation(model.scannerPresentation)
        .task { await model.startIfNeeded() }
    }

    @ViewBuilder
    private var screen: some View {
        switch model.screen {
        case .loading:
            WaitingView(onLeave: leave)
        case .journey(let workflow, let step, let pending):
            JourneyScreen(workflow: workflow, step: step, pending: pending, onProceed: proceed, onLeave: leave)
        case .input(let request):
            inputScreen(request)
                .id(ObjectIdentifier(model.draft))
        case .cameraAccess(let shouldShowRationale, _):
            CameraAccessScreen(shouldOfferSettings: shouldShowRationale, onRetry: proceed, onLeave: leave)
        case .issue(let error, _, _):
            IssueScreen(
                error: error,
                canRetry: model.canRetryIssue,
                retryTitle: model.issueRetryTitle,
                canReturn: model.issueOffersReturn,
                onRetry: retry,
                onReturn: leave,
                onLeave: abandon
            )
        case .outcome(let outcome, let transactionId):
            OutcomeScreen(outcome: outcome, transactionId: transactionId, onClose: confirm)
        }
    }

    @ViewBuilder
    private func inputScreen(_ request: InputRequest) -> some View {
        switch request {
        case .form(let fields, _):
            DetailsFormScreen(
                fields: fields,
                draft: model.draft,
                onSubmit: submitForm,
                onOverview: overviewAction,
                onLeave: leave
            )
        case .uploadIdDocument(let displayName, let description, let isOnlyFrontSide, _, _):
            IdentityUploadScreen(
                displayName: displayName,
                details: description,
                isOnlyFrontSide: isOnlyFrontSide,
                budget: UploadBudget.engine,
                draft: model.draft,
                onSubmit: submitIdentity,
                onOverview: overviewAction,
                onLeave: leave
            )
        case .uploadNonIdDocument(let documents, _, _):
            RecordUploadScreen(
                documents: documents,
                budget: UploadBudget.engine,
                draft: model.draft,
                onSubmit: submitRecord,
                onOverview: overviewAction,
                onLeave: leave
            )
        @unknown default:
            IssueScreen(
                error: .internal(message: "This input step is not supported by the custom UI sample."),
                canRetry: false,
                retryTitle: "Try again",
                canReturn: false,
                onRetry: {},
                onReturn: {},
                onLeave: abandon
            )
        }
    }

    private var overviewAction: (() -> Void)? {
        guard model.canReturnToOverview else { return nil }
        return { returnToOverview() }
    }

    private func proceed() { Task { await model.openCurrentStep() } }
    private func submitForm(_ values: [FormFieldValue]) { Task { await model.submit(form: values) } }
    private func submitIdentity(_ front: UploadFile, _ back: UploadFile?) {
        Task { await model.submitIdentity(front: front, back: back) }
    }
    private func submitRecord(_ documentType: String?, _ file: UploadFile) {
        Task { await model.submitRecord(documentType: documentType, file: file) }
    }
    private func retry() { Task { await model.retry() } }
    private func leave() { Task { await model.leave() } }
    private func abandon() { Task { await model.abandon() } }
    private func returnToOverview() { model.returnToOverview() }
    private func confirm() { model.confirmOutcome() }
}
