import SwiftUI

struct CaptureSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()

                Circle()
                    .fill(Theme.captureFill)
                    .frame(width: 140, height: 140)
                    .overlay(
                        Image(systemName: "mic.fill")
                            .font(.system(size: 56, weight: .semibold))
                            .foregroundStyle(.white)
                    )
                    .shadow(color: Theme.captureShadow, radius: 20, x: 0, y: 8)

                Text("Press to record")
                    .font(Theme.titleL())

                Text("This is the placeholder for the capture flow. We'll wire press-to-start / press-to-stop, a timer, and the canned transcript in step 6.")
                    .font(Theme.bodyL())
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background)
            .navigationTitle("Capture")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    CaptureSheet()
}
