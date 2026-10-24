// Components.swift — Shared (macOS + iOS)
//
// One SwiftUI view per Figma component in "21 · Global Components" > Section 1.
// Each type names the Figma component it implements.

import SwiftUI

// MARK: - Window/Header

/// The PG-13 bar. In Figma the window controls sit on this row. On macOS they are
/// the panel's real traffic lights, drawn by AppKit over this bar (the panel uses
/// a transparent, full-size-content title bar), so the bar leaves room for them.
/// iOS has no window controls, so the bar carries only the PG-13 mark.
struct WindowHeader: View {
    var body: some View {
        HStack {
            Spacer()
            Text("PG-13")
                .font(QM.labelSection)
                .foregroundColor(QM.iconDefault)
        }
#if os(macOS)
        .padding(.leading, WindowHeader.trafficLightsWidth)
        .frame(height: WindowHeader.titleBarHeight)
#else
        .frame(height: 31)
#endif
        .padding(.horizontal, QM.Space.s12)
        .background(QM.windowHeader)
        .overlay(alignment: .bottom) {
            Rectangle().fill(QM.borderHeader).frame(height: QM.stroke)
        }
        .accessibilityHidden(true)
    }

#if os(macOS)
    /// Height of an NSPanel title bar, so PG-13 centres on the traffic lights.
    static let titleBarHeight: CGFloat = 28
    /// Close, minimise and zoom buttons plus their left inset.
    static let trafficLightsWidth: CGFloat = 60
#endif
}

// MARK: - Navigation/Primary Tabs

/// Tab order matches AppState.activeTab.
enum AppTab: Int, CaseIterable, Identifiable {
    case prompt = 0, skill, history, folders, profile
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .prompt:  return "PROMPT"
        case .skill:   return "SKILL"
        case .history: return "HISTORY"
        case .folders: return "FOLDERS"
        case .profile: return "PROFILE"
        }
    }
}

/// The active tab is Navigation/Tab (Medium 16, text/secondary) at its own width.
/// The others are Regular 14 in text/nav-active and share the rest of the row.
struct PrimaryTabs: View {
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                if tab != .prompt {
                    Rectangle().fill(QM.borderDefault).frame(width: QM.stroke, height: 21)
                }
                let isActive = selection == tab.rawValue
                Button(action: { selection = tab.rawValue }) {
                    Text(tab.title)
                        .font(isActive ? QM.navTab : QM.bodyPrompt)
                        .foregroundColor(isActive ? QM.textSecondary : QM.textNavActive)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, QM.Space.s8)
                        .frame(maxWidth: isActive ? nil : .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .layoutPriority(isActive ? 1 : 0)
                .accessibilityAddTraits(isActive ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, QM.Space.s4)
        .padding(.bottom, QM.Space.s8)
        .overlay(alignment: .bottom) {
            Rectangle().fill(QM.borderDivider).frame(height: QM.stroke)
        }
    }
}

// MARK: - Form/Field/Generator

struct GeneratorField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var multiline: Bool = false
    var minHeight: CGFloat? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: QM.Space.s4) {
            FieldLabel(text: label)
            FieldInput(placeholder: placeholder, text: $text, multiline: multiline,
                       minHeight: minHeight)
        }
    }
}

/// The boxed input used by Form/Field/Generator, Form/Text Area and Form/Inline Input.
struct FieldInput: View {
    let placeholder: String
    @Binding var text: String
    var multiline: Bool = false
    var minHeight: CGFloat? = nil
    /// Form/Inline Input uses a 22pt box (padding 2/4) to sit level with Button/Small.
    var compact: Bool = false

    var body: some View {
        Group {
#if os(macOS)
            if multiline {
                ZStack(alignment: .topLeading) {
                    if text.isEmpty { placeholderText.padding(.top, QM.Space.s2) }
                    QMTextArea(text: $text)
                }
            } else {
                ZStack(alignment: .leading) {
                    if text.isEmpty { placeholderText }
                    QMTextField(placeholder: "", text: $text)
                }
            }
#else
            if multiline {
                TextField("", text: $text, prompt: placeholderText, axis: .vertical)
                    .lineLimit(2...8)
            } else {
                TextField("", text: $text, prompt: placeholderText)
            }
#endif
        }
        .font(QM.bodyPrompt)
        .foregroundColor(QM.textPrimary)
        .tint(QM.textAccentTeal)
        .frame(minHeight: minHeight, alignment: .topLeading)
        .padding(.horizontal, compact ? QM.Space.s4 : 0)
        .padding(.leading, compact ? 0 : QM.Space.s4)
        .padding(.top, compact ? QM.Space.s2 : QM.Space.s4)
        .padding(.bottom, compact ? QM.Space.s2 : QM.Space.s8)
        .frame(maxWidth: .infinity, minHeight: compact ? InlineInput.height : nil,
               maxHeight: compact ? InlineInput.height : nil, alignment: .leading)
        .qmBox(fill: QM.field, stroke: QM.borderAccentTeal, radius: 0)
    }

    private var placeholderText: Text {
        Text(placeholder).font(QM.bodyPrompt).foregroundColor(QM.textAccentCoral)
    }
}

// MARK: - Form/Text Area (read-only result with header + version badge)

struct ResultTextArea: View {
    let title: String
    let text: String
    var version: Int? = nil
    var maxHeight: CGFloat = 280

    var body: some View {
        VStack(alignment: .leading, spacing: QM.Space.s4) {
            HStack {
                FieldLabel(text: title)
                Spacer()
                if let v = version { CountBadge(text: "v\(v)") }
            }
            PromptBox(text: text, maxHeight: maxHeight)
        }
    }
}

/// The read-only text box inside Form/Text Area (surface/field, teal outline).
struct PromptBox: View {
    let text: String
    var maxHeight: CGFloat = 280

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            Text(text)
                .font(QM.bodyPrompt)
                .foregroundColor(QM.textPrimary)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .padding(.leading, QM.Space.s4)
                .padding(.top, QM.Space.s4)
                .padding(.bottom, QM.Space.s8)
        }
        .frame(minHeight: 100, maxHeight: maxHeight)
        .qmBox(fill: QM.field, stroke: QM.borderAccentTeal, radius: 0)
    }
}

// MARK: - Form/Inline Input

struct InlineInput: View {
    let placeholder: String
    @Binding var text: String
    let actionLabel: String
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        HStack(spacing: QM.Space.s12) {
            FieldInput(placeholder: placeholder, text: $text, compact: true)
            SmallButton(label: actionLabel, style: .label, height: InlineInput.height,
                        isLoading: isLoading, action: action)
        }
    }

    /// Input and button share one height, as in Figma (22pt plus room for 14pt text).
    static let height: CGFloat = 24
}

// MARK: - Form/Field/Auth

struct AuthField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var secure: Bool = false
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: QM.Space.s8) {
            FieldLabel(text: label)
            Group {
                if secure {
                    SecureField("", text: $text, prompt: prompt)
                } else {
                    TextField("", text: $text, prompt: prompt)
#if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
#endif
                        .autocorrectionDisabled()
                }
            }
            .textFieldStyle(.plain)
            .font(QM.bodyPrompt)
            .foregroundColor(QM.textPrimary)
            .tint(QM.textAccentTeal)
            .padding(.vertical, QM.Space.s8)
            .padding(.horizontal, QM.Space.s10)
            // input-form: Input, and Input selected while the pointer is over it.
            .qmBox(fill: isHovered ? QM.selected : QM.control, stroke: QM.borderInput,
                   radius: QM.Radius.md)
#if os(macOS)
            .onHover { isHovered = $0 }
#endif
        }
    }

    private var prompt: Text {
        Text(placeholder).foregroundColor(QM.textSecondary)
    }
}

// MARK: - Form/Message

struct FormMessage: View {
    enum Kind { case error, notice }
    let text: String
    let kind: Kind

    var body: some View {
        Text(text)
            .font(QM.bodyPrompt)
            .foregroundColor(kind == .error ? QM.textAccentCoral : QM.textAccentTeal)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Button/Small

struct SmallButton: View {
    /// Figma Button/Small styles:
    /// - `control`: teal box, Space Mono (Export MD, Export All MD).
    /// - `label`: coral outline, JetBrains Mono 14 (REFINE, SAVE, BACK TO SIGN IN).
    /// - `share`: coral outline, Space Mono (CLEAR ALL).
    enum Style { case control, label, share }

    let label: String
    var style: Style = .control
    var flexible: Bool = false
    var height: CGFloat? = nil
    var isLoading: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    private var font: Font { style == .label ? QM.bodyPrompt : QM.labelControl }
    private var textColor: Color {
        switch style {
        case .control: return QM.textControl
        case .label:   return QM.textAccentCoral
        case .share:   return isHovered ? QM.textAccentCoral : QM.textControl
        }
    }
    private var fill: Color {
        switch style {
        case .control:        return isHovered ? QM.controlActive : QM.control
        case .label, .share:  return isHovered ? QM.control : .clear
        }
    }
    private var strokeColor: Color {
        switch style {
        case .control: return QM.borderAccentTeal
        case .label:   return isHovered ? QM.borderAccentTeal : QM.borderAccentCoral
        case .share:   return isHovered ? QM.borderDefault : QM.borderAccentCoral
        }
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(label.uppercased())
                    .font(font)
                    .foregroundColor(textColor)
                    .lineLimit(1)
                    .opacity(isLoading ? 0 : 1)
                if isLoading { ProgressView().controlSize(.small).tint(QM.textAccentCoral) }
            }
            .padding(.horizontal, QM.Space.s4)
            .padding(.vertical, QM.Space.s2)
            .frame(maxWidth: flexible ? .infinity : nil, minHeight: height ?? 22,
                   maxHeight: height)
            .qmBox(fill: fill, stroke: strokeColor, radius: 0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
#if os(macOS)
        .onHover { isHovered = $0 }
#endif
    }
}

// MARK: - Button/Large

struct LargeButton: View {
    /// Figma Button/Large: `primary` is the filled plum button, `secondary` the
    /// light one with an outline. A press shows the other look for a moment,
    /// as the prototype does.
    enum Style { case primary, secondary }

    let label: String
    var style: Style = .primary
    /// 40 on Profile, 32 when it shares a row with Button/Small (GENERATE).
    var height: CGFloat = 40
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(label.uppercased())
                    .font(QM.navTab)
                    .lineLimit(1)
                    .opacity(isLoading ? 0 : 1)
                if isLoading {
                    // The system spinner follows the color scheme, not tint, on macOS:
                    // a dark scheme draws it light enough to read on the plum fill.
                    ProgressView().controlSize(.small)
                        .environment(\.colorScheme, style == .primary ? .dark : .light)
                }
            }
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
            .contentShape(Rectangle())
        }
        .buttonStyle(LargeButtonStyle(style: style))
        .disabled(isLoading)
    }
}

private struct LargeButtonStyle: ButtonStyle {
    let style: LargeButton.Style

    func makeBody(configuration: Configuration) -> some View {
        let filled = (style == .primary) != configuration.isPressed
        return configuration.label
            .foregroundColor(filled ? QM.textOnAction : QM.textSecondary)
            .tint(filled ? QM.textOnAction : QM.textSecondary)
            .qmBox(fill: filled ? QM.buttonPrimary : QM.badge,
                   stroke: filled ? QM.buttonPrimary : QM.borderActionSecondary,
                   radius: QM.Radius.sm)
    }
}

// MARK: - Button/Icon + Toolbar/Result Actions

/// The six result actions, in Figma order. SF Symbols stand in for the Figma icons.
enum ResultAction: CaseIterable, Identifiable {
    case copy, folder, share, save, edit, delete
    var id: Self { self }
    var symbol: String {
        switch self {
        case .copy:   return "doc.on.doc"
        case .folder: return "folder"
        case .share:  return "square.and.arrow.up"
        case .save:   return "arrow.down.to.line"
        case .edit:   return "pencil"
        case .delete: return "trash"
        }
    }
    /// The label Button/Icon shows on hover (Type=With Label).
    var title: String {
        switch self {
        case .copy:   return "Copy"
        case .folder: return "Folder"
        case .share:  return "Share"
        case .save:   return "Save"
        case .edit:   return "Edit"
        case .delete: return "Delete"
        }
    }
}

struct IconButton: View {
    let symbol: String
    /// Shown beside the icon on hover, as Figma's Type=With Label variant.
    var title: String? = nil
    let accessibilityLabel: String
    var isActive: Bool = false
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(QM.iconDefault)
                    .frame(width: 24, height: 24)
                if isHovered, let title {
                    Text(title.uppercased())
                        .font(QM.labelControl)
                        .foregroundColor(QM.textControl)
                        .lineLimit(1)
                        .padding(.horizontal, QM.Space.s4)
                }
            }
            .padding(.horizontal, QM.Space.s4)
            .frame(minWidth: 32, minHeight: 30, maxHeight: 30)
            .qmBox(fill: isActive ? QM.controlActive : QM.control,
                   stroke: QM.borderAccentCoral, radius: 0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
#if os(macOS)
        .onHover { isHovered = $0 }
#endif
    }
}

struct ResultToolbar: View {
    /// Actions to show, each with its label for VoiceOver and its handler.
    let items: [(action: ResultAction, label: String, active: Bool, run: () -> Void)]

    var body: some View {
        HStack(spacing: QM.Space.s8) {
            Spacer(minLength: 0)
            ForEach(items.indices, id: \.self) { i in
                IconButton(symbol: items[i].action.symbol,
                           title: items[i].action.title,
                           accessibilityLabel: items[i].label,
                           isActive: items[i].active,
                           action: items[i].run)
            }
        }
    }
}

// MARK: - Tags (chip)

struct TagChip: View {
    let text: String
    var isSelected: Bool = false

    var body: some View {
        Text(text.uppercased())
            .font(QM.labelControl)
            .foregroundColor(QM.textControl)
            .lineLimit(1)
            .padding(.horizontal, QM.Space.s4)
            .padding(.vertical, QM.Space.s2)
            .qmBox(fill: isSelected ? QM.controlActive : QM.control,
                   stroke: QM.borderAccentTeal)
    }
}

/// Tags, Label and Type variants: the PROMPT / SKILL badge on a saved item.
struct KindChip: View {
    let kind: RecordKind

    var body: some View {
        Text(kind.title)
            .font(QM.bodyPrompt)
            .foregroundColor(kind == .skill ? QM.textOnAction : QM.textAction)
            .lineLimit(1)
            .padding(.horizontal, QM.Space.s8)
            .padding(.vertical, QM.Space.s4)
            .background(RoundedRectangle(cornerRadius: QM.Radius.sm)
                .fill(kind == .skill ? QM.actionPrimaryBackground : QM.controlActive))
    }
}

// MARK: - Badge/Count and Badge/Count Arrow

struct CountBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(QM.labelControl)
            .foregroundColor(QM.textInk)
            .padding(.horizontal, QM.Space.s4)
            .frame(minWidth: 24, minHeight: 24)
            .qmBox(fill: QM.badge, stroke: QM.borderAccentCoral)
    }
}

// MARK: - Control/Tone and Control/Output Style (dropdown)

struct DropdownControl: View {
    let title: String
    let options: [String]
    @Binding var selection: String
    @State private var isOpen = false
    @State private var hoveredOption: String? = nil
    @State private var headerHovered = false

    var body: some View {
        VStack(spacing: 0) {
            Button(action: { withAnimation(.easeOut(duration: 0.15)) { isOpen.toggle() } }) {
                HStack {
                    Text("\(title.uppercased()): \(selection.uppercased())")
                        .font(QM.navTab)
                        .foregroundColor(QM.textControl)
                        .lineLimit(1)
                    Spacer()
                    Text(isOpen ? "-" : (selection.isEmpty ? "+" : "✓"))
                        .font(QM.navTab)
                        .foregroundColor(QM.textControl)
                }
                .padding(.horizontal, QM.Space.s8)
                .padding(.vertical, QM.Space.s4)
                .background(headerHovered && !isOpen ? QM.selected : Color.clear)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
#if os(macOS)
            .onHover { headerHovered = $0 }
#endif
            .accessibilityValue(selection.isEmpty ? "None" : selection)

            if isOpen {
                VStack(spacing: 0) {
                    ForEach(options, id: \.self) { option in
                        Button(action: {
                            selection = selection == option ? "" : option
                            withAnimation(.easeOut(duration: 0.15)) { isOpen = false }
                        }) {
                            HStack {
                                Text(option.uppercased())
                                    .font(QM.navTab)
                                    .foregroundColor(QM.textControl)
                                Spacer()
                            }
                            .padding(QM.Space.s8)
                            .background(selection == option || hoveredOption == option
                                        ? QM.selected : Color.clear)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(QM.borderDivider).frame(height: QM.stroke)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
#if os(macOS)
                        .onHover { hoveredOption = $0 ? option : (hoveredOption == option ? nil : hoveredOption) }
#endif
                        .accessibilityAddTraits(selection == option ? .isSelected : [])
                    }
                }
                .padding(.horizontal, QM.Space.s8)
                .padding(.bottom, QM.Space.s4)
            }
        }
        .qmBox(fill: QM.control, stroke: QM.borderAccentTeal)
    }
}

// MARK: - List/Folder Row

struct FolderRow: View {
    let name: String
    let count: Int
    let onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack {
                HStack(spacing: QM.Space.s16) {
                    Image(systemName: "folder")
                        .font(.system(size: 17))
                        .foregroundColor(QM.iconDefault)
                    Text(name.uppercased())
                        .font(QM.labelSection)
                        .tracking(1)
                        .foregroundColor(QM.textPrimary)
                        .lineLimit(1)
                }
                Spacer()
                HStack(spacing: QM.Space.s16) {
                    CountBadge(text: String(format: "%02d", count))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 15))
                        .foregroundColor(QM.iconMuted)
                }
            }
            .padding(.horizontal, QM.Space.s10)
            .padding(.vertical, QM.Space.s16)
            .background(isHovered ? QM.selected : Color.clear)
            .overlay(alignment: .bottom) {
                Rectangle().fill(QM.borderDefault).frame(height: QM.stroke)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
#if os(macOS)
        .onHover { isHovered = $0 }
#endif
    }
}

// MARK: - List/Saved Item (header)

/// Collapsed: name and date, then the PROMPT / SKILL badge and a chevron down.
/// Expanded: name and a chevron up, then the tone and style chips.
struct SavedItemHeader: View {
    let title: String
    let date: String
    let kind: RecordKind
    let tags: [String]
    let isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: QM.Space.s8) {
            HStack(alignment: .center, spacing: QM.Space.s4) {
                Text(title.uppercased())
                    .font(QM.labelSection)
                    .tracking(1)
                    .foregroundColor(QM.textPrimary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if isExpanded {
                    chevron("chevron.up")
                } else {
                    Text(date.uppercased())
                        .font(QM.labelControl)
                        .foregroundColor(QM.textControl)
                }
            }
            if isExpanded {
                if !tags.isEmpty {
                    HStack(spacing: QM.Space.s4) {
                        ForEach(tags, id: \.self) { TagChip(text: $0) }
                    }
                }
            } else {
                HStack(spacing: QM.Space.s4) {
                    KindChip(kind: kind)
                    Spacer(minLength: 0)
                    chevron("chevron.down")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func chevron(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .regular))
            .foregroundColor(QM.iconDefault)
            .frame(width: 24, height: 23)
            .accessibilityHidden(true)
    }
}

// MARK: - State/Empty

struct EmptyState: View {
    let title: String
    let message: String
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: QM.Space.s12) {
            Image(systemName: "folder")
                .font(.system(size: 30, weight: .light))
                .foregroundColor(QM.iconDefault)
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
            VStack(spacing: QM.Space.s8) {
                Text(title.uppercased())
                    .font(QM.labelSection)
                    .tracking(1)
                    .foregroundColor(QM.textPrimary)
                Text(message)
                    .font(QM.bodyPrompt)
                    .foregroundColor(QM.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            }
            if let actionLabel, let action {
                SmallButton(label: actionLabel, style: .label, action: action)
            }
        }
        .padding(.horizontal, QM.Space.s20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Navigation/Back Bar

struct BackBar: View {
    /// Read by VoiceOver for the chevron, e.g. "Back to Folders".
    let backLabel: String
    let title: String
    var trailingLabel: String? = nil
    let onBack: () -> Void
    var onTrailing: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: QM.Space.s8) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(QM.iconDefault)
                    .frame(width: 24, height: 23)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to \(backLabel)")
            Text(title.uppercased())
                .font(QM.navTab)
                .foregroundColor(QM.textAction)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
            if let trailingLabel, let onTrailing {
                Button(action: onTrailing) {
                    Text(trailingLabel)
                        .font(QM.labelControl)
                        .foregroundColor(QM.textSecondary)
                        .frame(minWidth: 24)
                }
                .buttonStyle(.plain)
            } else {
                // Keeps the title centred when there is no trailing action.
                Color.clear.frame(width: 24, height: 23)
            }
        }
        .frame(minHeight: 24)
    }
}

// MARK: - Screen title block (Heading/Screen + body)

/// The Auth Header block on Profile: centred heading and subtitle.
struct ScreenTitle: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: QM.Space.s4) {
            Text(title.uppercased())
                .font(QM.headingScreen)
                .foregroundColor(QM.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(QM.bodyPrompt)
                    .foregroundColor(QM.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }
}

/// Centred text link (Forgot password?, Back to Sign In, Change Password).
struct TextLink: View {
    let label: String
    var color: Color = QM.textSecondary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(QM.bodyPrompt)
                .foregroundColor(color)
                .padding(QM.Space.s4)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// divider-frame: a hairline with 10 above and below.
struct SectionDivider: View {
    var body: some View {
        Rectangle().fill(QM.borderDivider).frame(height: QM.stroke)
            .padding(.vertical, QM.Space.s10)
    }
}
