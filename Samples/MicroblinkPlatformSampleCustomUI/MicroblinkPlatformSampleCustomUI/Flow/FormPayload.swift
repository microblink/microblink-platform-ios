import Foundation
import MicroblinkPlatformEngine

/// Turns the on-screen answers into the engine's field values, including the v2 date formats.
enum FormPayload {
    static func values(fields: [FormField], drafts: [String: Draft]) -> [FormFieldValue] {
        fields.map { field in
            value(for: field, draft: drafts[field.name] ?? Draft(field: field))
        }
    }

    static func value(for field: FormField, draft: Draft) -> FormFieldValue {
        switch field.kind {
        case .text:
            return .text(fieldName: field.name, value: blankToNil(draft.text))
        case .number(.integer):
            return integer(field: field, text: draft.text)
        case .number(.decimal):
            return decimal(field: field, text: draft.text)
        case .number:
            return .text(fieldName: field.name, value: blankToNil(draft.text))
        case .bool:
            return .bool(fieldName: field.name, value: draft.bool)
        case .dateTime(.date):
            return .date(fieldName: field.name, value: formatted(draft.date, format: "yyyy-MM-dd"))
        case .dateTime(.time):
            return .time(fieldName: field.name, value: formatted(draft.date, format: "HH:mm:ss"))
        case .dateTime(.dateTime), .dateTime:
            return .dateTime(fieldName: field.name, value: formatted(draft.date, format: "yyyy-MM-dd'T'HH:mm:ss"))
        case .file:
            return .file(fieldName: field.name, value: draft.file)
        @unknown default:
            return .text(fieldName: field.name, value: blankToNil(draft.text))
        }
    }

    private static func integer(field: FormField, text: String) -> FormFieldValue {
        let trimmed = blankToNil(text)
        if let trimmed, Int64(trimmed) == nil {
            return .text(fieldName: field.name, value: trimmed)
        }
        return .integer(fieldName: field.name, value: trimmed.flatMap(Int64.init))
    }

    private static func decimal(field: FormField, text: String) -> FormFieldValue {
        let trimmed = blankToNil(text)
        let separator = Locale.current.decimalSeparator ?? "."
        let normalized = trimmed?.replacingOccurrences(of: separator, with: ".")
        let pattern = #"^[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)$"#
        if let normalized, normalized.range(of: pattern, options: .regularExpression) == nil {
            return .text(fieldName: field.name, value: trimmed)
        }
        guard let normalized else {
            return .decimal(fieldName: field.name, value: nil)
        }
        guard let number = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")), !number.isNaN else {
            return .text(fieldName: field.name, value: trimmed)
        }
        return .decimal(fieldName: field.name, value: number)
    }

    private static func blankToNil(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func formatted(_ date: Date?, format: String) -> String? {
        guard let date else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}
