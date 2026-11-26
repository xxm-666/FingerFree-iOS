import Accelerate
import AVFoundation
import Foundation

struct AudioTestMetrics {
    let pitchAccuracy: Double      // 0.0...1.0
    let rhythmAccuracy: Double     // 0.0...1.0
    let clarityScore: Double       // 0.0...1.0
    let evaluatedBeats: Int
    let pitchHits: Int
    let rhythmHits: Int
    let avgTimingOffsetMs: Int
}

@MainActor
final class AudioTestEngine: ObservableObject {
    @Published private(set) var isListening = false
    @Published private(set) var permissionDenied = false
    @Published private(set) var inputLevel: Double = 0.0           // 0...1 normalized meter
    @Published private(set) var detectedNoteName: String = "--"
    @Published private(set) var detectedMIDI: Int = 0
    @Published private(set) var detectedClarity: Double = 0.0
    @Published private(set) var lastTimingOffsetMs: Int? = nil     // negative = early, positive = late
    @Published private(set) var currentBeatPitchMatched: Bool = false

    @Published private(set) var evaluatedBeats: Int = 0
    @Published private(set) var pitchHits: Int = 0
    @Published private(set) var rhythmHits: Int = 0

    private var audioEngine: AVAudioEngine?
    private var isChordMode: Bool = false
    private var expectedMIDI: Int? = nil
    private var currentBeatStartTime: CFAbsoluteTime = 0
    private var beatIntervalSeconds: Double = 1.0
    private var metronomeSoundActive: Bool = true

    private var beatPitchMatched = false
    private var beatRhythmMatched = false
    private var beatHadSound = false
    private var previousRMS: Float = 0.0
    private var lastOnsetTime: CFAbsoluteTime = 0
    private var clarityHistory: [Double] = []
    private var timingOffsetsMs: [Int] = []

    func resetMetrics() {
        evaluatedBeats = 0
        pitchHits = 0
        rhythmHits = 0
        clarityHistory = []
        timingOffsetsMs = []
        detectedNoteName = "--"
        detectedMIDI = 0
        detectedClarity = 0
        lastTimingOffsetMs = nil
        currentBeatPitchMatched = false
        beatPitchMatched = false
        beatRhythmMatched = false
        beatHadSound = false
        previousRMS = 0
        lastOnsetTime = 0
    }

    /// Called on every metronome beat to advance the expected target note and finalize the previous beat's hit state.
    func onBeat(
        expectedMIDI targetMIDI: Int?,
        bpm: Int,
        isChordMode chordMode: Bool,
        isChordChangeBeat: Bool,
        metronomeSoundActive soundActive: Bool
    ) {
        let now = CFAbsoluteTimeGetCurrent()
        // Finalize previous beat before starting new beat
        if currentBeatStartTime > 0 {
            finalizeCurrentBeat(wasChordChangeBeat: chordMode ? isChordChangeBeat : true)
        }

        self.isChordMode = chordMode
        self.expectedMIDI = targetMIDI
        self.currentBeatStartTime = now
        self.beatIntervalSeconds = 60.0 / Double(max(bpm, 30))
        self.metronomeSoundActive = soundActive

        self.beatPitchMatched = false
        self.beatRhythmMatched = false
        self.beatHadSound = false
        self.currentBeatPitchMatched = false
    }

    private func finalizeCurrentBeat(wasChordChangeBeat: Bool) {
        if isChordMode {
            // In chord mode, evaluate every 4-beat chord change + sustain
            if wasChordChangeBeat {
                evaluatedBeats += 1
                if beatRhythmMatched || beatHadSound {
                    rhythmHits += 1
                }
                if beatHadSound {
                    pitchHits += 1
                }
            }
        } else {
            evaluatedBeats += 1
            if beatPitchMatched {
                pitchHits += 1
            }
            if beatRhythmMatched {
                rhythmHits += 1
            }
        }
    }

    func computeSummary() -> AudioTestMetrics {
        if currentBeatStartTime > 0 {
            finalizeCurrentBeat(wasChordChangeBeat: true)
            currentBeatStartTime = 0
        }
        let denom = max(1, evaluatedBeats)
        let pitchAcc = Double(pitchHits) / Double(denom)
        let rhythmAcc = Double(rhythmHits) / Double(denom)
        let avgClarity = clarityHistory.isEmpty
            ? 0.0
            : clarityHistory.reduce(0, +) / Double(clarityHistory.count)
        let avgOffset = timingOffsetsMs.isEmpty
            ? 0
            : timingOffsetsMs.map { abs($0) }.reduce(0, +) / timingOffsetsMs.count

        return AudioTestMetrics(
            pitchAccuracy: min(1.0, pitchAcc),
            rhythmAccuracy: min(1.0, rhythmAcc),
            clarityScore: min(1.0, avgClarity),
            evaluatedBeats: evaluatedBeats,
            pitchHits: pitchHits,
            rhythmHits: rhythmHits,
            avgTimingOffsetMs: avgOffset
        )
    }

    func startListening() {
        guard !isListening else { return }
        permissionDenied = false

        AVAudioApplication.requestRecordPermission { [weak self] granted in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if !granted {
                    self.permissionDenied = true
                    return
                }
                self.beginAudioTap()
            }
        }
    }

    func stopListening() {
        if let engine = audioEngine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        audioEngine = nil
        isListening = false
        inputLevel = 0
    }

    private func beginAudioTap() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .measurement,
                options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers]
            )
            try session.setActive(true)
        } catch {
            return
        }

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0 && format.channelCount > 0 else { return }

        let sampleRate = format.sampleRate
        inputNode.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameCount = Int(buffer.frameLength)
            guard frameCount >= 512 else { return }

            let analysis = Self.analyzeFrame(
                samples: channelData,
                count: frameCount,
                sampleRate: sampleRate
            )

            Task { @MainActor [weak self] in
                self?.processAnalysis(analysis)
            }
        }

        do {
            try engine.start()
            self.audioEngine = engine
            self.isListening = true
        } catch {
            self.isListening = false
        }
    }

    private func processAnalysis(_ frame: FrameAnalysis) {
        let now = CFAbsoluteTimeGetCurrent()
        // Normalize RMS for visual meter (guitar acoustic pickup range ~0.005...0.18)
        let normalized = min(1.0, max(0.0, Double(frame.rms) * 8.5))
        inputLevel = normalized

        // 35ms click-gate protection after metronome speaker click
        let sinceBeat = now - currentBeatStartTime
        if metronomeSoundActive && currentBeatStartTime > 0 && sinceBeat >= 0 && sinceBeat < 0.035 {
            previousRMS = frame.rms
            return
        }

        let noiseGate: Float = 0.012
        let isStrongSignal = frame.rms > noiseGate

        // Detect Note Onset (sharp energy rise)
        let isOnset = isStrongSignal && (frame.rms > previousRMS * 1.45 + 0.008) && (now - lastOnsetTime > 0.12)
        previousRMS = frame.rms

        if isStrongSignal {
            beatHadSound = true
        }

        if isOnset && currentBeatStartTime > 0 {
            lastOnsetTime = now
            // Compute nearest beat timing offset in milliseconds
            let elapsed = now - currentBeatStartTime
            let halfBeat = beatIntervalSeconds * 0.5
            let offsetSec = (elapsed <= halfBeat) ? elapsed : (elapsed - beatIntervalSeconds)
            let offsetMs = Int(round(offsetSec * 1000.0))
            lastTimingOffsetMs = offsetMs
            timingOffsetsMs.append(offsetMs)

            let toleranceMs = isChordMode ? 145 : 115
            if abs(offsetMs) <= toleranceMs {
                beatRhythmMatched = true
            }
        }

        if isStrongSignal {
            if frame.clarity > 0.25 {
                clarityHistory.append(frame.clarity)
                detectedClarity = frame.clarity
            }

            if let hz = frame.frequencyHz, frame.clarity > 0.45 {
                let midi = GuitarPitchHelper.midiNote(forFrequency: hz)
                detectedMIDI = midi
                detectedNoteName = GuitarPitchHelper.noteName(forMIDI: midi)

                if let target = expectedMIDI {
                    // Exact semitone match (or octave harmonic if overtone is dominant on acoustic guitar)
                    if midi == target || midi == target + 12 {
                        beatPitchMatched = true
                        currentBeatPitchMatched = true
                    }
                }
            }
        }
    }

    // MARK: - Pure DSP (Off-Main-Thread YIN Pitch + RMS)

    private struct FrameAnalysis: Sendable {
        let rms: Float
        let frequencyHz: Double?
        let clarity: Double
    }

    private nonisolated static func analyzeFrame(
        samples: UnsafePointer<Float>,
        count: Int,
        sampleRate: Double
    ) -> FrameAnalysis {
        // 1. RMS via Accelerate vDSP
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(count))
        guard rms > 0.010 else {
            return FrameAnalysis(rms: rms, frequencyHz: nil, clarity: 0)
        }

        // 2. YIN pitch detection tuned to standard guitar fundamental range (75 Hz ... 1100 Hz)
        let windowSize = min(count / 2, 1024)
        let minLag = max(2, Int(sampleRate / 1100.0))
        let maxLag = min(windowSize - 1, Int(sampleRate / 75.0))
        guard maxLag > minLag else {
            return FrameAnalysis(rms: rms, frequencyHz: nil, clarity: 0)
        }

        var diff = [Float](repeating: 0, count: maxLag + 1)
        for tau in minLag...maxLag {
            var sum: Float = 0
            // Stride by 2 for ultra-low CPU overhead on iPhone while keeping high accuracy
            var j = 0
            while j < windowSize {
                let delta = samples[j] - samples[j + tau]
                sum += delta * delta
                j += 2
            }
            diff[tau] = sum
        }

        // Cumulative Mean Normalized Difference (CMND)
        var cmnd = [Float](repeating: 1.0, count: maxLag + 1)
        var runningSum: Float = 0
        for tau in minLag...maxLag {
            runningSum += diff[tau]
            if runningSum > 0 {
                cmnd[tau] = diff[tau] * Float(tau - minLag + 1) / runningSum
            }
        }

        // Find first local minimum below YIN threshold (0.22)
        let threshold: Float = 0.22
        var bestTau = -1
        var minVal: Float = 1.0

        for tau in (minLag + 1)..<maxLag {
            let val = cmnd[tau]
            if val < threshold && val < cmnd[tau - 1] && val <= cmnd[tau + 1] {
                bestTau = tau
                minVal = val
                break
            }
            if val < minVal {
                minVal = val
                bestTau = tau
            }
        }

        guard bestTau > minLag && bestTau < maxLag else {
            return FrameAnalysis(rms: rms, frequencyHz: nil, clarity: Double(max(0, 1.0 - minVal)))
        }

        // Parabolic interpolation around bestTau
        let s0 = cmnd[bestTau - 1]
        let s1 = cmnd[bestTau]
        let s2 = cmnd[bestTau + 1]
        let denom = (s0 - 2.0 * s1 + s2)
        let shift = abs(denom) > 1e-6 ? 0.5 * (s0 - s2) / denom : 0
        let refinedLag = Double(bestTau) + Double(shift)
        let freq = sampleRate / refinedLag
        let clarity = max(0.0, min(1.0, 1.0 - Double(minVal)))

        return FrameAnalysis(rms: rms, frequencyHz: freq, clarity: clarity)
    }
}
