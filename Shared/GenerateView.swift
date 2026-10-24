// GenerateView.swift — Shared (macOS + iOS)
//
// Figma desktop 02 (Prompt) and 03 (Skill). Both screens share one layout:
// the form, a divider, the controls, the action row, then the result.

import SwiftUI

// MARK: - GenerateView

struct GenerateView: View {
    @ObservedObject var vm: GenerateViewModel
    @StateObject private var exporter = MarkdownExporter()
    @State private var showFolderInput = false
    @State private var folderName = ""

    var body: some View {
        ScreenScroll(scrollTarget: vm.generatedPrompt) {

            // API Key
            if vm.showAPIKeyField {
                HStack(alignment: .bottom, spacing: QM.Space.s8) {
                    AuthField(label: "Anthropic API Key", placeholder: "sk-ant-...",
                              text: $vm.inlineAPIKey, secure: true)
                    SmallButton(label: "Save", style: .label) { vm.saveAPIKey() }
                        .padding(.bottom, QM.Space.s8)
                }
            }

            // Prompt Form: Form/Field/Generator x3
            VStack(alignment: .leading, spacing: QM.Space.s10) {
                GeneratorField(label: "Role or Background",
                               placeholder: "You are a designer, a cyborg, CEO, joker...",
                               text: $vm.role)
                GeneratorField(label: "Goal / Request",
                               placeholder: "Describe your goal here...",
                               text: $vm.goal, multiline: true, minHeight: 72)
                GeneratorField(label: "Extras & Adjustments",
                               placeholder: "Add your odds and ends...",
                               text: $vm.extraInfo)
            }
            .padding(.bottom, QM.Space.s10)

            SectionDivider()

            // Control/Tone + Control/Output Style
            DropdownControl(title: "Tone", options: vm.tones, selection: $vm.selectedTone)
            DropdownControl(title: "Output Style", options: vm.outputTypes,
                            selection: $vm.selectedOutputType)

            // Actions/Prompt Form
            ActionRow(primaryLabel: vm.isGenerating ? "Generating..." : "Generate Prompt",
                      isLoading: vm.isGenerating,
                      onPrimary: { vm.generate() },
                      onClear: { vm.clear(); showFolderInput = false })

            let problem = vm.errorMessage.isEmpty ? exporter.errorMessage : vm.errorMessage
            if !problem.isEmpty { FormMessage(text: problem, kind: .error) }

            // Generated Prompt
            if vm.hasResult {
                Rectangle().fill(QM.borderDivider).frame(height: QM.stroke)
                ResultSection(
                    title: "Generated Result",
                    text: $vm.generatedPrompt,
                    version: vm.version,
                    isEditing: $vm.isEditing,
                    refineInput: $vm.refineInput,
                    isRefining: vm.isRefining,
                    savedMessage: vm.savedMessage,
                    copyFlash: vm.copyFlash,
                    shareFlash: vm.shareFlash,
                    shareText: vm.makeShareText(),
                    showFolderInput: $showFolderInput,
                    folderName: $folderName,
                    onRefine: { vm.refine() },
                    onCopy: { vm.copy() },
                    onShare: { vm.share() },
                    onSave: { vm.save(folder: $0) },
                    onExportMD: exportMD,
                    onDiscard: { vm.generatedPrompt = ""; vm.version = 0; showFolderInput = false })
                .id(generatedResultID)
            }
        }
#if os(iOS)
        .sheet(isPresented: $exporter.isPresentingShare) {
            if let url = exporter.shareURL { ShareSheet(items: [url]) }
        }
#endif
    }

    private func exportMD() {
        guard vm.hasResult else {
            vm.errorMessage = "Generate a prompt first, then export it as markdown."
            return
        }
        vm.errorMessage = ""
        exporter.export(vm.makeMarkdown(), fileName: Markdown.fileName(for: vm.goal))
    }
}

// MARK: - SkillView

struct SkillView: View {
    @ObservedObject var vm: SkillViewModel
    @StateObject private var exporter = MarkdownExporter()
    @State private var showFolderInput = false
    @State private var folderName = ""

    var body: some View {
        ScreenScroll(scrollTarget: vm.generated) {

            // Skill Form
            VStack(alignment: .leading, spacing: QM.Space.s10) {
                GeneratorField(label: "Skill Name",
                               placeholder: "e.g. weekly-status-report",
                               text: $vm.name)
                GeneratorField(label: "What It Does / When to Use",
                               placeholder: "Describe the task, and the requests that should trigger it",
                               text: $vm.purpose, multiline: true, minHeight: 150)
                GeneratorField(label: "Steps & Rules",
                               placeholder: "Steps to follow, things to never do...",
                               text: $vm.steps)
            }

            ActionRow(primaryLabel: vm.isGenerating ? "Generating..." : "Generate Skill",
                      isLoading: vm.isGenerating,
                      onPrimary: { vm.generate() },
                      onClear: { vm.clear(); showFolderInput = false })

            let problem = vm.errorMessage.isEmpty ? exporter.errorMessage : vm.errorMessage
            if !problem.isEmpty { FormMessage(text: problem, kind: .error) }

            if vm.hasResult {
                SectionDivider()
                ResultSection(
                    title: "SKILL.md",
                    text: $vm.generated,
                    version: vm.version,
                    isEditing: $vm.isEditing,
                    refineInput: $vm.refineInput,
                    isRefining: vm.isRefining,
                    savedMessage: vm.savedMessage,
                    copyFlash: vm.copyFlash,
                    shareFlash: vm.shareFlash,
                    shareText: vm.generated,
                    showFolderInput: $showFolderInput,
                    folderName: $folderName,
                    onRefine: { vm.refine() },
                    onCopy: { vm.copy() },
                    onShare: { vm.share() },
                    onSave: { vm.save(folder: $0) },
                    onExportMD: { exporter.export(vm.generated, fileName: vm.fileName) },
                    onDiscard: { vm.generated = ""; vm.version = 0; showFolderInput = false })
                .id(generatedResultID)
            }
        }
#if os(iOS)
        .sheet(isPresented: $exporter.isPresentingShare) {
            if let url = exporter.shareURL { ShareSheet(items: [url]) }
        }
#endif
    }
}

// MARK: - ScreenScroll

/// The scroll anchor on a generated result.
let generatedResultID = "generatedResult"

/// Screen Body Scroll: content with a 16 gap, scrolled to the result when one arrives.
struct ScreenScroll<Content: View>: View {
    let scrollTarget: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: QM.Space.s16) {
                    content()
                }
                .padding(.horizontal, QM.Space.s20)
                .padding(.bottom, QM.Space.s20)
            }
#if os(iOS)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil)
                    }
                    .font(QM.labelControl)
                    .foregroundColor(QM.textAccentTeal)
                }
            }
#endif
            .onChangeCompat(of: scrollTarget) { newValue in
                if !newValue.isEmpty {
                    withAnimation(.easeOut(duration: 0.35)) {
                        proxy.scrollTo(generatedResultID, anchor: .top)
                    }
                }
            }
        }
    }
}

// MARK: - ActionRow (Actions/Prompt Form)

/// Button/Large (GENERATE) beside Button/Small Share Controls (CLEAR ALL), both 32 tall.
struct ActionRow: View {
    let primaryLabel: String
    let isLoading: Bool
    let onPrimary: () -> Void
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: QM.Space.s10) {
            LargeButton(label: primaryLabel, height: 32, isLoading: isLoading, action: onPrimary)
            SmallButton(label: "Clear All", style: .share, height: 32, action: onClear)
        }
        .padding(.vertical, QM.Space.s4)
    }
}

// MARK: - ResultSection (Form/Text Area, Form/Inline Input, Toolbar/Result Actions)

struct ResultSection: View {
    let title: String
    @Binding var text: String
    let version: Int
    @Binding var isEditing: Bool
    @Binding var refineInput: String
    let isRefining: Bool
    let savedMessage: String
    let copyFlash: Bool
    let shareFlash: Bool
    let shareText: String
    @Binding var showFolderInput: Bool
    @Binding var folderName: String
    let onRefine: () -> Void
    let onCopy: () -> Void
    let onShare: () -> Void
    /// nil saves to History only; a name also files it in that folder.
    let onSave: (String?) -> Void
    let onExportMD: () -> Void
    /// Clears the result (the trash icon). Nothing saved is touched.
    let onDiscard: () -> Void
    @State private var showShareSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: QM.Space.s10) {
            if isEditing {
                VStack(alignment: .leading, spacing: QM.Space.s4) {
                    header
                    TextEditor(text: $text)
                        .font(QM.bodyPrompt)
                        .foregroundColor(QM.textPrimary)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 155)
                        .padding(QM.Space.s4)
                        .qmBox(fill: QM.field, stroke: QM.borderAccentTeal, radius: 0)
                }
            } else {
                ResultTextArea(title: title, text: text, version: version)
            }

            InlineInput(placeholder: "Add constraints...", text: $refineInput,
                        actionLabel: "Refine", isLoading: isRefining, action: onRefine)

            HStack(spacing: QM.Space.s8) {
                SmallButton(label: "Export MD", action: onExportMD)
                ResultToolbar(items: [
                    (.copy, copyFlash ? "Copied" : "Copy", copyFlash, onCopy),
                    (.folder, "Save to a folder", showFolderInput, { showFolderInput.toggle() }),
                    (.share, "Share", shareFlash, {
#if os(iOS)
                        showShareSheet = true
#endif
                        onShare()
                    }),
                    (.save, "Save to history", false, { onSave(nil) }),
                    (.edit, isEditing ? "Done editing" : "Edit", isEditing, { isEditing.toggle() }),
                    (.delete, "Clear result", false, onDiscard),
                ])
            }

            if showFolderInput {
                InlineInput(placeholder: "Folder name...", text: $folderName, actionLabel: "Save") {
                    let name = folderName.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else { return }
                    onSave(name)
                    folderName = ""; showFolderInput = false
                }
            }

            if !savedMessage.isEmpty {
                FormMessage(text: savedMessage, kind: .notice)
            }
        }
#if os(iOS)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(text: shareText)
        }
#endif
    }

    private var header: some View {
        HStack {
            FieldLabel(text: title)
            Spacer()
            CountBadge(text: "v\(version)")
        }
    }
}
