import SwiftUI
import TayaIntelligence

struct SandboxView: View {
    @State private var screen: Screen = .orb

    enum Screen: String, CaseIterable, Identifiable {
        case orb    = "Orb"
        case splash = "Splash"
        var id: Self { self }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Screen", selection: $screen) {
                ForEach(Screen.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(12)
            .background(.regularMaterial)

            Group {
                switch screen {
                case .orb:    OrbPlayground()
                case .splash: SplashPlayground()
                }
            }
        }
    }
}

// MARK: - Orb playground

private struct OrbPlayground: View {
    @State private var totalNotes: Int = 3
    @State private var currentNote: Int = 0
    @State private var phase: Phase = .idle
    @State private var simulationTask: Task<Void, Never>?

    enum Phase {
        case idle
        case pairing
        case syncing
        case complete
    }

    var orbState: OrbState {
        switch phase {
        case .idle:     return .idle
        case .pairing:  return .pairing
        case .syncing:  return .syncing(current: currentNote, total: totalNotes)
        case .complete: return .complete
        }
    }

    var body: some View {
        ZStack {
            TayaColors.cosmicLatte.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                TayaIntelligenceOrb(state: orbState, size: 180)

                statusLabel
                    .frame(height: 24)

                Spacer()

                controls
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
            }
        }
    }

    private var statusLabel: some View {
        Group {
            switch phase {
            case .idle:
                Text("Idle")
                    .foregroundStyle(TayaColors.oxfordBlue.opacity(0.5))
            case .pairing:
                Text("Pairing…")
                    .foregroundStyle(TayaColors.oxfordBlue.opacity(0.7))
            case .syncing:
                Text("Syncing \(currentNote) of \(totalNotes)")
                    .foregroundStyle(TayaColors.oxfordBlue)
            case .complete:
                Text("Up to date")
                    .foregroundStyle(TayaColors.oxfordBlue.opacity(0.7))
            }
        }
        .font(.system(size: 15, weight: .medium, design: .rounded))
    }

    private var controls: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Notes to sync")
                    .font(.system(size: 13))
                    .foregroundStyle(TayaColors.oxfordBlue.opacity(0.7))
                Spacer()
                Stepper(value: $totalNotes, in: 1...20) {
                    Text("\(totalNotes)")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(TayaColors.oxfordBlue)
                }
                .labelsHidden()
                .fixedSize()
                Text("\(totalNotes)")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(TayaColors.oxfordBlue)
                    .frame(width: 24, alignment: .trailing)
            }

            HStack(spacing: 12) {
                Button("Pair") { phase = .pairing }
                    .disabled(phase == .syncing)
                Button(phase == .syncing ? "Stop" : "Simulate sync") {
                    if phase == .syncing {
                        stopSimulation()
                    } else {
                        startSimulation()
                    }
                }
                .keyboardShortcut(.return)
                Button("Reset") {
                    stopSimulation()
                    currentNote = 0
                    phase = .idle
                }
            }
        }
    }

    private func startSimulation() {
        stopSimulation()
        currentNote = 0
        phase = .syncing
        simulationTask = Task { @MainActor in
            for i in 1...totalNotes {
                try? await Task.sleep(for: .milliseconds(900))
                if Task.isCancelled { return }
                currentNote = i
            }
            try? await Task.sleep(for: .milliseconds(500))
            if !Task.isCancelled {
                phase = .complete
            }
        }
    }

    private func stopSimulation() {
        simulationTask?.cancel()
        simulationTask = nil
    }
}

// MARK: - Splash playground

private struct SplashPlayground: View {
    @State private var replayKey: Int = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            SplashView()
                .id(replayKey)

            Button("Replay") {
                replayKey &+= 1
            }
            .keyboardShortcut(.return)
            .padding(.bottom, 24)
        }
    }
}
