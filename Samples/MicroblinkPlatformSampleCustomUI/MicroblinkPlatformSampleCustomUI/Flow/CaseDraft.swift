import MicroblinkPlatformEngine
import SwiftUI

struct Draft: Equatable {
    var text: String = ""
    var bool: Bool?
    var date: Date?
    var file: UploadFile?
}

extension Draft {
    init(field: FormField) {
        self.init(text: field.defaultValue ?? "")
        bool = field.defaultValue.flatMap { Bool($0.lowercased()) }
        guard case .dateTime(let subtype) = field.kind, let value = field.defaultValue else { return }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        let formats: [String]
        switch subtype {
        case .date:
            formats = ["yyyy-MM-dd"]
        case .time:
            formats = ["HH:mm:ss", "HH:mm"]
        case .dateTime:
            formats = ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm"]
        @unknown default:
            return
        }
        for format in formats {
            formatter.dateFormat = format
            if let parsed = formatter.date(from: value) {
                date = parsed
                return
            }
        }
    }
}

/// Answers and chosen files for one workflow step. A later error screen must not discard them.
@MainActor
final class CaseDraft: ObservableObject {
    let stepID: Int?
    let request: InputRequest?
    @Published var fields: [String: Draft] = [:]
    @Published var formErrors: [FormFieldError] = []
    @Published var uploadRejection: UploadInputErrorReason?
    @Published var front: UploadFile? {
        didSet { if front != oldValue { uploadRejection = nil } }
    }
    @Published var back: UploadFile? {
        didSet { if back != oldValue { uploadRejection = nil } }
    }
    @Published var file: UploadFile? {
        didSet { if file != oldValue { uploadRejection = nil } }
    }
    @Published var documentType: String?

    init(stepID: Int? = nil, request: InputRequest? = nil) {
        self.stepID = stepID
        self.request = request
        if case .uploadNonIdDocument(let documents, _, _) = request, documents.count == 1 {
            documentType = documents.first?.documentType
        }
    }

    func binding(for field: FormField) -> Binding<Draft> {
        Binding(
            get: { self.fields[field.name] ?? Draft(field: field) },
            set: { value in
                self.fields[field.name] = value
                self.formErrors.removeAll { $0.fieldName == field.name }
            }
        )
    }

    func clearRejectedUploads(_ kind: HostInputKind) {
        switch kind {
        case .uploadIDDocument:
            front = nil
            back = nil
        case .uploadNonIDDocument:
            file = nil
        case .form:
            break
        @unknown default:
            break
        }
    }
}
