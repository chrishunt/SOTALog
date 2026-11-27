import SwiftUI

#if os(iOS)
import UIKit

/// A one-emoji text field that opens with the emoji keyboard, since that is
/// the only thing it takes. `onChange` decides what the field keeps.
struct EmojiField: UIViewRepresentable {
    let emoji: String
    let onChange: (String) -> Void

    func makeUIView(context: Context) -> EmojiTextField {
        let field = EmojiTextField()
        field.font = .preferredFont(forTextStyle: .title2)
        field.adjustsFontForContentSizeCategory = true
        field.textAlignment = .center
        field.tintColor = .clear
        field.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged(_:)), for: .editingChanged)
        field.accessibilityLabel = "Emoji"
        field.setContentHuggingPriority(.required, for: .horizontal)
        return field
    }

    func updateUIView(_ field: EmojiTextField, context: Context) {
        context.coordinator.onChange = onChange
        if field.text != emoji { field.text = emoji }
    }

    func makeCoordinator() -> Coordinator { Coordinator(onChange: onChange) }

    final class Coordinator: NSObject {
        var onChange: (String) -> Void
        init(onChange: @escaping (String) -> Void) { self.onChange = onChange }

        @objc func editingChanged(_ field: UITextField) {
            onChange(field.text ?? "")
        }
    }
}

final class EmojiTextField: UITextField {
    override var textInputMode: UITextInputMode? {
        UITextInputMode.activeInputModes.first { $0.primaryLanguage == "emoji" } ?? super.textInputMode
    }
}
#endif
