import MicroblinkPlatformEngine
import SwiftUI
import UniformTypeIdentifiers

struct DetailsFormScreen: View {
    let fields: [FormField]
    @ObservedObject var draft: CaseDraft
    let onSubmit: ([FormFieldValue]) -> Void
    let onOverview: (() -> Void)?
    let onLeave: () -> Void
    @FocusState private var focusedField: String?

    var body: some View {
        StudioPage {
            VStack(alignment: .leading, spacing: 20) {
                StudioEyebrow(text: "Written details")
                Text("Questions for this step")
                    .font(.system(.largeTitle, design: .default))
                    .fixedSize(horizontal: false, vertical: true)
                Text("Nothing is sent until you use the button below. An unanswered yes-or-no stays unanswered.")
                    .font(.body)
                    .foregroundStyle(Studio.mute)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(fields, id: \.name) { field in
                    FormAnswerRow(
                        field: field,
                        draft: draft.binding(for: field),
                        error: draft.formErrors.first { $0.fieldName == field.name },
                        focusedField: $focusedField
                    )
                }
                StudioCommand("Send answers") {
                    focusedField = nil
                    onSubmit(FormPayload.values(fields: fields, drafts: draft.fields))
                }
                if let onOverview {
                    StudioCommand("Back to the case", tone: .secondary, action: onOverview)
                }
                StudioCommand("Leave the case", tone: .quiet, action: onLeave)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
    }
}

struct IdentityUploadScreen: View {
    let displayName: String?
    let details: String?
    let isOnlyFrontSide: Bool
    let budget: UploadBudget
    @ObservedObject var draft: CaseDraft
    let onSubmit: (UploadFile, UploadFile?) -> Void
    let onOverview: (() -> Void)?
    let onLeave: () -> Void

    private var allowed: [UTType] { [.jpeg, .png] }
    private var canSubmit: Bool {
        draft.front != nil && (isOnlyFrontSide || draft.back != nil)
    }

    var body: some View {
        StudioPage {
            VStack(alignment: .leading, spacing: 20) {
                StudioEyebrow(text: "Identity file")
                Text(heading)
                    .font(.system(.largeTitle, design: .default))
                    .fixedSize(horizontal: false, vertical: true)
                Text(introduction)
                    .font(.body)
                    .foregroundStyle(Studio.mute)
                    .fixedSize(horizontal: false, vertical: true)
                if !isOnlyFrontSide {
                    Text("Both sides are required.")
                        .font(.callout)
                        .foregroundStyle(Studio.copper)
                }
                if let rejection = draft.uploadRejection {
                    Text(StudioCopy.uploadMessage(rejection, budget: budget, allowed: allowed))
                        .font(.callout)
                        .foregroundStyle(Studio.ember)
                        .fixedSize(horizontal: false, vertical: true)
                }
                AttachmentWell(
                    title: isOnlyFrontSide ? "Document" : "Front",
                    detail: wellDetail,
                    file: $draft.front,
                    allowed: allowed,
                    budget: budget
                )
                if !isOnlyFrontSide {
                    AttachmentWell(
                        title: "Back",
                        detail: wellDetail,
                        file: $draft.back,
                        allowed: allowed,
                        budget: budget
                    )
                }
                StudioCommand("Send the document", action: submit)
                    .disabled(!canSubmit)
                if let onOverview {
                    StudioCommand("Back to the case", tone: .secondary, action: onOverview)
                }
                StudioCommand("Leave the case", tone: .quiet, action: onLeave)
            }
        }
    }

    private var heading: String {
        if let displayName, !displayName.isEmpty { return displayName }
        return "Identity document"
    }

    private var introduction: String {
        if let details, !details.isEmpty { return details }
        return "Add a JPEG or PNG for each side this step asks for."
    }

    private var wellDetail: String {
        "\(StudioCopy.allowedNames(allowed)) up to \(budget.megabytesText) MB"
    }

    private func submit() {
        guard let front = draft.front else { return }
        onSubmit(front, isOnlyFrontSide ? nil : draft.back)
    }
}

struct RecordUploadScreen: View {
    let documents: [AllowedDocument]
    let budget: UploadBudget
    @ObservedObject var draft: CaseDraft
    let onSubmit: (String?, UploadFile) -> Void
    let onOverview: (() -> Void)?
    let onLeave: () -> Void
    @State private var pendingType: String?
    @State private var confirmTypeChange = false

    private var selected: AllowedDocument? {
        documents.first { $0.documentType == draft.documentType }
    }

    private var allowed: [UTType] {
        let types = selected?.allowedFileTypes ?? documents.flatMap(\.allowedFileTypes)
        return UploadStaging.types(from: types, fallback: [.jpeg, .png, .pdf])
    }

    private var typeIsRequired: Bool {
        documents.contains { $0.documentType != nil }
    }

    private var canSubmit: Bool {
        draft.file != nil && (!typeIsRequired || draft.documentType != nil)
    }

    var body: some View {
        StudioPage {
            VStack(alignment: .leading, spacing: 20) {
                StudioEyebrow(text: "Supporting record")
                Text(selected?.displayName ?? "Choose a record")
                    .font(.system(.largeTitle, design: .default))
                    .fixedSize(horizontal: false, vertical: true)
                Text(selected?.description ?? "Pick the record type, then attach one file.")
                    .font(.body)
                    .foregroundStyle(Studio.mute)
                    .fixedSize(horizontal: false, vertical: true)
                if documents.count > 1 {
                    typeChooser
                }
                if let rejection = draft.uploadRejection {
                    Text(StudioCopy.uploadMessage(rejection, budget: budget, allowed: allowed))
                        .font(.callout)
                        .foregroundStyle(Studio.ember)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if selected != nil || documents.isEmpty {
                    AttachmentWell(
                        title: "File",
                        detail: "\(StudioCopy.allowedNames(allowed)) up to \(budget.megabytesText) MB",
                        file: $draft.file,
                        allowed: allowed,
                        budget: budget
                    )
                    .id(draft.documentType ?? "")
                }
                StudioCommand("Send the record", action: submit)
                    .disabled(!canSubmit)
                if let onOverview {
                    StudioCommand("Back to the case", tone: .secondary, action: onOverview)
                }
                StudioCommand("Leave the case", tone: .quiet, action: onLeave)
            }
        }
        .confirmationDialog("Change the record type?", isPresented: $confirmTypeChange, titleVisibility: .visible) {
            Button("Change and remove the file", role: .destructive) {
                draft.file = nil
                draft.documentType = pendingType
            }
            Button("Keep the current type", role: .cancel) {}
        } message: {
            Text("The attached file is cleared when the record type changes.")
        }
    }

    private var typeChooser: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(documents.enumerated()), id: \.offset) { _, document in
                    let title = document.displayName ?? document.documentType ?? "Record"
                    let selectedType = document.documentType == draft.documentType
                    Button(title) { select(document) }
                        .font(.system(.subheadline, design: .default))
                        .foregroundStyle(selectedType ? Studio.ink : Studio.cream)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .background(selectedType ? Studio.copper : Color.clear)
                        .overlay(Rectangle().stroke(Studio.line, lineWidth: 1))
                        .accessibilityAddTraits(selectedType ? .isSelected : [])
                }
            }
        }
        .accessibilityLabel("Record type")
    }

    private func select(_ document: AllowedDocument) {
        if draft.file != nil, draft.documentType != document.documentType {
            pendingType = document.documentType
            confirmTypeChange = true
        } else {
            draft.documentType = document.documentType
        }
    }

    private func submit() {
        guard let file = draft.file else { return }
        onSubmit(draft.documentType, file)
    }
}
