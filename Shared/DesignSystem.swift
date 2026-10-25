// DesignSystem.swift — Shared (macOS + iOS)
//
// Tokens mirror the Figma file "prompt-generator" (dn6XnEybPsH7QQ71yZVxXe):
// Colors (Light / Dark), Typography, and Spacing collections. Token names below
// match the Figma variable names, so a variable maps to exactly one QM member.

import SwiftUI
import CoreText

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
    /// Hex is RRGGBB, or AARRGGBB when the Figma token has alpha.
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

enum QM {

    // MARK: Colors (Figma: Colors collection, Light / Dark)

    private static let screenHex = (light: "FDF3E8", dark: "17141F")
    private static let fieldHex  = (light: "F5F5F5",   dark: "1A1622")

    // background/*
    static let canvas            = Color.adaptive(light: "FFFFFF", dark: "0B0B0F")
    static let screen            = Color.adaptive(light: screenHex.light, dark: screenHex.dark)
    // surface/*
    /// Strip behind the inactive tabs (Figma header-and-navigation fill, #F6F6F2).
    static let navStrip          = Color.adaptive(light: "F6F6F2", dark: "0B0B0F")
    static let windowHeader      = Color.adaptive(light: "FBE7D2", dark: "2A2138")
    static let field             = Color.adaptive(light: fieldHex.light, dark: fieldHex.dark)
    static let control           = Color.adaptive(light: "0500E5FF", dark: "1A1622")
    static let controlActive     = Color.adaptive(light: "3300E5FF", dark: "1A1622")
    static let selected          = Color(hex: "3300E5FF")
    static let badge             = Color(hex: "80F7D4C2")
    static let input             = Color.adaptive(light: "FFFFFF", dark: "2A2138")
    // action/*
    static let actionPrimary     = Color.adaptive(light: "991060", dark: "F03CAA")
    static let actionPrimaryBackground = Color.adaptive(light: "5FBFAE", dark: "F03CAA")
    static let actionSecondary   = Color.adaptive(light: "FDF3E8", dark: "2A2138")
    /// Button/Large primary fill. Figma paints it with palette/plum-550 directly
    /// (not through a semantic variable), so it has no dark value of its own.
    static let buttonPrimary     = Color(hex: "7A5E8A")
    // text/*
    static let textPrimary       = Color.adaptive(light: "1D1538", dark: "F5F5F5")
    static let textSecondary     = Color.adaptive(light: "7A5E8A", dark: "C9A3FF")
    static let textNavActive     = Color(hex: "C9A3FF")
    static let textControl       = Color.adaptive(light: "3A0420", dark: "F5F5F5")
    static let textAction        = Color.adaptive(light: "991060", dark: "F5F5F5")
    static let textOnAction      = Color(hex: "FDF3E8")
    static let textAccentCoral   = Color(hex: "FF5C8A")
    static let textAccentTeal    = Color(hex: "5FBFAE")
    static let textTagType       = Color(hex: "00E5FF")
    static let textInk           = Color(hex: "000000")
    // border/*
    static let borderWindow      = Color.adaptive(light: "80991060", dark: "2A2138")
    static let borderHeader      = Color.adaptive(light: "80991060", dark: "3A2B47")
    static let borderDivider     = Color.adaptive(light: "1D1538", dark: "3A2B47")
    static let borderDividerStrong = Color.adaptive(light: "681ABB", dark: "3A2B47")
    static let borderDefault     = Color(hex: "7A5E8A")
    static let borderAccentTeal  = Color(hex: "5FBFAE")
    static let borderAccentCoral = Color(hex: "FF5C8A")
    static let borderInput       = Color.adaptive(light: "80991060", dark: "3A2B47")
    static let borderActionSecondary = Color.adaptive(light: "80991060", dark: "FF5C8A")
    // icon/*, status/*
    static let iconDefault       = Color(hex: "5FBFAE")
    static let iconMuted         = Color(hex: "7A5E8A")
    static let windowClose       = Color(hex: "F03CAA")
    static let windowMinimize    = Color(hex: "F0D020")
    static let windowExpand      = Color(hex: "40D080")

    // MARK: Legacy names
    // Older views (Docs, Markdown, API key field) still use these. They now
    // resolve to the Figma tokens so those views pick up the new look.

    static let bgBase        = screen
    static let bgElevated    = field
    static let bgHover       = controlActive
    static let textMuted     = iconMuted
    static let accentCyan    = textAccentTeal
    static let accentMagenta = actionPrimary
    static let accentRed     = textAccentCoral
    static let accentAmber   = Color.adaptive(light: "A06800", dark: "F2A900")
    static let border        = borderDefault
    static let borderTeal    = borderAccentTeal
    static let borderHot     = borderAccentCoral
    static let accentText    = textOnAction

    // MARK: Spacing, radius, stroke (Figma: Spacing collection)

    enum Space {
        static let s2: CGFloat = 2
        static let s4: CGFloat = 4
        static let s8: CGFloat = 8
        static let s10: CGFloat = 10
        static let s12: CGFloat = 12
        static let s16: CGFloat = 16
        static let s20: CGFloat = 20
    }
    enum Radius {
        static let sm: CGFloat = 2
        static let md: CGFloat = 4
        static let window: CGFloat = 5
    }
    /// stroke/default. 0.5pt draws one device pixel on Retina screens.
    static let stroke: CGFloat = 0.5

    // MARK: Typography (Figma text styles)

    private static let jbRegular = "JetBrainsMono-Regular"
    private static let jbMedium  = "JetBrainsMono-Medium"
    private static let jbBold    = "JetBrainsMono-Bold"
    private static let spaceMono = "SpaceMono-Regular"
    private static let geistRegular = "GeistMono-Regular"
    private static let geistBold    = "GeistMono-Bold"

    /// Label/Section: JetBrains Mono Bold 14, tracking 1
    static let labelSection   = Font.custom(jbBold, size: 14, relativeTo: .subheadline)
    /// Navigation/Tab: JetBrains Mono Medium 16
    static let navTab         = Font.custom(jbMedium, size: 16, relativeTo: .callout)
    /// Navigation-Label, active tab: Geist Mono Bold 14
    static let navLabelActive = Font.custom(geistBold, size: 14, relativeTo: .subheadline)
    /// Navigation-Label, state=Default: Geist Mono Regular 14
    static let navLabel       = Font.custom(geistRegular, size: 14, relativeTo: .subheadline)
    /// Body/Prompt: JetBrains Mono Regular 14
    static let bodyPrompt     = Font.custom(jbRegular, size: 14, relativeTo: .subheadline)
    /// Label/Control: Space Mono Regular 12
    static let labelControl   = Font.custom(spaceMono, size: 12, relativeTo: .caption)
    /// Heading/Screen: JetBrains Mono Regular 18
    static let headingScreen  = Font.custom(jbRegular, size: 18, relativeTo: .title3)
    /// Heading/Reference: JetBrains Mono Bold 20
    static let headingReference = Font.custom(jbBold, size: 20, relativeTo: .title3)
    /// Body/Reference: JetBrains Mono Regular 16
    static let bodyReference  = Font.custom(jbRegular, size: 16, relativeTo: .callout)

    /// Legacy size-based font, now JetBrains Mono.
    static func mono(_ size: CGFloat) -> Font { .custom(jbRegular, size: size, relativeTo: .body) }

    /// Registers the bundled fonts. Call once at launch, before any view draws.
    static func registerFonts() {
        for name in [jbRegular, jbMedium, jbBold, spaceMono, geistRegular, geistBold] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    // MARK: Platform colors
    // For AppKit/UIKit APIs that take NSColor/UIColor instead of a SwiftUI Color.

#if os(macOS)
    /// Fixed (non-adaptive) screen color for the app's current theme. The panel sets
    /// its own appearance from the in-app toggle, so the caller picks the mode.
    static func nsBgBase(isLight: Bool) -> NSColor {
        NSColor(Color(hex: isLight ? screenHex.light : screenHex.dark))
    }
#endif

#if os(iOS)
    /// Dynamic field color that resolves against the view's userInterfaceStyle.
    static var uiBgElevated: UIColor {
        UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(Color(hex: fieldHex.dark))
                : UIColor(Color(hex: fieldHex.light))
        }
    }
#endif
}

// MARK: - Bordered shape helper

extension View {
    /// Fill plus a 1pt inside stroke on a rounded rectangle, the box every
    /// Figma control uses.
    func qmBox(fill: Color, stroke: Color, radius: CGFloat = QM.Radius.sm) -> some View {
        self
            .background(RoundedRectangle(cornerRadius: radius).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(stroke, lineWidth: QM.stroke))
    }
}

// MARK: - FieldLabel (Label/Section)

struct FieldLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(QM.labelSection)
            .tracking(1)
            .foregroundColor(QM.textPrimary)
    }
}

// MARK: - FormField

/// A labelled form row, with an "optional" tag when the field can be left blank.
struct FormField<Content: View>: View {
    let label: String
    var optional: Bool = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: QM.Space.s4) {
            HStack(spacing: QM.Space.s8) {
                FieldLabel(text: label)
                if optional {
                    Text("optional")
                        .font(QM.labelControl).foregroundColor(QM.textSecondary)
                }
            }
            content()
        }
    }
}

// MARK: - QMButton (legacy API, Button/Small look)

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

    private var fill: Color {
        switch style {
        case .primary: return QM.actionPrimary
        case .active:  return QM.controlActive
        default:       return isHovered ? QM.controlActive : QM.control
        }
    }
    private var fg: Color {
        switch style {
        case .primary: return QM.textOnAction
        case .danger:  return QM.textAccentCoral
        default:       return QM.textControl
        }
    }
    private var stroke: Color {
        switch style {
        case .primary: return QM.actionPrimary
        case .danger:  return QM.borderAccentCoral
        default:       return QM.borderAccentTeal
        }
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView().scaleEffect(0.6).tint(fg)
                } else {
                    Text(label.uppercased())
                        .font(QM.labelControl)
                        .foregroundColor(fg)
                        .lineLimit(1)
                }
            }
            .frame(width: flexible ? nil : width, height: height)
            .frame(maxWidth: flexible ? .infinity : nil)
            .padding(.horizontal, (flexible || width != nil) ? 0 : QM.Space.s8)
            .qmBox(fill: fill, stroke: stroke)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
#if os(macOS)
        .onHover { isHovered = $0 }
#endif
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}

// MARK: - TagToggle (Tags chip)

struct TagToggle: View {
    let label: String
    @Binding var selected: String
    var isOn: Bool { selected == label }

    var body: some View {
        Button(action: { selected = isOn ? "" : label }) {
            TagChip(text: label, isSelected: isOn)
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
        FlowLayout(spacing: QM.Space.s4) {
            ForEach(items, id: \.self) { TagToggle(label: $0, selected: $selected) }
        }
    }
}
