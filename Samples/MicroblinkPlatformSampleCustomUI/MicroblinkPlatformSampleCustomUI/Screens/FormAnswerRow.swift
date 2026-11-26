import MicroblinkPlatformEngine
import SwiftUI
import UniformTypeIdentifiers

struct FormAnswerRow: View {
    let field: FormField
    @Binding var draft: Draft
    let error: FormFieldError?
    var focusedField: FocusState<String?>.Binding

    private var name: String { field.displayName ?? field.name }
    private var accessibleName: String { field.isRequired ? "\(name), required" : "\(name), optional" }
    private var message: String? {
        guard let error else { return nil }
        return StudioCopy.fieldMessage(field, error: error)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            label
            control
            if let message {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(Studio.ember)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let description = field.description, !description.isEmpty {
                Text(description)
                    .font(.callout)
                    .foregroundStyle(Studio.mute)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) { Rectangle().fill(message == nil ? Studio.line : Studio.ember).frame(height: 1) }
    }

    private var label: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(name)
                .font(.system(.headline, design: .default))
            if !field.isRequired {
                Text("Optional")
                    .font(.caption)
                    .foregroundStyle(Studio.mute)
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var control: some View {
        switch field.kind {
        case .bool:
            boolControl
        case .dateTime(let subtype):
            dateControl(subtype)
        case .file(let subtype):
            AttachmentWell(
                title: "",
                detail: "\(StudioCopy.allowedNames(fileTypes(subtype))) up to \(UploadBudget.engine.megabytesText) MB",
                file: $draft.file,
                allowed: fileTypes(subtype),
                budget: UploadBudget.engine
            )
            .accessibilityLabel(accessibleName)
        case .text, .number:
            textControl
        @unknown default:
            textControl
        }
    }

    private var boolControl: some View {
        HStack(spacing: 8) {
            boolChoice("Yes", value: true)
            boolChoice("No", value: false)
            boolChoice("Unset", value: nil)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibleName)
    }

    private func boolChoice(_ title: String, value: Bool?) -> some View {
        let selected = draft.bool == value
        return Button {
            draft.bool = value
        } label: {
            Text(title)
                .font(.subheadline)
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(selected ? Studio.ink : Studio.cream)
                .background(selected ? Studio.copper : Color.clear)
                .overlay(Rectangle().stroke(Studio.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(accessibleName), \(title)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func dateControl(_ subtype: DateTimeSubtype) -> some View {
        HStack {
            if draft.date != nil {
                DatePicker(
                    "",
                    selection: Binding(get: { draft.date ?? Date() }, set: { draft.date = $0 }),
                    displayedComponents: components(subtype)
                )
                .labelsHidden()
                .accessibilityLabel(accessibleName)
                Button("Clear") { draft.date = nil }
                    .frame(minHeight: 44)
                    .accessibilityLabel("Clear \(name)")
            } else {
                Button(setTitle(subtype)) { draft.date = Date() }
                    .frame(minHeight: 44)
                    .accessibilityLabel("\(accessibleName), \(setTitle(subtype))")
            }
            Spacer(minLength: 0)
        }
    }

    private var textControl: some View {
        TextField(name, text: $draft.text, prompt: Text(name).foregroundStyle(Studio.mute))
            .textFieldStyle(.plain)
            .font(.body)
            .keyboardType(keyboard)
            .textContentType(contentType)
            .textInputAutocapitalization(field.kind == .text(.email) ? .never : .sentences)
            .autocorrectionDisabled(disablesCorrection)
            .focused(focusedField, equals: field.name)
            .frame(minHeight: 44)
            .accessibilityLabel(accessibleName)
            .accessibilityHint(message ?? field.description ?? "")
    }

    private func fileTypes(_ subtype: FileSubtype) -> [UTType] {
        switch subtype {
        case .pdf:
            return [.pdf]
        case .image:
            return [.jpeg, .png]
        @unknown default:
            return [.jpeg, .png]
        }
    }

    private var disablesCorrection: Bool {
        switch field.kind {
        case .text(.email), .text(.phone), .text(.ssn), .number:
            return true
        default:
            return false
        }
    }

    private var keyboard: UIKeyboardType {
        switch field.kind {
        case .text(.email): return .emailAddress
        case .text(.phone): return .phonePad
        case .text(.ssn), .number(.integer): return .numberPad
        case .number(.decimal): return .decimalPad
        default: return .default
        }
    }

    private var contentType: UITextContentType? {
        switch field.kind {
        case .text(.email): return .emailAddress
        case .text(.phone): return .telephoneNumber
        default: return nil
        }
    }

    private func setTitle(_ subtype: DateTimeSubtype) -> String {
        switch subtype {
        case .date: return "Set a date"
        case .time: return "Set a time"
        case .dateTime: return "Set a date and time"
        @unknown default: return "Set a date and time"
        }
    }

    private func components(_ subtype: DateTimeSubtype) -> DatePicker.Components {
        switch subtype {
        case .date: return .date
        case .time: return .hourAndMinute
        case .dateTime: return [.date, .hourAndMinute]
        @unknown default: return [.date, .hourAndMinute]
        }
    }
}
