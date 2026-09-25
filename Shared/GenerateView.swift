// GenerateView.swift — Shared (macOS + iOS)

import SwiftUI

// MARK: - GenerateView

struct GenerateView: View {
    @ObservedObject var vm: GenerateViewModel
    @StateObject private var exporter = MarkdownExporter()

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // API Key
                    if vm.showAPIKeyField {
                        VStack(alignment: .leading, spacing: 5) {
                            FieldLabel(text: "Anthropic API Key")
                            HStack(spacing: 6) {
                                SecureField("sk-ant-...", text: $vm.inlineAPIKey)
                                    .font(QM.mono(12))
                                    .foregroundColor(QM.textPrimary)
                                    .textFieldStyle(.plain)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(QM.bgElevated)
                                    .overlay(Rectangle().stroke(QM.accentAmber.opacity(0.6), lineWidth: 1))
                                QMButton(label: "Save", style: .primary) { vm.saveAPIKey() }
                            }
                        }
                        .padding(.bottom, 12)
                    }

                    // 1. Role
                    FormField(label: "Role or Background") {
                        PlatformTextField(
                            placeholder: "Senior product manager, student, developer…",
                            text: $vm.role)
                    }

                    // 2. Goal
                    FormField(label: "Goal / Request") {
                        PlatformTextArea(
                            placeholder: "What should this prompt help you accomplish?",
                            text: $vm.goal)
                    }

                    // 3. Extra Information (optional)
                    FormField(label: "Extras & Adjustments", optional: true) {
                        PlatformTextArea(
                            placeholder: "Audience, constraints, examples, context…",
                            text: $vm.extraInfo)
                    }

                    // 4. Tone
                    FormField(label: "Tone") {
                        TagFlow(items: vm.tones, selected: $vm.selectedTone)
                    }

                    // 5. Output Type
                    FormField(label: "Output Type") {
                        TagFlow(items: vm.outputTypes, selected: $vm.selectedOutputType)
                    }

                    // Generate + Clear (Figma: wide generate, clear all beside it)
                    HStack(spacing: 10) {
                        QMButton(
                            label: vm.isGenerating ? "Generating..." : "Generate Prompt",
                            style: .primary, height: 30, isLoading: vm.isGenerating, flexible: true
                        ) { vm.generate() }
                        QMButton(label: "Clear All", height: 30) { vm.clear() }
                    }
                    .padding(.top, 14)

                    // Export MD — always visible, mirrors Generate
                    QMButton(label: "Export MD", height: 30, flexible: true) { exportMD() }
                        .padding(.top, 8)

                    // Error
                    let problem = vm.errorMessage.isEmpty ? exporter.errorMessage : vm.errorMessage
                    if !problem.isEmpty {
                        Text(problem)
                            .font(QM.mono(10))
                            .foregroundColor(QM.accentRed)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .overlay(Rectangle().stroke(QM.accentRed.opacity(0.4), lineWidth: 1))
                            .padding(.top, 8)
                    }

                    // Result
                    if vm.hasResult {
                        ResultSection(vm: vm)
                            .id("promptResult")
                            .padding(.top, 14)
                    }

                    Spacer(minLength: 16)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
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
                    .font(QM.mono(13))
                    .foregroundColor(QM.accentCyan)
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

// MARK: - ResultSection

struct ResultSection: View {
    @ObservedObject var vm: GenerateViewModel
    @State private var showShareSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            HStack {
                Text("Generated prompt")
                    .font(QM.mono(9)).foregroundColor(QM.textSecondary).tracking(0.5)
                Spacer()
                Text("v\(vm.version)")
                    .font(QM.mono(9)).foregroundColor(QM.accentAmber)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .overlay(Rectangle().stroke(QM.accentAmber.opacity(0.5), lineWidth: 1))
            }

            if vm.isEditing {
                TextEditor(text: $vm.generatedPrompt)
                    .font(QM.mono(11))
                    .foregroundColor(QM.textPrimary)
                    .scrollContentBackground(.hidden)
                    .background(QM.bgElevated)
                    .frame(minHeight: 120)
                    .overlay(Rectangle().stroke(QM.borderTeal.opacity(0.5), lineWidth: 1))
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    Text(vm.generatedPrompt)
                        .font(QM.mono(11))
                        .foregroundColor(QM.textPrimary)
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .textSelection(.enabled)
                }
                .background(QM.bgElevated)
                .frame(minHeight: 100, maxHeight: 280)
                .overlay(Rectangle().stroke(QM.borderTeal.opacity(0.3), lineWidth: 1))
            }

            if !vm.savedMessage.isEmpty {
                Text(vm.savedMessage)
                    .font(QM.mono(9)).foregroundColor(QM.accentCyan)
            }

            HStack(spacing: 5) { actionButtons }

            // Refine
            HStack(spacing: 4) {
                PlatformTextField(
                    placeholder: "Make it shorter, add constraints…",
                    text: $vm.refineInput,
                    borderOverride: QM.borderHot.opacity(0.5))
                QMButton(label: "Refine →", style: .ghost, isLoading: vm.isRefining) { vm.refine() }
            }
        }
#if os(iOS)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(text: vm.makeShareText())
        }
#endif
    }

    @ViewBuilder var actionButtons: some View {
        QMButton(label: vm.copyFlash  ? "Copied" : "Copy",  style: vm.copyFlash  ? .active : .ghost, flexible: true) { vm.copy() }
        QMButton(label: vm.shareFlash ? "Shared" : "Share", style: vm.shareFlash ? .active : .ghost, flexible: true) {
#if os(iOS)
            showShareSheet = true
#endif
            vm.share()
        }
        QMButton(label: "Save", flexible: true)  { vm.save(folder: nil) }
        QMButton(label: vm.isEditing ? "Done" : "Edit", style: vm.isEditing ? .active : .ghost, flexible: true) { vm.isEditing.toggle() }
    }
}
