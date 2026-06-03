import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Tiny façade over UIKit's feedback generators so call sites can stay
/// vocabulary-driven (`Haptics.tap()`, `Haptics.commit()`) rather than
/// reaching for raw `UIImpactFeedbackGenerator(style:)` calls.
///
/// The shape of the system mirrors what shipped first on `CaptureSheet`:
/// **light** to *engage* an action, **medium** to *commit* one. The other
/// events extend that vocabulary to cover toggles, settles, confirmations,
/// and destructive paths without each surface having to invent its own.
///
/// Non-UIKit builds (the macOS Preview host) no-op.
@MainActor
enum Haptics {
    /// Light tap. Use when the user *engages* something — opening a
    /// sheet, tapping a row, starting dictation. The grammar's "click"
    /// — quiet, confirms a tap was registered.
    static func tap() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    /// Medium-weight commit. Use when the user finishes a meaningful
    /// action — sending a chat message, finishing a capture, committing
    /// dictation. Heavier than `.tap()`; carries a sense of "done."
    static func commit() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }

    /// Soft settle. Use for animated snaps and reveals (Home ↔ hardware
    /// pane). Whisper-quiet, exists to texture motion, not announce it.
    static func settle() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        #endif
    }

    /// Binary state flip — completing/uncompleting a task,
    /// flipping a toggle. Slightly crisper than `.tap()` via `.rigid`
    /// so the body feels the snap, not the press.
    static func toggle() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        #endif
    }

    /// Discrete picker move — sort menu item, segmented control. Uses
    /// `UISelectionFeedbackGenerator` so the feel matches iOS pickers.
    static func selection() {
        #if canImport(UIKit)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }

    /// Successful resolution — copy landed, save committed, restore
    /// applied. Notification feedback, so it stands apart from impact
    /// taps and reads as a tiny *yes*.
    static func success() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    /// "Are you sure?" or "this is destructive" cue. Use when surfacing
    /// a confirmation dialog for a destructive action.
    static func warning() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
    }

    /// Hard error — something failed in a user-visible way.
    static func error() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
    }
}
