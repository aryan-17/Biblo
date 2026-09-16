import Foundation
import Combine

/// Shared observable state driving WheelView.
final class WheelState: ObservableObject {
    @Published var wheel: Wheel?
    @Published var highlightedIndex: Int?          // nil = dead zone / hidden
    @Published var actionIndices: [Int: Int] = [:] // per-segment current action index
    @Published var wheelOrigin: CGPoint = .zero    // wheel centre in SwiftUI view coords
}
