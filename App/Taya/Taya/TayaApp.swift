import SwiftUI
import TayaCompanion

@main
struct TayaApp: App {
    @State private var store = DataStore.seeded(now: Date())

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
        }
    }
}
