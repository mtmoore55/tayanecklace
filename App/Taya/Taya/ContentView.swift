import SwiftUI
import TayaCompanion

// The real root view lives in the TayaCompanion library so it can be
// previewed/iterated independently of the App target. This file is kept
// as a thin re-export so the generated Xcode template still has something
// to compile, and previews here mirror the App entry.
struct ContentView: View {
    var body: some View {
        RootView()
    }
}

#Preview {
    ContentView()
        .environment(DataStore.seeded(now: Date()))
}
