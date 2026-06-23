import AppKit
import SwiftUI

struct PaninoTextInput: View {
    let placeholder: String
    @Binding var text: String
    var isSecure = false
    var onSubmit: (() -> Void)?
    @EnvironmentObject private var theme: ThemeSettings

    init(
        _ placeholder: String,
        text: Binding<String>,
        isSecure: Bool = false,
        onSubmit: (() -> Void)? = nil
    ) {
        self.placeholder = placeholder
        self._text = text
        self.isSecure = isSecure
        self.onSubmit = onSubmit
    }

    var body: some View {
        PaninoTextInputField(
            placeholder: placeholder,
            text: $text,
            isSecure: isSecure,
            onSubmit: onSubmit
        )
        .frame(height: PaninoTokens.Layout.controlMinSize)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .paninoGlassCard(
            level: .floatingChrome,
            cornerRadius: PaninoTokens.Radius.control + 4,
            tint: theme.semanticSelectionColor
        )
    }
}

private struct PaninoTextInputField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var isSecure = false
    var onSubmit: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field: NSTextField = isSecure ? PaninoSecureTextField() : PaninoPlainTextField()
        field.delegate = context.coordinator
        field.placeholderString = placeholder
        field.stringValue = text
        field.isEditable = true
        field.isSelectable = true
        field.isBezeled = false
        field.isBordered = false
        field.drawsBackground = false
        field.backgroundColor = .clear
        field.focusRingType = .none
        field.font = .preferredFont(forTextStyle: .body)
        field.textColor = .labelColor
        field.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: NSColor.placeholderTextColor
            ]
        )
        field.lineBreakMode = .byTruncatingTail
        field.target = context.coordinator
        field.action = #selector(Coordinator.submit(_:))
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        context.coordinator.parent = self
        if nsView.placeholderString != placeholder {
            nsView.placeholderString = placeholder
            nsView.placeholderAttributedString = NSAttributedString(
                string: placeholder,
                attributes: [
                    .foregroundColor: NSColor.placeholderTextColor
                ]
            )
        }
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: PaninoTextInputField

        init(_ parent: PaninoTextInputField) {
            self.parent = parent
        }

        @objc func submit(_ sender: NSTextField) {
            parent.text = sender.stringValue
            parent.onSubmit?()
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            guard commandSelector == #selector(NSResponder.insertNewline(_:)) else {
                return false
            }
            if let field = control as? NSTextField {
                parent.text = field.stringValue
            }
            parent.onSubmit?()
            return true
        }
    }
}

private final class PaninoPlainTextField: NSTextField {
    override var acceptsFirstResponder: Bool { true }
    override var needsPanelToBecomeKey: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.window?.makeFirstResponder(self.currentEditor() ?? self)
            }
        }
        return accepted
    }
}

private final class PaninoSecureTextField: NSSecureTextField {
    override var acceptsFirstResponder: Bool { true }
    override var needsPanelToBecomeKey: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.window?.makeFirstResponder(self.currentEditor() ?? self)
            }
        }
        return accepted
    }
}
