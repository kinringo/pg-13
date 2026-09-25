// PlatformFields.swift — Shared (macOS + iOS)

import SwiftUI

// MARK: - iOS share sheet

#if os(iOS)
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    init(text: String)   { items = [text] }
    init(items: [Any])   { self.items = items }
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
#endif

// Markdown export lives in Markdown.swift (MarkdownExporter).

// MARK: - macOS text fields

#if os(macOS)
import AppKit

// Single-line NSTextField
struct QMTextField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSTextField {
        let f = NSTextField()
        f.placeholderString = placeholder
        f.stringValue = text
        f.isBordered = false
        f.isBezeled = false
        f.drawsBackground = false
        f.focusRingType = .none
        f.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        f.textColor = .labelColor          // adaptive: dark in light mode, light in dark
        f.maximumNumberOfLines = 1
        f.cell?.wraps = false
        f.cell?.isScrollable = true
        f.delegate = context.coordinator
        return f
    }

    func updateNSView(_ v: NSTextField, context: Context) {
        if v.stringValue != text { v.stringValue = text }
        v.placeholderString = placeholder
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: QMTextField
        init(_ p: QMTextField) { parent = p }
        func controlTextDidChange(_ obj: Notification) {
            guard let f = obj.object as? NSTextField else { return }
            parent.text = f.stringValue
        }
    }
}

// Multiline NSTextView — subclass forces focus in nonActivatingPanel
private class _QMTextView: NSTextView {
    override var acceptsFirstResponder: Bool { true }
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }
}

struct QMTextArea: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let sv = NSScrollView()
        sv.hasVerticalScroller = false
        sv.hasHorizontalScroller = false
        sv.drawsBackground = false
        sv.borderType = .noBorder

        let tv = _QMTextView()
        tv.isEditable = true
        tv.isSelectable = true
        tv.isRichText = false
        tv.allowsUndo = true
        tv.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        tv.textColor = .labelColor             // adaptive
        tv.insertionPointColor = NSColor(QM.accentCyan)
        tv.backgroundColor = .clear
        tv.drawsBackground = false
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.textContainerInset = NSSize(width: 0, height: 2)
        tv.textContainer?.lineFragmentPadding = 0
        tv.textContainer?.widthTracksTextView = true
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.delegate = context.coordinator
        if !text.isEmpty { tv.string = text }
        sv.documentView = tv
        return sv
    }

    func updateNSView(_ sv: NSScrollView, context: Context) {
        guard let tv = sv.documentView as? _QMTextView else { return }
        if tv.string != text { tv.string = text }
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: QMTextArea
        init(_ p: QMTextArea) { parent = p }
        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
        }
    }
}

#endif // os(macOS)

// MARK: - Cross-platform styled wrappers

struct PlatformTextField: View {
    let placeholder: String
    @Binding var text: String
    var borderOverride: Color? = nil

    private var stroke: Color { borderOverride ?? QM.borderTeal.opacity(0.4) }

    var body: some View {
#if os(macOS)
        QMTextField(placeholder: placeholder, text: $text)
            .frame(height: 34)
            .padding(.horizontal, 10)
            .background(QM.bgElevated)
            .overlay(Rectangle().stroke(stroke, lineWidth: 1))
#else
        TextField(placeholder, text: $text)
            .font(QM.mono(12))
            .foregroundColor(QM.textPrimary)
            .tint(QM.accentCyan)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(QM.bgElevated)
            .overlay(Rectangle().stroke(stroke, lineWidth: 1))
#endif
    }
}

struct PlatformTextArea: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
#if os(macOS)
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(QM.mono(12))
                    .foregroundColor(QM.textMuted)
                    .padding(.top, 4)
                    .allowsHitTesting(false)
            }
            QMTextArea(text: $text)
        }
        .frame(minHeight: 64)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(QM.bgElevated)
        .overlay(Rectangle().stroke(QM.borderTeal.opacity(0.4), lineWidth: 1))
#else
        TextField(placeholder, text: $text, axis: .vertical)
            .lineLimit(3...8)
            .font(QM.mono(12))
            .foregroundColor(QM.textPrimary)
            .tint(QM.accentCyan)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(QM.bgElevated)
            .overlay(Rectangle().stroke(QM.borderTeal.opacity(0.4), lineWidth: 1))
#endif
    }
}
