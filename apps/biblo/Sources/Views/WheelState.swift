import Foundation
import Combine

/// Shared observable state driving WheelView.
final class WheelState: ObservableObject {
    @Published var wheel: Wheel?
    @Published var highlightedIndex: Int?          // nil = dead zone / hidden
    @Published var actionIndices: [Int: Int] = [:] // per-segment current action index
    @Published var wheelOrigin: CGPoint = .zero    // wheel centre in SwiftUI view coords
    /// Which outer-ring sub-command is selected (nil = cursor in inner ring or no terminal segment)
    @Published var outerSelectedIndex: Int? = nil
}
