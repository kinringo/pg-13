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

    private static let screenHex = (light: "F1ECF5", dark: "150E1C")
    private static let fieldHex  = (light: "E2DAE9", dark: "1E1726")

    // background/*
    static let canvas            = Color.adaptive(light: "FBF9FD", dark: "0A0510")
    static let screen            = Color.adaptive(light: screenHex.light, dark: screenHex.dark)
    // chrome/*. Four roles, each with exactly one job.
    /// Where you are: the title bar and the current tab.
    static let chromeRose        = Color(hex: "D48AAD")
    /// The action: one primary button per screen.
    static let chromeIce         = Color(hex: "71B7C8")
    /// Progress: loading and in-flight states.
    static let chromeMint        = Color(hex: "91CCBB")
    /// Close and destructive.
    static let chromeCoral       = Color(hex: "C06A64")

    // surface/*
    /// Strip behind the inactive tabs.
    static let navStrip          = Color.adaptive(light: "E2DAE9", dark: "1E1726")
    /// Title bar. Chrome rose means "where you are", so it is fixed across themes.
    static let windowHeader      = chromeRose
    static let field             = Color.adaptive(light: fieldHex.light, dark: fieldHex.dark)
    static let control           = Color.adaptive(light: "FBF9FD", dark: "1E1726")
    static let controlActive     = Color.adaptive(light: "E2DAE9", dark: "251E2E")
    static let selected          = Color.adaptive(light: "E2DAE9", dark: "251E2E")
    static let badge             = Color.adaptive(light: "E2DAE9", dark: "1E1726")
    /// surface/badge-prompt and surface/badge-skill. Chrome, fixed across themes.
    static let badgePrompt       = chromeIce
    static let badgeSkill        = chromeMint
    // action/*
    static let actionPrimary     = Color.adaptive(light: "94436D", dark: "C0789B")
    /// Primary button. Chrome ice: one per screen, and always outlined, because
    /// ice alone is only 1.94 against the light page. The outline carries it.
    static let buttonPrimary     = chromeIce
    // text/*
    static let textPrimary       = Color.adaptive(light: "231933", dark: "EAE6EE")
    static let textSecondary     = Color.adaptive(light: "615971", dark: "A399B0")
    static let textControl       = Color.adaptive(light: "231933", dark: "EAE6EE")
    static let textAction        = Color.adaptive(light: "94436D", dark: "C0789B")
    /// Labels on a chrome fill. Chrome is light in both themes, so this stays
    /// dark: 7.40 on ice, 9.19 on mint, 6.39 on rose.
    static let textOnAction      = Color(hex: "231933")
    static let textAccentCoral   = chromeCoral
    static let textAccentTeal    = Color(hex: "64B3C0")
    /// Figma color/ink: the text colour, so it has to follow the theme. Fixed
    /// dark put the folder count at 1.04 on the dark badge.
    static let textInk           = Color.adaptive(light: "231933", dark: "EAE6EE")
    /// Disabled label. Deliberately under 4.5 (3.16 light, 3.13 dark): hitting
    /// the body threshold would make a dead control look live.
    static let textDisabled      = Color.adaptive(light: "87848E", dark: "65616D")
    // border/*
    /// The outline that every drawn object carries. Ink, so it reads against
    /// any chrome fill: 14.35 on the page, 6.39 on rose, 7.40 on ice.
    static let borderInk         = Color.adaptive(light: "231933", dark: "EAE6EE")
    static let borderWindow      = borderInk
    static let borderHeader      = borderInk
    static let borderDivider     = Color.adaptive(light: "7D778A", dark: "746E81")
    static let borderDividerStrong = Color.adaptive(light: "231933", dark: "EAE6EE")
    static let borderDefault     = borderInk
    static let borderAccentTeal  = borderInk
    static let borderAccentCoral = chromeCoral
    // annotation/recovery: the active tab outline and the tab baseline.
    static let annotationRecovery = Color.adaptive(light: "94436D", dark: "C0789B")
    static let borderInput       = borderInk
    static let borderActionSecondary = borderInk
    // icon/*, status/*
    static let iconDefault       = chromeIce
    static let iconMuted         = Color.adaptive(light: "615971", dark: "A399B0")
    static let windowClose       = chromeCoral
    static let windowMinimize    = chromeRose
    static let windowExpand      = chromeMint

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
    static let accentAmber   = textAccentCoral
    static let border        = borderDefault
    static let borderTeal    = borderAccentTeal
    static let borderHot     = borderAccentCoral
    static let accentText    = textOnAction

    // MARK: Spacing, radius, stroke (Figma: Spacing collection)

    enum Space {
        static let s2: CGFloat = 2
        static let s4: CGFloat = 4
        static let s5: CGFloat = 5
        static let s7: CGFloat = 7
        static let s8: CGFloat = 8
        static let s10: CGFloat = 10
        static let s12: CGFloat = 12
        static let s16: CGFloat = 16
        static let s20: CGFloat = 20
    }
    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 6
        static let window: CGFloat = 8
        /// Top corners of the primary tabs.
        static let tab: CGFloat = 6
    }
    /// stroke/default. Every drawn object carries a 2pt ink outline; the
    /// outline does the separating, which is what lets the fills stay muted.
    static let stroke: CGFloat = 2
    /// Rules and dividers. They separate without enclosing, so they stay quiet.
    static let hairline: CGFloat = 1

    // MARK: Typography (Figma text styles)

    private static let jbRegular = "JetBrainsMono-Regular"
    private static let jbMedium  = "JetBrainsMono-Medium"
    private static let jbBold    = "JetBrainsMono-Bold"
    private static let spaceMono = "SpaceMono-Regular"
    private static let geistRegular = "GeistMono-Regular"
    private static let geistBold    = "GeistMono-Bold"
    /// Manrope ships as a single variable font, so the weight is applied at the
    /// Font level rather than by picking a named file.
    private static let manrope      = "Manrope"

    /// Label/Section: JetBrains Mono Bold 14, tracking 1
    static let labelSection   = Font.custom(jbBold, size: 14, relativeTo: .subheadline)
    /// Navigation/Tab: JetBrains Mono Medium 16
    static let navTab         = Font.custom(jbMedium, size: 16, relativeTo: .callout)
    /// Body/Prompt: JetBrains Mono Regular 14
    static let bodyPrompt     = Font.custom(jbRegular, size: 14, relativeTo: .subheadline)
    /// Label/Control: Space Mono Regular 12
    static let labelControl   = Font.custom(spaceMono, size: 12, relativeTo: .caption)
    /// Heading/Screen: Manrope Medium 18
    static let headingScreen  = Font.custom(manrope, size: 18, relativeTo: .title3).weight(.medium)
    /// Heading/Reference: Manrope SemiBold 20
    static let headingReference = Font.custom(manrope, size: 20, relativeTo: .title3).weight(.semibold)
    /// Page header title at the default size. Manrope, like the other headings,
    /// so it no longer shares labelSection with the wordmark and the tabs.
    static let headingTitle   = Font.custom(manrope, size: 14, relativeTo: .subheadline).weight(.semibold)
    /// Page heading band title. Figma Workstation/Display.
    static let headingDisplay = Font.custom(manrope, size: 28, relativeTo: .title).weight(.semibold)
    /// Folder and saved-item names.
    static let folderName     = Font.custom(manrope, size: 14, relativeTo: .subheadline).weight(.medium)
    /// Body/Reference: JetBrains Mono Regular 16
    static let bodyReference  = Font.custom(jbRegular, size: 16, relativeTo: .callout)

    /// Legacy size-based font, now JetBrains Mono.
    static func mono(_ size: CGFloat) -> Font { .custom(jbRegular, size: size, relativeTo: .body) }

    /// Registers the bundled fonts. Call once at launch, before any view draws.
    static func registerFonts() {
        for name in [jbRegular, jbMedium, jbBold, spaceMono, geistRegular, geistBold, manrope] {
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
    func qmBox(fill: Color, stroke: Color, radius: CGFloat = QM.Radius.sm,
               lineWidth: CGFloat = QM.stroke) -> some View {
        self
            .background(RoundedRectangle(cornerRadius: radius).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(stroke, lineWidth: lineWidth))
    }
}

// MARK: - FieldLabel (Label/Section)

struct FieldLabel: View {
    let text: String
    var body: some View {
        // Sentence case, no tracking: the Workstation frames stopped shouting.
        Text(text)
            .font(QM.labelSection)
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
