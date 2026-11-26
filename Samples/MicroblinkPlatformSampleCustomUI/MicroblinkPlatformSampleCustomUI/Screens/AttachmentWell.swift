import AVFoundation
import MicroblinkPlatformEngine
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Chooses a JPEG, PNG, or PDF and checks it with Engine's upload rules before the field keeps it.
struct AttachmentWell: View {
    let title: String
    let detail: String
    @Binding var file: UploadFile?
    let allowed: [UTType]
    let budget: UploadBudget

    @State private var rejection: UploadInputErrorReason?
    @State private var showFiles = false
    @State private var showLibrary = false
    @State private var showCamera = false
    @State private var showPreview = false
    @State private var confirmRemove = false
    @State private var photo: PhotosPickerItem?
    @State private var pendingCapture: Data?
    @State private var cameraBlocked = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !title.isEmpty {
                Text(title)
                    .font(.system(.headline, design: .default))
            }
            if let file {
                selected(file)
            } else {
                emptyWell
            }
            Text(detail)
                .font(.caption)
                .foregroundStyle(Studio.mute)
                .fixedSize(horizontal: false, vertical: true)
            if let rejection {
                Text(StudioCopy.uploadMessage(rejection, budget: budget, allowed: allowed))
                    .font(.callout)
                    .foregroundStyle(Studio.ember)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if cameraBlocked {
                VStack(alignment: .leading, spacing: 8) {
                    Text("The camera is off for this app.")
                        .font(.callout)
                        .foregroundStyle(Studio.ember)
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                    .frame(minHeight: 44)
                }
            }
        }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: allowed) { result in
            switch result {
            case .success(let url):
                accept(UploadStaging.read(url, allowed: allowed, budget: budget))
            case .failure:
                accept(.rejected(.unreadable))
            }
        }
        .photosPicker(isPresented: $showLibrary, selection: $photo, matching: .images)
        .fullScreenCover(isPresented: $showCamera, onDismiss: applyCapture) {
            CapturePicker { data in
                pendingCapture = data
                showCamera = false
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showPreview) {
            if let image = previewImage {
                StudioPreview(image: image, name: file?.fileName ?? "Photo", onClose: { showPreview = false }, onRemove: {
                    showPreview = false
                    file = nil
                })
            }
        }
        .confirmationDialog("Remove this file?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Remove", role: .destructive) { file = nil }
            Button("Keep", role: .cancel) {}
        }
        .onChange(of: photo) { _, item in
            guard let item else { return }
            Task { await loadPhoto(item) }
        }
    }

    private var emptyWell: some View {
        Menu {
            if !allowed.isEmpty {
                Button { showFiles = true } label: { Label("Browse files", systemImage: "doc") }
            }
            if allowed.contains(.jpeg) {
                Button { showLibrary = true } label: { Label("Photo library", systemImage: "photo") }
                if CapturePicker.isAvailable {
                    Button { openCamera() } label: { Label("Take a photo", systemImage: "camera") }
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text("Add a file")
                    .font(.system(.title3, design: .default))
                Text("Files, library, or camera")
                    .font(.caption)
                    .foregroundStyle(Studio.mute)
            }
            .frame(maxWidth: .infinity, minHeight: 140, alignment: .leading)
            .padding(16)
            .overlay(Rectangle().stroke(Studio.copper, style: StrokeStyle(lineWidth: 1, dash: [7, 5])))
        }
        .menuOrder(.fixed)
        .accessibilityLabel(title.isEmpty ? "Add a file" : "Add \(title)")
        .accessibilityHint(detail)
    }

    private func selected(_ upload: UploadFile) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let image = previewImage {
                Button { showPreview = true } label: {
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 220)
                }
                .accessibilityLabel(upload.fileName)
            } else {
                Text(upload.contentType == "application/pdf" ? "PDF" : "File")
                    .font(.system(.largeTitle, design: .default))
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
                    .padding(16)
                    .overlay(Rectangle().stroke(Studio.line, lineWidth: 1))
                    .accessibilityHidden(true)
            }
            Text(upload.fileName)
                .font(.system(.callout, design: .monospaced))
                .fixedSize(horizontal: false, vertical: true)
            if case .data(let data) = upload.source {
                Text(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))
                    .font(.caption)
                    .foregroundStyle(Studio.mute)
            }
            Button("Remove \(upload.fileName)", role: .destructive) { confirmRemove = true }
                .frame(minHeight: 44)
                .accessibilityLabel("Remove \(upload.fileName)")
        }
    }

    private var previewImage: Image? {
        guard let file, case .data(let data) = file.source, let image = UIImage(data: data) else { return nil }
        return Image(uiImage: image)
    }

    private func openCamera() {
        guard CapturePicker.isAvailable else { return }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraBlocked = false
            showCamera = true
        case .notDetermined:
            Task {
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                cameraBlocked = !granted
                showCamera = granted
            }
        default:
            cameraBlocked = true
        }
    }

    private func applyCapture() {
        guard let data = pendingCapture else { return }
        pendingCapture = nil
        acceptJPEG(data, name: "photo.jpg")
    }

    private func loadPhoto(_ item: PhotosPickerItem) async {
        let data = try? await item.loadTransferable(type: Data.self)
        let jpeg = data.flatMap { UIImage(data: $0)?.jpegData(compressionQuality: 0.9) }
        if let jpeg {
            acceptJPEG(jpeg, name: "library.jpg")
        } else {
            accept(.rejected(.unreadable))
        }
        photo = nil
    }

    private func acceptJPEG(_ data: Data, name: String) {
        if let problem = UploadValidation.rejection(
            byteCount: data.count,
            header: data,
            allowedContentTypes: allowed.compactMap(\.preferredMIMEType),
            maximumByteCount: budget.byteCount
        ) {
            accept(.rejected(problem))
        } else {
            accept(.accepted(UploadFile(contentType: "image/jpeg", fileName: name, source: .data(data))))
        }
    }

    private func accept(_ picked: PickedUpload) {
        switch picked {
        case .accepted(let upload):
            rejection = nil
            file = upload
        case .rejected(let problem):
            file = nil
            rejection = problem
            AccessibilityNotification.Announcement(StudioCopy.uploadMessage(problem, budget: budget, allowed: allowed)).post()
        }
    }
}

private struct StudioPreview: View {
    let image: Image
    let name: String
    let onClose: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            image
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel(name)
            HStack(spacing: 12) {
                StudioCommand("Close", tone: .secondary, action: onClose)
                StudioCommand("Remove", tone: .quiet, action: onRemove)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Studio.ink.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .accessibilityAddTraits(.isModal)
    }
}
