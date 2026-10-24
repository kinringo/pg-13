// Components.swift — Shared (macOS + iOS)
//
// One SwiftUI view per Figma component in "21 · Global Components" > Section 1.
// Each type names the Figma component it implements.

import SwiftUI

// MARK: - Window/Header

struct WindowHeader: View {
    var body: some View {
        HStack {
            HStack(spacing: QM.Space.s4) {
                dot(QM.windowClose)
                dot(QM.windowMinimize)
                dot(QM.windowExpand)
            }
            Spacer()
            Text("PG-13")
                .font(QM.labelSection)
                .foregroundColor(QM.iconDefault)
        }
        .padding(.horizontal, QM.Space.s12)
        .padding(.vertical, QM.Space.s2)
        .frame(height: 31)
        .background(QM.windowHeader)
        .overlay(Rectangle().strokeBorder(QM.borderHeader, lineWidth: QM.stroke))
        .accessibilityHidden(true)
    }

    private func dot(_ fill: Color) -> some View {
        Circle().fill(fill)
            .overlay(Circle().strokeBorder(QM.borderWindow, lineWidth: QM.stroke))
            .frame(width: 13, height: 13)
    }
}

// MARK: - Navigation/Primary Tabs

/// Tab order matches AppState.activeTab. Slot 1 is DOCS until SKILL is built.
enum AppTab: Int, CaseIterable, Identifiable {
    case prompt = 0, docs, history, folders, profile
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .prompt:  return "PROMPT"
        case .docs:    return "DOCS"
        case .history: return "HISTORY"
        case .folders: return "FOLDERS"
        case .profile: return "PROFILE"
        }
    }
}

struct PrimaryTabs: View {
    @Binding var selection: Int

    var body: some View {
        // Five tabs at Navigation/Tab 16pt need 390pt; a 360pt body falls back to 14pt.
        ViewThatFits(in: .horizontal) {
            tabs(font: QM.navTab)
            tabs(font: QM.navTabCompact)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, QM.Space.s4)
        .padding(.bottom, QM.Space.s8)
        .overlay(alignment: .bottom) {
            Rectangle().fill(QM.borderDivider).frame(height: QM.stroke)
        }
    }

    private func tabs(font: Font) -> some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                if tab != .prompt {
                    Rectangle().fill(QM.borderDefault).frame(width: QM.stroke, height: 21)
                }
                Button(action: { selection = tab.rawValue }) {
                    Text(tab.title)
                        .font(font)
                        .foregroundColor(selection == tab.rawValue ? QM.textNavActive : QM.textSecondary)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, QM.Space.s8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == tab.rawValue ? .isSelected : [])
            }
        }
    }
}

// MARK: - Form/Field/Generator

struct GeneratorField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var multiline: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: QM.Space.s4) {
            FieldLabel(text: label)
            FieldInput(placeholder: placeholder, text: $text, multiline: multiline)
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
            .qmBox(fill: QM.input, stroke: QM.borderInput, radius: QM.Radius.md)
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
    /// Figma Button/Small styles. `control` is teal (CLEAR ALL); `label` is coral (REFINE, GENERATE).
    enum Style { case control, label }

    let label: String
    var style: Style = .control
    var flexible: Bool = false
    var height: CGFloat? = nil
    var isLoading: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(label.uppercased())
                    .font(QM.labelControl)
                    .foregroundColor(style == .label ? QM.textAccentCoral : QM.textControl)
                    .lineLimit(1)
                    .opacity(isLoading ? 0 : 1)
                if isLoading { ProgressView().controlSize(.small).tint(QM.textAccentCoral) }
            }
            .padding(.horizontal, QM.Space.s4)
            .padding(.vertical, QM.Space.s2)
            .frame(maxWidth: flexible ? .infinity : nil, minHeight: height ?? 22,
                   maxHeight: height)
            .qmBox(fill: isHovered ? QM.controlActive : QM.control,
                   stroke: style == .label ? QM.borderAccentCoral : QM.borderAccentTeal,
                   radius: 0)
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
    enum Style { case primary, secondary }

    let label: String
    var style: Style = .primary
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(label.uppercased())
                    .font(QM.navTab)
                    .foregroundColor(style == .primary ? QM.textOnAction : QM.textAction)
                    .opacity(isLoading ? 0 : 1)
                if isLoading {
                    ProgressView().controlSize(.small)
                        .tint(style == .primary ? QM.textOnAction : QM.textAction)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 40)
            .qmBox(fill: style == .primary ? QM.actionPrimary : QM.actionSecondary,
                   stroke: style == .primary ? QM.actionPrimary : QM.borderActionSecondary,
                   radius: QM.Radius.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
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
}

struct IconButton: View {
    let symbol: String
    let accessibilityLabel: String
    var isActive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(QM.iconDefault)
                .frame(width: 32, height: 30)
                .qmBox(fill: isActive ? QM.controlActive : QM.control,
                       stroke: QM.borderAccentCoral, radius: 0)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
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
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
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
                            .background(selection == option ? QM.selected : Color.clear)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(QM.borderDivider).frame(height: QM.stroke)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
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

struct SavedItemHeader: View {
    let title: String
    let date: String
    let tags: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: QM.Space.s4) {
            HStack(alignment: .firstTextBaseline, spacing: QM.Space.s4) {
                Text(title.uppercased())
                    .font(QM.labelSection)
                    .tracking(1)
                    .foregroundColor(QM.textPrimary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(date.uppercased())
                    .font(QM.labelControl)
                    .foregroundColor(QM.textControl)
            }
            if !tags.isEmpty {
                HStack(spacing: QM.Space.s4) {
                    ForEach(tags, id: \.self) { TagChip(text: $0) }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
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
                .font(.system(size: 20))
                .foregroundColor(QM.iconDefault)
                .frame(width: 72, height: 72)
                .background(Circle().fill(QM.control))
                .overlay(Circle().strokeBorder(QM.borderAccentTeal, lineWidth: QM.stroke))
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
            }
            if let actionLabel, let action {
                SmallButton(label: actionLabel, style: .label, action: action)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, QM.Space.s20)
    }
}

// MARK: - Navigation/Back Bar

struct BackBar: View {
    let backLabel: String
    let title: String
    var trailingLabel: String? = nil
    let onBack: () -> Void
    var onTrailing: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: QM.Space.s8) {
            Button(action: onBack) {
                Text("< \(backLabel.uppercased())")
                    .font(QM.labelControl)
                    .foregroundColor(QM.textAccentTeal)
            }
            .buttonStyle(.plain)
            Spacer()
            Text(title.uppercased())
                .font(QM.labelSection)
                .tracking(1)
                .foregroundColor(QM.textAction)
                .lineLimit(1)
            Spacer()
            if let trailingLabel, let onTrailing {
                Button(action: onTrailing) {
                    Text(trailingLabel)
                        .font(QM.labelControl)
                        .foregroundColor(QM.textSecondary)
                }
                .buttonStyle(.plain)
            } else {
                // Keeps the title centred when there is no trailing action.
                Text("< \(backLabel.uppercased())").font(QM.labelControl).hidden()
            }
        }
        .frame(minHeight: 24)
    }
}

// MARK: - Screen title block (Heading/Screen + body)

struct ScreenTitle: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: QM.Space.s4) {
            Text(title)
                .font(QM.headingScreen)
                .foregroundColor(QM.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(QM.bodyPrompt)
                    .foregroundColor(QM.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
