import SwiftUI

// Shims for iOS-only SwiftUI modifiers so the project compiles on macOS (SPM build)
#if os(macOS)
enum TextInputAutocapitalization {
    case characters, words, sentences, never
}

enum NavigationBarTitleDisplayMode {
    case inline, large, automatic
}

extension View {
    func textInputAutocapitalization(_ style: TextInputAutocapitalization?) -> some View { self }
    func navigationBarTitleDisplayMode(_ mode: NavigationBarTitleDisplayMode) -> some View { self }
}
#endif
