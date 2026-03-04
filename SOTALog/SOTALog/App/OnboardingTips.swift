import SwiftUI
import TipKit

struct OmniboxTip: Tip {
    var title: Text { Text("All-in-one entry") }
    var message: Text? { Text("Just type a callsign to log. Override any field (RST, frequency, state, S2S/P2P references) by typing it inline.") }
    var image: Image? { Image(systemName: "keyboard") }
    var options: [TipOption] { [MaxDisplayCount(1)] }
}
