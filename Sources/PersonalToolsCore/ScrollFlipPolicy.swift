import Foundation

/// What the scroll event tap should do with one wheel event.
///
/// Trackpads, the Magic Mouse, and continuous "smooth scroll" wheels take
/// the pass-through path even when the feature is on. That is the same rule
/// as mouse-scroll-flip: natural scrolling on those devices stays untouched.
public enum ScrollFlipDecision: Equatable, Sendable {
    case passThrough
    case invert(horizontal: Bool)
}

public enum ScrollFlipPolicy {
    public static func decide(
        traits: ScrollEventTraits,
        enabled: Bool,
        reverseHorizontal: Bool
    ) -> ScrollFlipDecision {
        guard enabled else { return .passThrough }
        guard ScrollClassifier.source(of: traits) == .discreteMouseWheel else {
            return .passThrough
        }
        return .invert(horizontal: reverseHorizontal)
    }
}
