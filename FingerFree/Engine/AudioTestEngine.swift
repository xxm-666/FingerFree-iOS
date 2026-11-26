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
    private var nextExpectedMIDI: Int? = nil
    private var currentBeatStartTime: CFAbsoluteTime = 0
    private var currentBeatIsChordChange: Bool = false
    private var beatIntervalSeconds: Double = 1.0
    private var metronomeSoundActive: Bool = true
    private var clickGateSeconds: Double = 0.095

    private var beatPitchMatched = false
    private var beatRhythmMatched = false
    private var beatHadSound = false
    private var beatMaxFullness: Double = 0.0

    // Early-onset lookahead buffers (when player attacks slightly before the upcoming beat)
    private var nextBeatPreMatchedPitch = false
    private var nextBeatPreMatchedRhythm = false
    private var nextBeatPreMatchedHadSound = false
    private var nextBeatPreMatchedFullness: Double = 0.0

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

        currentBeatStartTime = 0
        currentBeatIsChordChange = false
        expectedMIDI = nil
        nextExpectedMIDI = nil

        beatPitchMatched = false
        beatRhythmMatched = false
        beatHadSound = false
        beatMaxFullness = 0.0

        nextBeatPreMatchedPitch = false
        nextBeatPreMatchedRhythm = false
        nextBeatPreMatchedHadSound = false
        nextBeatPreMatchedFullness = 0.0

        previousRMS = 0
        lastOnsetTime = 0
    }

    /// Called directly from MetronomeEngine on every non-count-in beat to finalize the previous beat and arm the new beat.
    func onBeat(
        expectedMIDI targetMIDI: Int?,
        nextExpectedMIDI upcomingMIDI: Int?,
        bpm: Int,
        isChordMode chordMode: Bool,
        isChordChangeBeat: Bool,
        metronomeSoundActive soundActive: Bool,
        clickGateDuration: Double,
        tickTimestamp: CFAbsoluteTime
    ) {
        // Finalize previous beat using THAT beat's own chord-change flag
        if currentBeatStartTime > 0 {
            finalizeCurrentBeat(wasChordChangeBeat: self.currentBeatIsChordChange)
        }

        let interval = 60.0 / Double(max(bpm, 30))
        self.isChordMode = chordMode
        self.expectedMIDI = targetMIDI
        self.nextExpectedMIDI = upcomingMIDI
        self.currentBeatStartTime = tickTimestamp
        self.currentBeatIsChordChange = isChordChangeBeat
        self.beatIntervalSeconds = interval
        self.metronomeSoundActive = soundActive
        self.clickGateSeconds = min(max(clickGateDuration, 0.065), interval * 0.35)

        // Carry over any early-onset hit that belonged to this beat
        self.beatPitchMatched = nextBeatPreMatchedPitch
        self.beatRhythmMatched = nextBeatPreMatchedRhythm
        self.beatHadSound = nextBeatPreMatchedHadSound
        self.beatMaxFullness = nextBeatPreMatchedFullness
        self.currentBeatPitchMatched = chordMode ? (nextBeatPreMatchedFullness >= 0.45) : nextBeatPreMatchedPitch

        self.nextBeatPreMatchedPitch = false
        self.nextBeatPreMatchedRhythm = false
        self.nextBeatPreMatchedHadSound = false
        self.nextBeatPreMatchedFullness = 0.0
    }

    private func finalizeCurrentBeat(wasChordChangeBeat: Bool) {
        if isChordMode {
            // In chord mode, evaluate every 4-beat chord change (beat 1 of each bar)
            if wasChordChangeBeat {
                evaluatedBeats += 1
                if beatRhythmMatched {
                    rhythmHits += 1
                }
                // Chord fullness requires multi-band tonal ring (>= 0.45), not just muted percussive noise
                if beatHadSound && beatMaxFullness >= 0.45 {
                    pitchHits += 1
                }
                if beatHadSound {
                    clarityHistory.append(beatMaxFullness)
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
            finalizeCurrentBeat(wasChordChangeBeat: self.currentBeatIsChordChange)
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
        let hwInputLatency = max(0.0, session.inputLatency)
        inputNode.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameCount = Int(buffer.frameLength)
            guard frameCount >= 512 else { return }

            // Compensate hardware mic latency + half analysis buffer window
            let bufferHalfDuration = (Double(frameCount) / sampleRate) * 0.5
            let captureTimestamp = CFAbsoluteTimeGetCurrent() - hwInputLatency - bufferHalfDuration

            let analysis = Self.analyzeFrame(
                samples: channelData,
                count: frameCount,
                sampleRate: sampleRate,
                timestamp: captureTimestamp
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
        let now = frame.timestamp
        // Normalize RMS for visual meter (guitar acoustic pickup range ~0.005...0.18)
        let normalized = min(1.0, max(0.0, Double(frame.rms) * 8.5))
        inputLevel = normalized

        // Timbre-aware click-gate protection after metronome speaker click
        let sinceBeat = now - currentBeatStartTime
        if metronomeSoundActive && currentBeatStartTime > 0 && sinceBeat >= 0 && sinceBeat < clickGateSeconds {
            previousRMS = frame.rms
            return
        }

        let noiseGate: Float = 0.012
        let isStrongSignal = frame.rms > noiseGate

        // Detect Note Onset (sharp energy rise)
        let isOnset = isStrongSignal && (frame.rms > previousRMS * 1.45 + 0.008) && (now - lastOnsetTime > 0.12)
        previousRMS = frame.rms

        let elapsed = currentBeatStartTime > 0 ? (now - currentBeatStartTime) : 0
        let halfBeat = beatIntervalSeconds * 0.5
        let isEarlyForNextBeat = currentBeatStartTime > 0 && elapsed > halfBeat

        if isStrongSignal {
            if isEarlyForNextBeat && isOnset {
                nextBeatPreMatchedHadSound = true
            } else {
                beatHadSound = true
            }
        }

        if isOnset && currentBeatStartTime > 0 {
            lastOnsetTime = now
            // Compute nearest beat timing offset in milliseconds (negative = early for next beat, positive = late for current beat)
            let offsetSec = isEarlyForNextBeat ? (elapsed - beatIntervalSeconds) : elapsed
            let offsetMs = Int(round(offsetSec * 1000.0))
            lastTimingOffsetMs = offsetMs
            timingOffsetsMs.append(offsetMs)

            let toleranceMs = isChordMode ? 145 : 115
            if abs(offsetMs) <= toleranceMs {
                if isEarlyForNextBeat {
                    nextBeatPreMatchedRhythm = true
                } else {
                    beatRhythmMatched = true
                }
            }
        }

        if isStrongSignal {
            if isChordMode {
                detectedClarity = frame.chordFullness
                if isEarlyForNextBeat && nextBeatPreMatchedHadSound {
                    nextBeatPreMatchedFullness = max(nextBeatPreMatchedFullness, frame.chordFullness)
                } else {
                    beatMaxFullness = max(beatMaxFullness, frame.chordFullness)
                    if beatMaxFullness >= 0.45 {
                        currentBeatPitchMatched = true
                    }
                }
            } else {
                if frame.clarity > 0.25 {
                    clarityHistory.append(frame.clarity)
                    detectedClarity = frame.clarity
                }

                if let hz = frame.frequencyHz, frame.clarity > 0.45 {
                    let midi = GuitarPitchHelper.midiNote(forFrequency: hz)
                    detectedMIDI = midi
                    detectedNoteName = GuitarPitchHelper.noteName(forMIDI: midi)

                    if isEarlyForNextBeat {
                        // Early note played just before next beat: attribute to next beat's target if it matches
                        if let nextTarget = nextExpectedMIDI, (midi == nextTarget || midi == nextTarget + 12) {
                            nextBeatPreMatchedPitch = true
                        } else if !beatPitchMatched, let target = expectedMIDI, (midi == target || midi == target + 12) {
                            beatPitchMatched = true
                            currentBeatPitchMatched = true
                        }
                    } else if let target = expectedMIDI {
                        // Exact semitone match (or octave harmonic if overtone is dominant on acoustic guitar)
                        if midi == target || midi == target + 12 {
                            beatPitchMatched = true
                            currentBeatPitchMatched = true
                        }
                    }
                }
            }
        }
    }

    // MARK: - Pure DSP (Off-Main-Thread YIN Pitch + FFT Chord Fullness + RMS)

    private struct FrameAnalysis: Sendable {
        let rms: Float
        let frequencyHz: Double?
        let clarity: Double
        let chordFullness: Double
        let timestamp: CFAbsoluteTime
    }

    private nonisolated static func analyzeFrame(
        samples: UnsafePointer<Float>,
        count: Int,
        sampleRate: Double,
        timestamp: CFAbsoluteTime
    ) -> FrameAnalysis {
        // 1. RMS via Accelerate vDSP
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(count))
        guard rms > 0.010 else {
            return FrameAnalysis(rms: rms, frequencyHz: nil, clarity: 0, chordFullness: 0, timestamp: timestamp)
        }

        // 2. Spectral chord fullness (1024-pt Radix-2 FFT across 5 guitar harmonic bands + tonality peakness)
        let fullness = computeChordFullness(samples: samples, count: count, sampleRate: sampleRate)

        // 3. YIN pitch detection tuned to standard guitar fundamental range (75 Hz ... 1100 Hz)
        let windowSize = min(count / 2, 1024)
        let minLag = max(2, Int(sampleRate / 1100.0))
        let maxLag = min(windowSize - 1, Int(sampleRate / 75.0))
        guard maxLag > minLag else {
            return FrameAnalysis(rms: rms, frequencyHz: nil, clarity: 0, chordFullness: fullness, timestamp: timestamp)
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
            return FrameAnalysis(
                rms: rms,
                frequencyHz: nil,
                clarity: Double(max(0, 1.0 - minVal)),
                chordFullness: fullness,
                timestamp: timestamp
            )
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

        return FrameAnalysis(
            rms: rms,
            frequencyHz: freq,
            clarity: clarity,
            chordFullness: fullness,
            timestamp: timestamp
        )
    }

    /// Computes polyphonic chord fullness (0...1) from 1024-pt FFT magnitude spectrum.
    /// Rewards ringing multi-string tonal peaks across guitar registers while penalizing broadband muted noise.
    private nonisolated static func computeChordFullness(
        samples: UnsafePointer<Float>,
        count: Int,
        sampleRate: Double
    ) -> Double {
        let n = 1024
        guard count >= n else { return 0.0 }

        var real = [Float](repeating: 0, count: n)
        var imag = [Float](repeating: 0, count: n)
        let twoPiOverN = Float(2.0 * Double.pi / Double(n - 1))

        // Hann window
        for i in 0..<n {
            let w = 0.5 * (1.0 - cos(twoPiOverN * Float(i)))
            real[i] = samples[i] * w
        }

        // Bit-reversal permutation
        var j = 0
        for i in 1..<n {
            var bit = n >> 1
            while j & bit != 0 {
                j ^= bit
                bit >>= 1
            }
            j ^= bit
            if i < j {
                real.swapAt(i, j)
            }
        }

        // Iterative Cooley-Tukey Radix-2 FFT
        var len = 2
        while len <= n {
            let half = len >> 1
            let angle = -2.0 * Float.pi / Float(len)
            let wLenRe = cos(angle)
            let wLenIm = sin(angle)
            var i = 0
            while i < n {
                var wRe: Float = 1.0
                var wIm: Float = 0.0
                for k in 0..<half {
                    let uRe = real[i + k]
                    let uIm = imag[i + k]
                    let vRe = real[i + k + half] * wRe - imag[i + k + half] * wIm
                    let vIm = real[i + k + half] * wIm + imag[i + k + half] * wRe
                    real[i + k] = uRe + vRe
                    imag[i + k] = uIm + vIm
                    real[i + k + half] = uRe - vRe
                    imag[i + k + half] = uIm - vIm
                    let nextWRe = wRe * wLenRe - wIm * wLenIm
                    wIm = wRe * wLenIm + wIm * wLenRe
                    wRe = nextWRe
                }
                i += len
            }
            len <<= 1
        }

        let binWidth = sampleRate / Double(n)
        let maxBin = min(n / 2 - 1, Int(2200.0 / binWidth))
        let minBin = max(1, Int(80.0 / binWidth))
        guard maxBin > minBin else { return 0.0 }

        var mags = [Double](repeating: 0, count: maxBin + 1)
        var totalEnergy = 0.0
        for b in minBin...maxBin {
            let m = sqrt(Double(real[b] * real[b] + imag[b] * imag[b]))
            mags[b] = m
            totalEnergy += m
        }
        guard totalEnergy > 1e-5 else { return 0.0 }

        // 5 guitar frequency bands: Bass(80-165), LowMid(165-310), Mid(310-580), UpperMid(580-1100), Presence(1100-2200)
        let bandRanges: [(Double, Double)] = [
            (80, 165), (165, 310), (310, 580), (580, 1100), (1100, 2200)
        ]

        var activeBands = 0
        var tonalSum = 0.0
        for (lo, hi) in bandRanges {
            let bLo = max(minBin, Int(lo / binWidth))
            let bHi = min(maxBin, Int(hi / binWidth))
            guard bHi >= bLo else { continue }
            var bandSum = 0.0
            var bandPeak = 0.0
            for b in bLo...bHi {
                let v = mags[b]
                bandSum += v
                if v > bandPeak { bandPeak = v }
            }
            let bandShare = bandSum / totalEnergy
            let bandMean = bandSum / Double(bHi - bLo + 1)
            let peakRatio = bandMean > 1e-6 ? (bandPeak / bandMean) : 0.0

            // A tonal ringing string produces a distinct harmonic peak (peakRatio > 1.7) and meaningful energy share
            if bandShare >= 0.06 && peakRatio >= 1.65 {
                activeBands += 1
                tonalSum += min(1.0, (peakRatio - 1.3) / 3.0)
            }
        }

        // 0-1 active bands -> muted/single note; 3+ tonal bands -> full ringing chord
        let coverageScore = min(1.0, Double(activeBands) / 4.0)
        let tonalityScore = activeBands > 0 ? (tonalSum / Double(activeBands)) : 0.0
        return min(1.0, max(0.0, coverageScore * 0.65 + tonalityScore * 0.35))
    }
}
