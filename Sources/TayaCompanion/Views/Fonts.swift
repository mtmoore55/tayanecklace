import CoreText
import Foundation

/// Registers the bundled .otf files with Core Text so SwiftUI's `Font.custom`
/// can find them by postScript name. Idempotent — safe to call multiple times.
/// Call once on app launch.
public enum AppFonts {
    private static var registered = false
    private static let names = [
        "centralesans-medium",
        "centralesans-bold",
        "aguila-medium",
    ]

    public static func register() {
        guard !registered else { return }
        registered = true
        for name in names {
            guard let url = Bundle.module.url(forResource: name, withExtension: "otf") else {
                assertionFailure("Missing font resource: \(name).otf")
                continue
            }
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                let desc = error?.takeRetainedValue().localizedDescription ?? "unknown"
                #if DEBUG
                print("Font registration failed for \(name): \(desc)")
                #endif
            }
        }
    }
}
