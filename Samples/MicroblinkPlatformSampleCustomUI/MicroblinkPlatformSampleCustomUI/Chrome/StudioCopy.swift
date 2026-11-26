import MicroblinkPlatformEngine
import UniformTypeIdentifiers

enum StudioCopy {
    static func capabilityTitle(_ type: InteractiveStepType, secondDocument: Bool) -> String {
        switch type {
        case .verifyDocument, .documentScan:
            return secondDocument ? "Second document" : "Identity document"
        case .faceCapture:
            return "Portrait"
        case .cardScan:
            return "Payment card"
        case .form:
            return "Written details"
        case .uploadIDDocument:
            return "Identity file"
        case .uploadNonIDDocument:
            return "Supporting record"
        @unknown default:
            return "Next step"
        }
    }

    static func capabilityDetail(_ type: InteractiveStepType) -> String {
        switch type {
        case .documentScan:
            return "Proceed opens the document scanner. This app continues when that scanner closes."
        case .verifyDocument:
            return "Proceed opens document verification. This app continues when that scanner closes."
        case .faceCapture:
            return "Proceed opens guided portrait capture. This app continues when it closes."
        case .cardScan:
            return "Proceed opens the card scanner. The card is reported back here, and logs keep only the last four digits."
        case .form:
            return "The questions stay on the next screen until you send them."
        case .uploadIDDocument:
            return "Add images of the identity document. A second side is required when the step asks for it."
        case .uploadNonIDDocument:
            return "Choose the record type, then attach one file."
        @unknown default:
            return "Continue when you are ready."
        }
    }

    static func symbol(_ type: InteractiveStepType) -> String {
        switch type {
        case .verifyDocument, .documentScan:
            return "person.text.rectangle"
        case .faceCapture:
            return "face.smiling"
        case .cardScan:
            return "creditcard"
        case .form:
            return "square.and.pencil"
        case .uploadIDDocument:
            return "doc.viewfinder"
        case .uploadNonIDDocument:
            return "paperclip"
        @unknown default:
            return "circle"
        }
    }

    static func proceedTitle(type: InteractiveStepType, hasFinishedStep: Bool, hasPendingInput: Bool) -> String {
        if hasPendingInput {
            switch type {
            case .form:
                return "Open the questions"
            case .uploadIDDocument, .uploadNonIDDocument:
                return "Open the files"
            default:
                return hasFinishedStep ? "Continue" : "Begin"
            }
        }
        switch type {
        case .faceCapture:
            return "Open portrait capture"
        case .cardScan:
            return "Open the card scanner"
        case .documentScan, .verifyDocument:
            return "Open the document scanner"
        default:
            return hasFinishedStep ? "Continue" : "Begin"
        }
    }

    static func allowedNames(_ allowed: [UTType]) -> String {
        var names: [String] = []
        if allowed.contains(.jpeg) { names.append("JPEG") }
        if allowed.contains(.png) { names.append("PNG") }
        if allowed.contains(.pdf) { names.append("PDF") }
        return names.isEmpty ? "file" : names.joined(separator: ", ")
    }

    static func uploadMessage(_ rejection: UploadInputErrorReason, budget: UploadBudget, allowed: [UTType]) -> String {
        switch rejection {
        case .tooLarge:
            return "This file is larger than \(budget.megabytesText) MB."
        case .unsupportedType:
            return "Use a \(allowedNames(allowed)) file."
        case .empty:
            return "The file is empty."
        case .unreadable:
            return "The file could not be read."
        @unknown default:
            return "The file could not be used."
        }
    }

    static func fieldMessage(_ field: FormField, error: FormFieldError) -> String {
        switch error.reason {
        case .required:
            return "This answer is required."
        case .outOfRange:
            return "This answer is outside the allowed range."
        case .wrongType, .invalidFormat:
            return formatMessage(field)
        @unknown default:
            return "This answer cannot be used."
        }
    }

    static func formatMessage(_ field: FormField) -> String {
        switch field.kind {
        case .text(.email):
            return "Enter an email address."
        case .text(.phone):
            return "Enter a phone number."
        case .text(.ssn):
            return "Enter a valid number for this field."
        case .text:
            return "This text cannot be used."
        case .number(.integer):
            return "Enter a whole number."
        case .number(.decimal), .number:
            return "Enter a number."
        case .bool:
            return "Choose yes or no."
        case .dateTime(.date):
            return "Enter a valid date."
        case .dateTime(.time):
            return "Enter a valid time."
        case .dateTime:
            return "Enter a valid date and time."
        case .file(.pdf):
            return "Attach a PDF."
        case .file:
            return "Attach a JPEG or PNG image."
        @unknown default:
            return "This answer cannot be used."
        }
    }
}

struct IssueCopy {
    let title: String
    let message: String

    init(_ error: EngineError) {
        switch error {
        case .noNetwork:
            title = "The connection dropped"
            message = "Nothing else was sent. Try again when the device is back online."
        case .timeout:
            title = "The service timed out"
            message = "The case is still open. You can try this step again."
        case .verificationUnavailable:
            title = "No decision is available"
            message = "The service finished without an accept, decline, or review result."
        case .retryLimitExceeded:
            title = "The retry limit was reached"
            message = "This step cannot be attempted again in this case."
        case .internal(let detail):
            title = "This case cannot continue"
            message = detail
        case .invalidNextInput:
            title = "This step is out of order"
            message = "Go back and continue from the step the case is waiting on."
        case .invalidFormInput:
            title = "Some answers need a correction"
            message = "Return to the questions and fix the marked fields."
        case .invalidUploadInput:
            title = "The file was not accepted"
            message = "Choose a different file and send it again."
        case .stepValidation(let reason, let step):
            let name = StudioCopy.capabilityTitle(step.type, secondDocument: step.isSecondOfSameKind)
            let pair = Self.validationCopy(reason, step: step.type)
            title = pair.title
            message = "\(name). \(pair.message)"
        @unknown default:
            title = "This case cannot continue"
            message = "The service returned a result this sample does not recognize."
        }
    }

    private static func validationCopy(_ reason: StepValidationReason, step: InteractiveStepType) -> (title: String, message: String) {
        switch reason {
        case .retakeSelfie:
            return ("The portrait needs another take", "Capture the face again.")
        case .faceOccluded:
            return ("The face is covered", "Remove anything covering the face, then capture it again with the whole face visible.")
        case .verifyDocumentInvalidInput:
            return ("The document capture could not be used", "Scan the document again.")
        case .verifyDocumentUnsupportedInput, .uploadIDUnsupportedDocument:
            return ("This document is not accepted", "Use a document this step allows.")
        case .uploadNonIDDocumentInvalidInput:
            return ("The record does not match", "Check the selected type and the file, then send it again.")
        case .uploadIDDocumentUploadAgain:
            return ("The identity file was refused", "The previous files were cleared. Choose them again.")
        case .stepCanceled:
            return ("The step was canceled", "You can continue the case.")
        case .generic:
            return genericCopy(step)
        @unknown default:
            return ("This step was not accepted", "Try it again.")
        }
    }

    private static func genericCopy(_ step: InteractiveStepType) -> (title: String, message: String) {
        switch step {
        case .faceCapture:
            return ("The portrait needs another take", "Capture the face again.")
        case .verifyDocument, .documentScan, .cardScan:
            return ("The capture could not be used", "Run the scanner again.")
        default:
            return ("This step was not accepted", "Try it again.")
        }
    }
}
