import AVFoundation
import Foundation
import UIKit

@MainActor
final class MetronomeEngine: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var isCountingIn = false
    @Published private(set) var countInBeat: Int = 0        // 1...4 during count-in
    @Published private(set) var currentBeat: Int = 0        // 1...4 while playing
    @Published private(set) var totalBeatCount: Int = 0     // 1-indexed continuous counter for visualizers
    @Published private(set) var lastTickTimestamp: CFAbsoluteTime = 0

    @Published var bpm: Int = 60 {
        didSet {
            let clamped = min(max(bpm, 30), 160)
            if bpm != clamped {
                bpm = clamped
                return
            }
            if isRunning {
                rescheduleTimer()
            }
        }
    }

    @Published var sound: MetronomeSound = .warmWoodblock
    @Published var isMuted: Bool = false
    @Published var hapticsEnabled: Bool = true
    @Published var countInEnabled: Bool = true

    /// Direct low-latency callback fired immediately on every non-count-in beat with its host timestamp.
    var onBeatTick: ((_ totalBeatCount: Int, _ currentBeat: Int, _ tickTimestamp: CFAbsoluteTime) -> Void)?

    /// Approximate audible decay duration of the currently selected metronome timbre (used for mic click-gating).
    var clickGateDuration: Double {
        switch sound {
        case .classicMechanical: return 0.065
        case .warmWoodblock: return 0.095
        case .guitarBodyTap: return 0.120
        case .softMarimba: return 0.165
        }
    }

    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var accentBuffers: [MetronomeSound: AVAudioPCMBuffer] = [:]
    private var regularBuffers: [MetronomeSound: AVAudioPCMBuffer] = [:]
    private var countInBuffer: AVAudioPCMBuffer?

    private var timer: DispatchSourceTimer?
    private let timerQueue = DispatchQueue(label: "com.fingerfree.metronome.timer", qos: .userInteractive)
    private let strongImpact = UIImpactFeedbackGenerator(style: .medium)
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private var audioConfigured = false
    private var notificationObservers: [NSObjectProtocol] = []

    init() {
        setupAudio()
        observeAudioNotifications()
    }

    deinit {
        timer?.cancel()
        audioEngine.stop()
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func setupAudio() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            // Continue gracefully if audio session setup fails
        }

        let sampleRate: Double = 44100
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            return
        }

        for timbre in MetronomeSound.allCases {
            accentBuffers[timbre] = synthesizeBuffer(for: timbre, accent: true, format: format)
            regularBuffers[timbre] = synthesizeBuffer(for: timbre, accent: false, format: format)
        }
        countInBuffer = synthesizeCountInBuffer(format: format)

        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: format)

        do {
            try audioEngine.start()
            audioConfigured = true
        } catch {
            audioConfigured = false
        }
    }

    private func observeAudioNotifications() {
        let nc = NotificationCenter.default
        let interruption = nc.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let info = notification.userInfo,
                  let typeVal = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeVal) else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch type {
                case .began:
                    if self.isRunning {
                        self.stop()
                    }
                case .ended:
                    try? AVAudioSession.sharedInstance().setActive(true)
                    try? self.audioEngine.start()
                @unknown default:
                    break
                }
            }
        }

        let routeChange = nc.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.audioConfigured && !self.audioEngine.isRunning {
                    try? self.audioEngine.start()
                }
            }
        }
        notificationObservers = [interruption, routeChange]
    }

    // MARK: - Studio Acoustic Percussion Synthesis

    private func synthesizeBuffer(
        for timbre: MetronomeSound,
        accent: Bool,
        format: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        let sr = format.sampleRate
        let duration: Double
        switch timbre {
        case .warmWoodblock: duration = 0.085
        case .classicMechanical: duration = 0.050
        case .guitarBodyTap: duration = 0.110
        case .softMarimba: duration = 0.160
        }

        let frameCount = AVAudioFrameCount(sr * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let samples = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount

        // Deterministic pseudo-random noise state for organic wooden strike transient
        var seed: UInt64 = accent ? 0x9E3779B97F4A7C15 : 0xBF58476D1CE4E5B9
        func nextNoise() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let val = Double((seed >> 33) & 0x7FFFFFFF) / Double(0x7FFFFFFF)
            return val * 2.0 - 1.0
        }

        var lpNoise = 0.0

        for i in 0..<Int(frameCount) {
            let t = Double(i) / sr
            let rawNoise = nextNoise()
            lpNoise = lpNoise * 0.72 + rawNoise * 0.28
            let sample: Double

            switch timbre {
            case .warmWoodblock:
                // Hollow resonant woodblock / studio claves (warm body + subtle mallet tap)
                let f1 = accent ? 840.0 : 620.0
                let f2 = f1 * 1.48
                let f3 = f1 * 2.76
                let attack = min(1.0, t / 0.0014)
                let body1 = sin(2.0 * .pi * f1 * t) * exp(-t * 48.0) * 0.72
                let body2 = sin(2.0 * .pi * f2 * t) * exp(-t * 78.0) * 0.34
                let body3 = sin(2.0 * .pi * f3 * t) * exp(-t * 145.0) * 0.14
                let strike = lpNoise * exp(-t * 520.0) * 0.38
                sample = attack * (body1 + body2 + body3 + strike) * (accent ? 0.92 : 0.68)

            case .classicMechanical:
                // Crisp Wittner mechanical metronome wood-box tick/tack
                let fBox = accent ? 1420.0 : 1060.0
                let fRes = accent ? 2850.0 : 2120.0
                let attack = min(1.0, t / 0.0005)
                let click = (sin(2.0 * .pi * fBox * t) * 0.65 + sin(2.0 * .pi * fRes * t) * 0.32) * exp(-t * 140.0)
                let snap = rawNoise * exp(-t * 850.0) * 0.45
                sample = attack * (click + snap) * (accent ? 0.90 : 0.65)

            case .guitarBodyTap:
                // Acoustic guitar top-plate thump (accent) & side-rim wooden tap (regular)
                let attack = min(1.0, t / 0.0022)
                if accent {
                    // Warm downward pitch drop like palm/knuckle tap on spruce soundboard
                    let sweep = 215.0 + 95.0 * exp(-t * 65.0)
                    let thump = sin(2.0 * .pi * sweep * t) * exp(-t * 34.0) * 0.85
                    let wood = sin(2.0 * .pi * 540.0 * t) * exp(-t * 85.0) * 0.28
                    let skin = lpNoise * exp(-t * 380.0) * 0.35
                    sample = attack * (thump + wood + skin) * 0.95
                } else {
                    let rim1 = sin(2.0 * .pi * 490.0 * t) * exp(-t * 62.0) * 0.62
                    let rim2 = sin(2.0 * .pi * 920.0 * t) * exp(-t * 120.0) * 0.25
                    let tap = lpNoise * exp(-t * 460.0) * 0.28
                    sample = attack * (rim1 + rim2 + tap) * 0.72
                }

            case .softMarimba:
                // Gentle wooden marimba mallet chime (D5+A5 fifth on beat 1, A4 on beats 2-4)
                let attack = min(1.0, t / 0.0035)
                if accent {
                    let fRoot = 587.33 // D5
                    let fFifth = 880.00 // A5
                    let fHarm = fRoot * 4.0 // Classic marimba 4x bar overtone
                    let tone = sin(2.0 * .pi * fRoot * t) * exp(-t * 24.0) * 0.65
                        + sin(2.0 * .pi * fFifth * t) * exp(-t * 30.0) * 0.28
                        + sin(2.0 * .pi * fHarm * t) * exp(-t * 120.0) * 0.12
                    let mallet = lpNoise * exp(-t * 480.0) * 0.16
                    sample = attack * (tone + mallet) * 0.85
                } else {
                    let fRoot = 440.00 // A4
                    let fHarm = fRoot * 4.0
                    let tone = sin(2.0 * .pi * fRoot * t) * exp(-t * 28.0) * 0.68
                        + sin(2.0 * .pi * fHarm * t) * exp(-t * 130.0) * 0.10
                    let mallet = lpNoise * exp(-t * 520.0) * 0.14
                    sample = attack * (tone + mallet) * 0.68
                }
            }

            // Soft limiter (tanh) to ensure warm, clip-free output
            samples[i] = Float(tanh(sample))
        }
        return buffer
    }

    private func synthesizeCountInBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let sr = format.sampleRate
        let duration = 0.045
        let frameCount = AVAudioFrameCount(sr * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let samples = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount

        for i in 0..<Int(frameCount) {
            let t = Double(i) / sr
            let attack = min(1.0, t / 0.001)
            let click = (sin(2.0 * .pi * 1280.0 * t) * 0.6 + sin(2.0 * .pi * 1920.0 * t) * 0.28) * exp(-t * 110.0)
            samples[i] = Float(tanh(attack * click * 0.62))
        }
        return buffer
    }

    // MARK: - Playback Controls

    func preview(sound timbre: MetronomeSound) {
        sound = timbre
        guard !isMuted, audioConfigured else { return }
        if !audioEngine.isRunning {
            try? audioEngine.start()
        }
        guard let buffer = accentBuffers[timbre] else { return }
        playerNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        if !playerNode.isPlaying {
            playerNode.play()
        }
    }

    func start(withCountIn: Bool? = nil, resetProgress: Bool = true) {
        guard !isRunning else { return }
        if !audioEngine.isRunning && audioConfigured {
            try? audioEngine.start()
        }
        strongImpact.prepare()
        lightImpact.prepare()

        let useCountIn = withCountIn ?? countInEnabled
        isRunning = true
        isCountingIn = useCountIn
        countInBeat = 0
        if resetProgress {
            currentBeat = 0
            totalBeatCount = 0
        }
        scheduleTimer(fireImmediately: true)
    }

    /// Pauses playback while preserving `totalBeatCount` and `currentBeat` so visualizers resume seamlessly.
    func pause() {
        timer?.cancel()
        timer = nil
        playerNode.stop()
        isRunning = false
        isCountingIn = false
        countInBeat = 0
    }

    func stop() {
        timer?.cancel()
        timer = nil
        playerNode.stop()
        isRunning = false
        isCountingIn = false
        countInBeat = 0
        currentBeat = 0
        totalBeatCount = 0
    }

    func toggle() {
        if isRunning {
            pause()
        } else {
            let hasProgress = totalBeatCount > 0
            start(resetProgress: !hasProgress)
        }
    }

    func dropTenBPM() {
        bpm = max(30, bpm - 10)
    }

    private func rescheduleTimer() {
        scheduleTimer(fireImmediately: false)
    }

    private func scheduleTimer(fireImmediately: Bool) {
        timer?.cancel()
        let interval = 60.0 / Double(max(bpm, 30))
        let newTimer = DispatchSource.makeTimerSource(queue: timerQueue)
        let startDeadline: DispatchTime = fireImmediately ? .now() : .now() + interval
        newTimer.schedule(deadline: startDeadline, repeating: interval, leeway: .milliseconds(2))
        newTimer.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleTick()
            }
        }
        timer = newTimer
        newTimer.resume()
    }

    private func handleTick() {
        guard isRunning else { return }

        if isCountingIn {
            if countInBeat < 4 {
                countInBeat += 1
                playCountInClick()
                if hapticsEnabled {
                    lightImpact.impactOccurred()
                }
                return
            } else {
                // Count-in finished; transition cleanly into Beat 1!
                isCountingIn = false
                countInBeat = 0
            }
        }

        let nextBeat = (currentBeat % 4) + 1
        let tickTime = CFAbsoluteTimeGetCurrent()
        lastTickTimestamp = tickTime
        currentBeat = nextBeat
        totalBeatCount += 1

        let isAccent = (nextBeat == 1)
        playClick(accent: isAccent)
        onBeatTick?(totalBeatCount, nextBeat, tickTime)

        if hapticsEnabled {
            if isAccent {
                strongImpact.impactOccurred()
            } else {
                lightImpact.impactOccurred()
            }
        }
    }

    private func playClick(accent: Bool) {
        guard !isMuted, audioConfigured else { return }
        if !audioEngine.isRunning {
            try? audioEngine.start()
        }
        let buffer = accent ? accentBuffers[sound] : regularBuffers[sound]
        guard let buffer else { return }
        playerNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        if !playerNode.isPlaying {
            playerNode.play()
        }
    }

    private func playCountInClick() {
        guard !isMuted, audioConfigured else { return }
        if !audioEngine.isRunning {
            try? audioEngine.start()
        }
        guard let buffer = countInBuffer else { return }
        playerNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        if !playerNode.isPlaying {
            playerNode.play()
        }
    }
}
