import AVFoundation
import Foundation
import UIKit

@MainActor
final class MetronomeEngine: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var currentBeat: Int = 0       // 1...4 while running, 0 when stopped
    @Published private(set) var totalBeatCount: Int = 0    // 0-indexed continuous counter for visualizers
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
    @Published var isMuted: Bool = false
    @Published var hapticsEnabled: Bool = true

    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var accentBuffer: AVAudioPCMBuffer?
    private var regularBuffer: AVAudioPCMBuffer?
    private var timer: DispatchSourceTimer?
    private let timerQueue = DispatchQueue(label: "com.fingerfree.metronome.timer", qos: .userInteractive)
    private let strongImpact = UIImpactFeedbackGenerator(style: .medium)
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private var audioConfigured = false

    init() {
        setupAudio()
    }

    deinit {
        timer?.cancel()
        audioEngine.stop()
    }

    private func setupAudio() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            // Audio session may fail in simulator or restricted environments; continue gracefully.
        }

        let sampleRate: Double = 44100
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            return
        }

        accentBuffer = makeClickBuffer(format: format, frequency: 1180, duration: 0.045, amplitude: 0.78)
        regularBuffer = makeClickBuffer(format: format, frequency: 820, duration: 0.038, amplitude: 0.56)

        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: format)

        do {
            try audioEngine.start()
            audioConfigured = true
        } catch {
            audioConfigured = false
        }
    }

    private func makeClickBuffer(
        format: AVAudioFormat,
        frequency: Double,
        duration: Double,
        amplitude: Float
    ) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }
        buffer.frameLength = frameCount
        guard let samples = buffer.floatChannelData?[0] else { return nil }

        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            // Crisp woodblock-like percussive envelope (fast attack, exponential decay)
            let attack = min(1.0, t / 0.002)
            let decay = exp(-t * 95.0)
            let fundamental = sin(2.0 * .pi * frequency * t)
            let overtone = 0.25 * sin(2.0 * .pi * frequency * 2.15 * t)
            samples[i] = Float(attack * decay * (fundamental + overtone)) * amplitude
        }
        return buffer
    }

    func start() {
        guard !isRunning else { return }
        if !audioEngine.isRunning && audioConfigured {
            try? audioEngine.start()
        }
        strongImpact.prepare()
        lightImpact.prepare()
        isRunning = true
        currentBeat = 0
        totalBeatCount = 0
        scheduleTimer(fireImmediately: true)
    }

    func stop() {
        timer?.cancel()
        timer = nil
        playerNode.stop()
        isRunning = false
        currentBeat = 0
    }

    func toggle() {
        if isRunning {
            stop()
        } else {
            start()
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
        let nextBeat = (currentBeat % 4) + 1
        currentBeat = nextBeat
        totalBeatCount += 1

        let isAccent = (nextBeat == 1)
        playClick(accent: isAccent)

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
        guard let buffer = accent ? accentBuffer : regularBuffer else { return }
        playerNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        if !playerNode.isPlaying {
            playerNode.play()
        }
    }
}
