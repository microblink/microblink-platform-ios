import Foundation
import MicroblinkPlatformEngine
import UniformTypeIdentifiers

/// The byte cap Engine will accept for one upload. A step's recommended size is only a hint.
struct UploadBudget: Equatable {
    static let engine = UploadBudget(byteCount: UploadValidation.maximumByteCount)

    let byteCount: Int

    var megabytesText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        let megabytes = Double(byteCount) / (1024 * 1024)
        return formatter.string(from: NSNumber(value: megabytes)) ?? ""
    }
}

enum PickedUpload {
    case accepted(UploadFile)
    case rejected(UploadInputErrorReason)
}

/// Reads a security-scoped file and applies Engine's size and signature preflight.
enum UploadStaging {
    static func read(_ url: URL, allowed: [UTType], budget: UploadBudget) -> PickedUpload {
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                url.stopAccessingSecurityScopedResource()
            }
        }
        if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > budget.byteCount {
            return .rejected(.tooLarge)
        }
        guard let data = try? Data(contentsOf: url) else { return .rejected(.unreadable) }
        let types = allowed.compactMap(\.preferredMIMEType)
        if let problem = UploadValidation.rejection(
            byteCount: data.count,
            header: data,
            allowedContentTypes: types,
            maximumByteCount: budget.byteCount
        ) {
            return .rejected(problem)
        }
        guard let contentType = signatureType(of: data) else { return .rejected(.unsupportedType) }
        let name = url.lastPathComponent.isEmpty ? "upload" : url.lastPathComponent
        return .accepted(UploadFile(contentType: contentType, fileName: name, source: .data(data)))
    }

    static func types(from mimeTypes: [String], fallback: [UTType]) -> [UTType] {
        if mimeTypes.isEmpty { return fallback }
        let mapped = mimeTypes.compactMap { raw -> UTType? in
            let mime = raw == "image/jpg" ? "image/jpeg" : raw
            return UTType(mimeType: mime)
        }.filter { [UTType.jpeg, .png, .pdf].contains($0) }
        return mapped.isEmpty ? fallback : mapped
    }

    static func signatureType(of data: Data) -> String? {
        if data.starts(with: [0xFF, 0xD8, 0xFF]) { return "image/jpeg" }
        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return "image/png" }
        if data.starts(with: [0x25, 0x50, 0x44, 0x46]) { return "application/pdf" }
        return nil
    }
}
