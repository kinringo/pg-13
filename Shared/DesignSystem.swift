// DesignSystem.swift — Shared (macOS + iOS)

import SwiftUI

// MARK: - onChange shim (macOS 13 / iOS 16 vs macOS 14 / iOS 17+)

extension View {
    @ViewBuilder
    func onChangeCompat<V: Equatable>(of value: V, perform action: @escaping (V) -> Void) -> some View {
        if #available(macOS 14.0, iOS 17.0, *) {
            self.onChange(of: value) { _, newValue in action(newValue) }
        } else {
            self.onChange(of: value, perform: action)
        }
    }
}

// MARK: - Adaptive Color

extension Color {
    static func adaptive(light: String, dark: String) -> Color {
#if os(iOS)
        Color(UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(Color(hex: dark))
                : UIColor(Color(hex: light))
        })
#else
        Color(NSColor(name: nil) { appearance in
            let darkNames: [NSAppearance.Name] = [
                .darkAqua, .vibrantDark,
                .accessibilityHighContrastDarkAqua,
                .accessibilityHighContrastVibrantDark
            ]
            return darkNames.contains(appearance.name)
                ? NSColor(Color(hex: dark))
                : NSColor(Color(hex: light))
        })
#endif
    }
}

// MARK: - QM Design Tokens
//
// Light — SVG palette: cream bg, dark navy text, teal borders, magenta accents
// Dark  — inverted: near-black bg, light text, same teal/cyan accents

enum QM {
    static let bgBase     = Color.adaptive(light: "FBF0E8", dark: "0D0D0D")
    static let bgElevated = Color.adaptive(light: "F5F5F5", dark: "141414")
    static let bgHover    = Color.adaptive(light: "EDE5DB", dark: "1A0A12")

    static let textPrimary   = Color.adaptive(light: "1D1538", dark: "EAEAEA")
    static let textSecondary = Color.adaptive(light: "4A2840", dark: "8C8C8C")
    static let textMuted     = Color.adaptive(light: "9B8898", dark: "4A4A4A")

    static let accentCyan    = Color(hex: "00E5FF")
    static let accentMagenta = Color.adaptive(light: "991060", dark: "E535AB")
    static let accentRed     = Color.adaptive(light: "CC2030", dark: "E63946")
    static let accentAmber   = Color.adaptive(light: "A06800", dark: "F2A900")

    static let border        = Color.adaptive(light: "C8B8B0", dark: "2A2A2A")
    static let borderTeal    = Color(hex: "5FBFAE")
    static let borderHot     = Color.adaptive(light: "FF5C8A", dark: "E535AB")

    // Always dark — text on bright cyan buttons in both modes
    static let accentText = Color(hex: "1D1538")

    static func mono(_ size: CGFloat) -> Font { .system(size: size, design: .monospaced) }
}

// MARK: - FieldLabel

struct FieldLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(QM.mono(9))
            .foregroundColor(QM.textSecondary)
            .tracking(1.5)
    }
}

// MARK: - FormField

/// A labelled form row, with an "optional" tag when the field can be left blank.
struct FormField<Content: View>: View {
    let label: String
    var optional: Bool = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                FieldLabel(text: label)
                if optional {
                    Text("optional")
                        .font(QM.mono(8)).foregroundColor(QM.textMuted).tracking(0.5)
                }
            }
            content()
        }
        .padding(.bottom, 12)
    }
}

// MARK: - QMButton

enum QMButtonStyle { case primary, ghost, danger, active }

struct QMButton: View {
    let label: String
    var style: QMButtonStyle = .ghost
    var width: CGFloat? = nil
    var height: CGFloat = 28
    var isLoading: Bool = false
    var flexible: Bool = false   // expands to fill available width
    let action: () -> Void

    @State private var isHovered = false

    var bgColor: Color {
        switch style {
        case .primary: return isHovered ? QM.accentCyan.opacity(0.85) : QM.accentCyan
        case .ghost:   return isHovered ? QM.bgHover : QM.bgElevated
        case .danger:  return isHovered ? QM.accentRed.opacity(0.85) : QM.accentRed
        case .active:  return QM.accentMagenta.opacity(0.12)
        }
    }
    var fgColor: Color {
        switch style {
        case .primary: return QM.accentText
        case .ghost:   return QM.textSecondary
        case .danger:  return QM.textPrimary
        case .active:  return QM.accentMagenta
        }
    }
    var borderColor: Color {
        switch style {
        case .ghost:  return QM.border
        case .active: return QM.accentMagenta.opacity(0.4)
        default:      return .clear
        }
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView().scaleEffect(0.6).tint(fgColor)
                } else {
                    Text(label)
                        .font(QM.mono(10))
                        .foregroundColor(fgColor)
                        .tracking(0.5)
                }
            }
            .frame(width: flexible ? nil : width, height: height)
            .padding(.horizontal, (flexible || width != nil) ? 0 : 10)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: flexible ? .infinity : nil)
        .background(bgColor)
        .overlay(Rectangle().stroke(borderColor, lineWidth: 1))
#if os(macOS)
        .onHover { isHovered = $0 }
#endif
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}

// MARK: - TagToggle

struct TagToggle: View {
    let label: String
    @Binding var selected: String
    var isOn: Bool { selected == label }

    var body: some View {
        Button(action: { selected = isOn ? "" : label }) {
            Text(label)
                .font(QM.mono(9))
                .foregroundColor(isOn ? QM.accentCyan : QM.textSecondary)
                .tracking(0.3)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(isOn ? QM.accentCyan.opacity(0.10) : QM.bgElevated)
                .overlay(Rectangle().stroke(isOn ? QM.borderTeal : QM.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - FlowLayout

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var height: CGFloat = 0
        for (i, row) in rows.enumerated() {
            height += row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            if i < rows.count - 1 { height += spacing }
        }
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: ProposedViewSize(width: bounds.width, height: nil), subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            let rowH = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            for sub in row {
                let size = sub.sizeThatFits(.unspecified)
                sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += rowH + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubview]] {
        var rows: [[LayoutSubview]] = [[]]
        var x: CGFloat = 0
        let maxW = proposal.width ?? .infinity
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > maxW && !rows[rows.count - 1].isEmpty { rows.append([]); x = 0 }
            rows[rows.count - 1].append(sub)
            x += size.width + spacing
        }
        return rows
    }
}

// MARK: - TagFlow

struct TagFlow: View {
    let items: [String]
    @Binding var selected: String

    var body: some View {
        FlowLayout(spacing: 5) {
            ForEach(items, id: \.self) { TagToggle(label: $0, selected: $selected) }
        }
    }
}
