import SwiftUI

/// Floating suggestion panel view
struct SuggestionView: View {
    let suggestion: SuggestionResponse
    let autoDismissSeconds: Int
    let onAccept: (Int) -> Void
    let onDismiss: () -> Void

    @State private var hoveredIndex: Int? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Header: mode badge + close
            HStack {
                ModeBadge(mode: suggestion.mode)
                Spacer()
                HStack(spacing: 8) {
                    if suggestion.latency > 0 {
                        Text(String(format: "%.1fs", suggestion.latency))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    if suggestion.source == .cache {
                        Text("cached")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.15))
                            .cornerRadius(3)
                    }
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()
                .padding(.horizontal, 14)

            // Suggestions
            VStack(spacing: 4) {
                SuggestionRow(
                    text: suggestion.primarySuggestion,
                    shortcut: "⌥1",
                    isPrimary: true,
                    isHovered: hoveredIndex == 0,
                    onTap: { onAccept(0) }
                )
                .onHover { hoveredIndex = $0 ? 0 : nil }

                ForEach(Array(suggestion.alternatives.enumerated()), id: \.offset) { idx, alt in
                    SuggestionRow(
                        text: alt,
                        shortcut: "⌥\(idx + 2)",
                        isPrimary: false,
                        isHovered: hoveredIndex == idx + 1,
                        onTap: { onAccept(idx + 1) }
                    )
                    .onHover { hoveredIndex = $0 ? idx + 1 : nil }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            Spacer(minLength: 4)

            // Hint
            HStack {
                Text("⌥1-3 accept · Esc dismiss · auto-dismiss in \(autoDismissSeconds)s")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.6))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
        }
        .frame(width: AppConstants.panelDefaultWidth)
        .frame(minHeight: 120, maxHeight: 350)
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .cornerRadius(14)
                .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
        )
    }
}

// MARK: - Mode Badge
struct ModeBadge: View {
    let mode: AnalysisMode

    private var label: String {
        switch mode {
        case .chineseToEnglish: return "中→英"
        case .englishToChinese: return "英→中"
        case .englishImprovement: return "润色"
        case .skip: return ""
        }
    }

    private var color: Color {
        switch mode {
        case .chineseToEnglish, .englishToChinese: return .orange
        case .englishImprovement: return .blue
        case .skip: return .gray
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 9))
            Text(label)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(color.opacity(0.12))
        )
    }
}

// MARK: - Suggestion Row
struct SuggestionRow: View {
    let text: String
    let shortcut: String
    let isPrimary: Bool
    let isHovered: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Text(text)
                    .font(.system(size: 14, weight: isPrimary ? .medium : .regular))
                    .foregroundColor(isPrimary ? .primary : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)

                Spacer()

                Text(shortcut)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.7))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.12))
                    .cornerRadius(3)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.accentColor.opacity(0.08) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Visual Effect
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = 14
        view.layer?.masksToBounds = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
