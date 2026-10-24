// GenerateView.swift — Shared (macOS + iOS)

import SwiftUI

// MARK: - GenerateView

struct GenerateView: View {
    @ObservedObject var vm: GenerateViewModel
    @StateObject private var exporter = MarkdownExporter()

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: QM.Space.s10) {

                    // API Key
                    if vm.showAPIKeyField {
                        HStack(alignment: .bottom, spacing: QM.Space.s8) {
                            AuthField(label: "Anthropic API Key", placeholder: "sk-ant-...",
                                      text: $vm.inlineAPIKey, secure: true)
                            SmallButton(label: "Save", style: .label) { vm.saveAPIKey() }
                                .padding(.bottom, QM.Space.s8)
                        }
                    }

                    // Prompt form (Figma 01: Form/Field/Generator x2, Form/Text Area)
                    VStack(alignment: .leading, spacing: QM.Space.s10) {
                        GeneratorField(label: "Role or Background",
                                       placeholder: "You are a designer, a cyborg, CEO, joker...",
                                       text: $vm.role)
                        GeneratorField(label: "Goal / Request",
                                       placeholder: "Describe",
                                       text: $vm.goal, multiline: true)
                        GeneratorField(label: "Extras & Adjustments",
                                       placeholder: "Add your odds and ends...",
                                       text: $vm.extraInfo)
                    }

                    Divider().overlay(QM.borderDivider)

                    // Control/Tone + Control/Output Style
                    VStack(spacing: QM.Space.s10) {
                        DropdownControl(title: "Tone", options: vm.tones, selection: $vm.selectedTone)
                        DropdownControl(title: "Output Style", options: vm.outputTypes,
                                        selection: $vm.selectedOutputType)
                    }

                    // Actions/Prompt Form
                    HStack(spacing: QM.Space.s10) {
                        SmallButton(label: vm.isGenerating ? "Generating..." : "Generate Prompt",
                                    style: .label, flexible: true,
                                    isLoading: vm.isGenerating) { vm.generate() }
                        SmallButton(label: "Clear All") { vm.clear() }
                    }

                    // Error
                    let problem = vm.errorMessage.isEmpty ? exporter.errorMessage : vm.errorMessage
                    if !problem.isEmpty {
                        FormMessage(text: problem, kind: .error)
                    }

                    // Result
                    if vm.hasResult {
                        Divider().overlay(QM.borderDivider)
                        ResultSection(vm: vm, onExportMD: exportMD)
                            .id("promptResult")
                    }

                    Spacer(minLength: 16)
                }
                .padding(.horizontal, QM.Space.s20)
                .padding(.vertical, QM.Space.s10)
            }
#if os(iOS)
            .sheet(isPresented: $exporter.isPresentingShare) {
                if let url = exporter.shareURL {
                    ShareSheet(items: [url])
                }
            }
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
            .onChangeCompat(of: vm.generatedPrompt) { newValue in
                if !newValue.isEmpty {
                    withAnimation(.easeOut(duration: 0.35)) {
                        proxy.scrollTo("promptResult", anchor: .top)
                    }
                }
            }
        }
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

// MARK: - ResultSection (Form/Text Area, Toolbar/Result Actions, Form/Inline Input)

struct ResultSection: View {
    @ObservedObject var vm: GenerateViewModel
    let onExportMD: () -> Void
    @State private var showShareSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: QM.Space.s10) {
            if vm.isEditing {
                VStack(alignment: .leading, spacing: QM.Space.s4) {
                    HStack {
                        FieldLabel(text: "Generated Result")
                        Spacer()
                        CountBadge(text: "v\(vm.version)")
                    }
                    TextEditor(text: $vm.generatedPrompt)
                        .font(QM.bodyPrompt)
                        .foregroundColor(QM.textPrimary)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 120)
                        .padding(QM.Space.s4)
                        .qmBox(fill: QM.field, stroke: QM.borderAccentTeal, radius: 0)
                }
            } else {
                ResultTextArea(title: "Generated Result", text: vm.generatedPrompt, version: vm.version)
            }

            if !vm.savedMessage.isEmpty {
                FormMessage(text: vm.savedMessage, kind: .notice)
            }

            HStack(spacing: QM.Space.s8) {
                SmallButton(label: "Export MD", action: onExportMD)
                ResultToolbar(items: [
                    (.copy, vm.copyFlash ? "Copied" : "Copy", vm.copyFlash, { vm.copy() }),
                    (.share, "Share", vm.shareFlash, {
#if os(iOS)
                        showShareSheet = true
#endif
                        vm.share()
                    }),
                    (.save, "Save to history", false, { vm.save(folder: nil) }),
                    (.edit, vm.isEditing ? "Done editing" : "Edit", vm.isEditing, { vm.isEditing.toggle() }),
                ])
            }

            InlineInput(placeholder: "Add constraints...", text: $vm.refineInput,
                        actionLabel: "Refine", isLoading: vm.isRefining) { vm.refine() }
        }
#if os(iOS)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(text: vm.makeShareText())
        }
#endif
    }
}
