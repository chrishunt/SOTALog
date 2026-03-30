import SwiftUI
import TipKit

struct OmniboxTip: Tip {
    var title: Text { Text("Quick entry") }
    var message: Text? { Text("Just type a callsign to log. Override any field (RST, frequency, state, S2S/P2P references) by typing it inline.") }
    var image: Image? { Image(systemName: "keyboard") }
    var options: [TipOption] { [MaxDisplayCount(1)] }
}

struct SpotsTip: Tip {
    @Parameter static var omniboxTipClosed: Bool = false

    var title: Text { Text("Live spots") }
    var message: Text? { Text("Tap a spot to pre-fill your log entry.") }
    var image: Image? { Image(systemName: "antenna.radiowaves.left.and.right") }
    var options: [TipOption] { [MaxDisplayCount(1)] }

    var rules: [Rule] {
        #Rule(Self.$omniboxTipClosed) { $0 }
    }
}
