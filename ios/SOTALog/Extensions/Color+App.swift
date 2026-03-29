import SwiftUI

// Okabe-Ito color blind-safe palette with light/dark mode variants.
// Light mode: Okabe-Ito base values (designed for light backgrounds).
// Dark mode: Same hues, brightened for dark backgrounds.
extension Color {
    #if os(iOS)
    static let appOrange = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 255/255, green: 183/255, blue: 51/255, alpha: 1)   // #FFB733
            : UIColor(red: 230/255, green: 159/255, blue: 0/255, alpha: 1)    // #E69F00
    })

    static let appGreen = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 46/255, green: 201/255, blue: 160/255, alpha: 1)   // #2EC9A0
            : UIColor(red: 0/255, green: 158/255, blue: 115/255, alpha: 1)    // #009E73
    })

    static let appBlue = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 86/255, green: 180/255, blue: 233/255, alpha: 1)   // #56B4E9
            : UIColor(red: 0/255, green: 114/255, blue: 178/255, alpha: 1)    // #0072B2
    })

    static let appRed = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 255/255, green: 119/255, blue: 51/255, alpha: 1)   // #FF7733
            : UIColor(red: 213/255, green: 94/255, blue: 0/255, alpha: 1)     // #D55E00
    })

    // MARK: - Semantic surface & text tokens

    static let appBackground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 20/255, green: 20/255, blue: 20/255, alpha: 1)     // #141414
            : .systemBackground
    })

    static let appSurface = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 30/255, green: 30/255, blue: 32/255, alpha: 1)     // #1E1E20
            : .secondarySystemBackground
    })

    static let appSurfaceRaised = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 44/255, green: 44/255, blue: 46/255, alpha: 1)     // #2C2C2E
            : UIColor(red: 232/255, green: 232/255, blue: 234/255, alpha: 1)  // #E8E8EA
    })

    static let appTextPrimary = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 235/255, green: 235/255, blue: 235/255, alpha: 1)  // #EBEBEB
            : .label
    })

    static let appTextSecondary = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 160/255, green: 160/255, blue: 160/255, alpha: 1)  // #A0A0A0
            : .secondaryLabel
    })

    static let appTextTertiary = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 120/255, green: 120/255, blue: 120/255, alpha: 1)  // #787878
            : .tertiaryLabel
    })
    #else
    // macOS SPM build fallback — static colors (light mode values)
    static let appOrange = Color(red: 230/255, green: 159/255, blue: 0/255)
    static let appGreen = Color(red: 0/255, green: 158/255, blue: 115/255)
    static let appBlue = Color(red: 0/255, green: 114/255, blue: 178/255)
    static let appRed = Color(red: 213/255, green: 94/255, blue: 0/255)
    static let appBackground = Color(red: 20/255, green: 20/255, blue: 20/255)
    static let appSurface = Color(red: 30/255, green: 30/255, blue: 32/255)
    static let appSurfaceRaised = Color(red: 44/255, green: 44/255, blue: 46/255)
    static let appTextPrimary = Color(red: 235/255, green: 235/255, blue: 235/255)
    static let appTextSecondary = Color(red: 160/255, green: 160/255, blue: 160/255)
    static let appTextTertiary = Color(red: 120/255, green: 120/255, blue: 120/255)
    #endif
}
