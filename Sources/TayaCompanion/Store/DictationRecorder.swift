import Foundation
import OSLog
import Observation
import os
#if canImport(AVFoundation)
@preconcurrency import AVFoundation
#endif
#if canImport(Speech)
import Speech
#endif

private let log = Logger(subsystem: "com.mttmr.Taya", category: "Dictation")

private enum DictationError: LocalizedError {
    case invalidInputFormat
    var errorDescription: String? {
        switch self {
        case .invalidInputFormat: return "Microphone unavailable"
        }
    }
}

/// Live microphone capture + on-device speech recognition. One instance
/// drives both the waveform meter and the transcript surface; the audio
/// engine's input tap fans the same buffer into the speech request and
/// into RMS amplitude.
///
/// `level` is published per-frame and read by `TayaListeningWaveform`
/// inside a `TimelineView`, which works cleanly with `@Observable`.
/// Transcript and error updates ride on plain callbacks (`onTranscript`,
/// `onError`) rather than published properties, because SwiftUI's
/// `.onChange(of:)` against `@Observable` properties doesn't always
/// re-fire when the property only appears in modifier arguments — those
/// reads don't register a body subscription, so the view never knows the
/// value changed. Callbacks bypass that pitfall entirely.
@Observable
@MainActor
public final class DictationRecorder {
    /// Smoothed audio amplitude in 0…1. Backed by a lock-protected scalar
    /// and updated directly from the audio tap thread — at 48 kHz with
    /// 1024-sample buffers the tap fires ~47 Hz, and hopping each update
    /// to `@MainActor` was enough to starve the main thread (gestures
    /// gated, UI froze). The waveform is frame-driven by `TimelineView`
    /// which polls this each tick, so observation isn't needed here
    /// either — bypassing `@Observable` keeps SwiftUI from invalidating
    /// the 4-layer blurred waveform on every audio buffer.
    @ObservationIgnored
    public var level: Double {
        levelStorage.withLock { $0 }
    }
    @ObservationIgnored
    private let levelStorage = OSAllocatedUnfairLock<Double>(initialState: 0)

    public private(set) var isRecording: Bool = false
    /// Latch that closes the window between `start()` entering and
    /// `isRecording` flipping true at the end of bg setup. Without it, a
    /// quick second `start()` call (e.g. SwiftUI re-firing `onAppear` /
    /// re-evaluating the `.task(id:)`) sails past the `!isRecording`
    /// guard and races the first call on the same audio session.
    @ObservationIgnored
    private var startInProgress: Bool = false

    /// Fires on every partial-result update from the recognizer.
    /// Replaced before each `start()`; safe to read off the main actor.
    @ObservationIgnored public var onTranscript: ((String) -> Void)?
    /// Fires when `start()` bails (permission denied, engine refused,
    /// etc.) and on any mid-session failure. UI should drop recording
    /// chrome when this fires.
    @ObservationIgnored public var onError: ((String) -> Void)?

    /// Latest transcript snapshot. Useful for `stop()` consumers that
    /// just want the final string without subscribing to every partial.
    @ObservationIgnored public private(set) var transcript: String = ""

    #if canImport(AVFoundation) && canImport(Speech)
    private let engine = AVAudioEngine()
    private let recognizer: SFSpeechRecognizer? = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    #endif

    public init() {}

    public func start() async {
        guard !isRecording, !startInProgress else { return }
        startInProgress = true
        defer { startInProgress = false }
        log.info("dictation start requested")
        transcript = ""

        #if canImport(AVFoundation) && canImport(Speech)
        guard await ensureMicPermission() else {
            log.error("mic permission denied")
            report(error: "Microphone access denied")
            return
        }
        guard await ensureSpeechPermission() else {
            log.error("speech permission denied")
            report(error: "Speech recognition denied")
            return
        }
        guard let recognizer, recognizer.isAvailable else {
            log.error("speech recognizer unavailable")
            report(error: "Speech recognition unavailable")
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // On-device recognition keeps the entire pipeline local — cloud
        // recognition has been observed to stall the recognition task
        // (especially on Simulator) and pile up `Task { @MainActor }`
        // callbacks once results start flowing.
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request

        // Synchronous AVAudioSession activation, input-format probe, tap
        // install, and engine.start all run on a background queue:
        //  - `setActive(true)` and `engine.start()` are the slow ops that
        //    were stalling main and gating gestures.
        //  - The tap install must come *after* `setActive(true)` so the
        //    input node's `outputFormat` reflects the live audio route —
        //    if installed beforehand, the tap callback never fires once
        //    the session is finally activated.
        // Capture `request` and `engine` nonisolated-unsafe so the bg
        // closure (and the tap callback inside it) can use them without
        // crossing the @MainActor boundary per buffer.
        nonisolated(unsafe) let req = request
        nonisolated(unsafe) let engineRef = self.engine

        do {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    do {
                        #if os(iOS) || os(visionOS) || os(tvOS) || os(watchOS)
                        let session = AVAudioSession.sharedInstance()
                        // `.record` (not `.playAndRecord`) and `.default`
                        // (not `.measurement`) are the lightest combo that
                        // still works for speech capture — heavier modes
                        // add coordination work to `setActive(true)`.
                        try session.setCategory(.record, mode: .default)
                        try session.setActive(true)
                        #endif

                        let input = engineRef.inputNode
                        let format = input.outputFormat(forBus: 0)
                        guard format.sampleRate > 0, format.channelCount > 0 else {
                            cont.resume(throwing: DictationError.invalidInputFormat)
                            return
                        }
                        log.info("installing tap: rate=\(format.sampleRate), channels=\(format.channelCount)")
                        input.removeTap(onBus: 0)
                        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                            req.append(buffer)
                            let amp = Self.amplitude(from: buffer)
                            self?.pushAmplitude(amp)
                        }

                        engineRef.prepare()
                        try engineRef.start()
                        cont.resume()
                    } catch {
                        cont.resume(throwing: error)
                    }
                }
            }
        } catch {
            log.error("engine start: \(error.localizedDescription, privacy: .public)")
            report(error: "Engine start: \(error.localizedDescription)")
            teardown()
            return
        }

        // Recognition task is set up after the engine is running. Its
        // callback runs on the recognizer's private queue; we hop to main
        // only when there's actually something to publish.
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let transcriptText = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let hasError = error != nil
            if let error {
                log.error("recognition task error: \(error.localizedDescription, privacy: .public)")
            }
            if transcriptText == nil && !isFinal && !hasError { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let transcriptText {
                    self.transcript = transcriptText
                    self.onTranscript?(transcriptText)
                }
                if hasError || isFinal {
                    self.teardown()
                }
            }
        }

        isRecording = true
        log.info("engine running")
        #else
        report(error: "Audio capture unavailable on this platform")
        #endif
    }

    /// Stop capture. Lets the recognizer drain any in-flight audio so the
    /// final transcript settles; the task callback is what flips
    /// `isRecording` back to false.
    public func stop() {
        guard isRecording else { return }
        log.info("dictation stop")
        #if canImport(AVFoundation) && canImport(Speech)
        request?.endAudio()
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        #endif
        isRecording = false
        levelStorage.withLock { $0 = 0 }
    }

    /// Bail out without keeping the transcript. Cuts the recognition
    /// task immediately rather than letting it drain.
    public func cancel() {
        log.info("dictation cancel")
        #if canImport(AVFoundation) && canImport(Speech)
        task?.cancel()
        #endif
        teardown()
        transcript = ""
    }

    // MARK: - Teardown

    private func teardown() {
        #if canImport(AVFoundation) && canImport(Speech)
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        request = nil
        task = nil
        #if os(iOS) || os(visionOS) || os(tvOS) || os(watchOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
        #endif
        isRecording = false
        levelStorage.withLock { $0 = 0 }
    }

    private func report(error message: String) {
        // Only fire the callback — the recorder doesn't keep an
        // observable error state because the UI is callback-driven.
        onError?(message)
    }

    // MARK: - Level smoothing

    /// Called from the audio tap thread per buffer. Applies an asymmetric
    /// envelope (fast attack, slow release) directly under the lock so
    /// the waveform doesn't strobe on plosives but still tracks pauses.
    /// `nonisolated` lets the audio thread call it without an actor hop.
    nonisolated private func pushAmplitude(_ next: Double) {
        levelStorage.withLock { current in
            let coef = next > current ? 0.55 : 0.12
            current += (next - current) * coef
        }
    }

    #if canImport(AVFoundation)
    /// RMS → dB → normalized 0…1. Floor at −50 dB (near-silence),
    /// ceiling at −5 dB (close-mic shouting); typical conversational
    /// speech lands around 0.3–0.7.
    private static func amplitude(from buffer: AVAudioPCMBuffer) -> Double {
        guard let channel = buffer.floatChannelData?[0] else { return 0 }
        let n = Int(buffer.frameLength)
        guard n > 0 else { return 0 }
        var sum: Float = 0
        for i in 0..<n {
            let v = channel[i]
            sum += v * v
        }
        let rms = sqrt(sum / Float(n))
        let db = 20 * log10(max(rms, 1e-6))
        let minDB: Float = -50
        let maxDB: Float = -5
        let clamped = min(max(db, minDB), maxDB)
        return Double((clamped - minDB) / (maxDB - minDB))
    }
    #endif

    // MARK: - Permissions

    #if canImport(AVFoundation)
    private func ensureMicPermission() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: return true
        case .denied: return false
        case .undetermined: return await AVAudioApplication.requestRecordPermission()
        @unknown default: return false
        }
    }
    #endif

    #if canImport(Speech)
    private func ensureSpeechPermission() async -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: return true
        case .denied, .restricted: return false
        case .notDetermined:
            return await withCheckedContinuation { cont in
                SFSpeechRecognizer.requestAuthorization { status in
                    cont.resume(returning: status == .authorized)
                }
            }
        @unknown default: return false
        }
    }
    #endif
}
