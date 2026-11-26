import SwiftUI

enum Studio {
    static let ink = Color(red: 0.10, green: 0.05, blue: 0.14)
    static let panel = Color(red: 0.18, green: 0.10, blue: 0.24)
    static let line = Color(red: 0.46, green: 0.28, blue: 0.56)
    static let cream = Color(red: 0.98, green: 0.93, blue: 0.97)
    static let mute = Color(red: 0.78, green: 0.64, blue: 0.84)
    static let copper = Color(red: 0.96, green: 0.35, blue: 0.58)
    static let moss = Color(red: 0.74, green: 0.52, blue: 0.96)
    static let ember = Color(red: 0.95, green: 0.22, blue: 0.35)
    static let slip = Color(red: 0.98, green: 0.90, blue: 0.95)
}

struct StudioPage<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                Studio.ink.ignoresSafeArea()
                ScrollView {
                    content()
                        .frame(maxWidth: sizeClass == .regular ? 720 : .infinity, alignment: .leading)
                        .frame(maxWidth: .infinity, minHeight: max(proxy.size.height - 40, 0), alignment: .top)
                        .padding(.horizontal, sizeClass == .regular ? 40 : 20)
                        .padding(.vertical, 20)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .foregroundStyle(Studio.cream)
        .tint(Studio.copper)
        .preferredColorScheme(.dark)
    }
}

struct StudioEyebrow: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(Studio.copper)
            .textCase(.uppercase)
    }
}

struct StudioCommand: View {
    enum Tone { case primary, secondary, quiet }

    let title: String
    var tone: Tone = .primary
    let action: () -> Void

    init(_ title: String, tone: Tone = .primary, action: @escaping () -> Void) {
        self.title = title
        self.tone = tone
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.headline, design: .default))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 52)
                .padding(.horizontal, 12)
                .contentShape(Rectangle())
        }
        .buttonStyle(StudioCommandStyle(tone: tone))
    }
}

struct StudioCommandStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused
    @Environment(\.isEnabled) private var isEnabled
    var tone: StudioCommand.Tone

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foreground)
            .background(background.opacity(configuration.isPressed ? 0.82 : 1))
            .overlay(Rectangle().stroke(border, lineWidth: 1))
            .overlay(
                Rectangle()
                    .inset(by: -4)
                    .stroke(Studio.cream, lineWidth: 2)
                    .opacity(isFocused ? 1 : 0)
            )
            .opacity(isEnabled ? 1 : 0.4)
    }

    private var foreground: Color {
        switch tone {
        case .primary: return Studio.ink
        case .secondary: return Studio.cream
        case .quiet: return Studio.mute
        }
    }

    private var background: Color {
        switch tone {
        case .primary: return Studio.copper
        case .secondary, .quiet: return .clear
        }
    }

    private var border: Color {
        switch tone {
        case .primary, .secondary: return Studio.copper
        case .quiet: return Studio.line
        }
    }
}

struct ActivityDock: View {
    let activity: StudioActivity
    let onLeave: () -> Void

    var body: some View {
        if activity != .hidden {
            ZStack(alignment: .bottom) {
                Studio.ink.opacity(0.55).ignoresSafeArea()
                VStack(alignment: .leading, spacing: 12) {
                    Text(label)
                        .font(.system(.body, design: .default))
                        .foregroundStyle(Studio.cream)
                    progress
                    StudioCommand("Leave the case", tone: .quiet, action: onLeave)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Studio.panel)
            }
            .accessibilityElement(children: .contain)
        }
    }

    @ViewBuilder
    private var progress: some View {
        switch activity {
        case .uploading(let percent):
            ProgressView(value: Double(percent), total: 100)
                .tint(Studio.copper)
                .accessibilityLabel(label)
        case .working:
            ProgressView()
                .tint(Studio.copper)
                .accessibilityLabel(label)
        case .hidden:
            EmptyView()
        }
    }

    private var label: String {
        switch activity {
        case .uploading(let percent):
            return "Sending the file, \(percent) percent complete."
        case .working:
            return "Contacting the service."
        case .hidden:
            return ""
        }
    }
}
