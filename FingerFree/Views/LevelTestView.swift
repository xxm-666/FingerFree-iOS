import SwiftUI

struct LevelTestView: View {
    let level: TrainingLevel
    @EnvironmentObject private var store: PracticeStore
    @Environment(\.dismiss) private var dismiss

    @StateObject private var metronome = MetronomeEngine()
    @StateObject private var audioEngine = AudioTestEngine()

    @State private var selectedTierIndex: Int = 0
    @State private var remainingSeconds: Int = 45
    @State private var isTesting: Bool = false
    @State private var silentVisualMetronome: Bool = false

    // Lv.1 non-audio manual counters
    @State private var manualMistakes: Int = 0
    @State private var manualLinkages: Int = 0

    // Post-test 1-tap relaxation check & final result
    @State private var noForearmTension: Bool = true
    @State private var showPostCheck: Bool = false
    @State private var finalScore: Int? = nil
    @State private var finalRank: ProficiencyRank = .unranked
    @State private var lastAudioSummary: AudioTestMetrics? = nil

    private let secondTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var spec: LevelTestSpec { level.testSpec }
    private var selectedTier: TestSpeedTier { spec.tiers[min(selectedTierIndex, spec.tiers.count - 1)] }
    private var testExercise: ExerciseItem { spec.exercise }

    private var currentTargetNoteLabel: String {
        if level.isChordAudioTest {
            return "每第 1 拍准时扫响和弦"
        }
        guard isTesting && !metronome.isCountingIn && metronome.totalBeatCount > 0 else {
            return "准备收音"
        }
        return testExercise.expectedTargetNote(atBeat: metronome.totalBeatCount)?.label ?? "跟拍弹奏"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerBanner

                    if let score = finalScore {
                        resultCard(score: score, rank: finalRank)
                    } else if showPostCheck {
                        postTestCheckCard
                    } else {
                        if !isTesting {
                            tierSelectionCard
                        }

                        testCountdownAndVisualizer

                        if spec.usesAudioAnalysis {
                            liveAudioTelemetryCard
                        } else {
                            manualWakeupCountersCard
                        }

                        actionButtons
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("\(level.code) 阶段熟练度考核")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("退出") {
                        stopEverything()
                        dismiss()
                    }
                }
            }
            .onAppear {
                UIApplication.shared.isIdleTimerDisabled = true
                remainingSeconds = spec.durationSeconds
                metronome.sound = store.metronomeSound
                metronome.hapticsEnabled = store.hapticsEnabled
                metronome.countInEnabled = true
            }
            .onDisappear {
                UIApplication.shared.isIdleTimerDisabled = false
                stopEverything()
            }
            .onChange(of: metronome.totalBeatCount) { _, newBeat in
                guard isTesting && spec.usesAudioAnalysis && newBeat > 0 else { return }
                let target = testExercise.expectedTargetNote(atBeat: newBeat)?.midi
                audioEngine.onBeat(
                    expectedMIDI: target,
                    bpm: selectedTier.bpm,
                    isChordMode: level.isChordAudioTest,
                    isChordChangeBeat: ((newBeat - 1) % 4 == 0),
                    metronomeSoundActive: !metronome.isMuted
                )
            }
            .onReceive(secondTimer) { _ in
                guard isTesting && !metronome.isCountingIn else { return }
                if remainingSeconds > 1 {
                    remainingSeconds -= 1
                } else {
                    remainingSeconds = 0
                    finishCaptureAndShowPostCheck()
                }
            }
        }
    }

    // MARK: - Subviews

    private var headerBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(spec.usesAudioAnalysis ? "实时麦克风音频测评" : "无琴神经控制考核（免麦克风）",
                      systemImage: spec.usesAudioAnalysis ? "mic.fill" : "hand.raised.fill")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(level.accentColor.opacity(0.16), in: Capsule())
                    .foregroundStyle(level.accentColor)
                Spacer()
                Text("\(spec.durationSeconds) 秒")
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Text(spec.title)
                .font(.headline)
            Text(spec.requirement)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var tierSelectionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("选择挑战速度档位")
                .font(.subheadline.bold())

            HStack(spacing: 8) {
                ForEach(Array(spec.tiers.enumerated()), id: \.element.id) { idx, tier in
                    let selected = idx == selectedTierIndex
                    Button {
                        selectedTierIndex = idx
                    } label: {
                        VStack(spacing: 3) {
                            Text(tier.name).font(.subheadline.bold())
                            Text("\(tier.bpm) BPM").font(.caption.monospacedDigit()).opacity(0.85)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selected ? level.accentColor : Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(selected ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if spec.usesAudioAnalysis {
                Toggle(isOn: $silentVisualMetronome) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("静音节拍器（推荐耳机或纯视觉跟拍）")
                            .font(.caption.weight(.semibold))
                        Text("关闭外放节拍声可彻底消除麦克风串音，音准识别最精准")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(level.accentColor)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var testCountdownAndVisualizer: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(metronome.isCountingIn ? "预备拍 · 准备弹奏" : "考核剩余时间")
                        .font(.caption.bold())
                        .foregroundStyle(metronome.isCountingIn ? .orange : .secondary)
                    Text(metronome.isCountingIn ? "预备 \(max(1, metronome.countInBeat)) / 4" : String(format: "%02d:%02d", remainingSeconds / 60, remainingSeconds % 60))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(metronome.isCountingIn ? .orange : .primary)
                        .monospacedDigit()
                }
                Spacer()
                HStack(spacing: 8) {
                    ForEach(1...4, id: \.self) { beat in
                        let lit = metronome.isCountingIn ? (metronome.countInBeat == beat) : (isTesting && metronome.currentBeat == beat)
                        Circle()
                            .fill(lit ? (metronome.isCountingIn ? Color.orange : (beat == 1 ? level.accentColor : Color.primary)) : Color.primary.opacity(0.14))
                            .frame(width: beat == 1 ? 22 : 18, height: beat == 1 ? 22 : 18)
                    }
                }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            ExerciseVisualizerView(
                exercise: testExercise,
                currentBeat: metronome.currentBeat,
                totalBeatCount: metronome.totalBeatCount,
                isRunning: isTesting && !metronome.isCountingIn,
                fChordStyle: store.fChordStyle
            )
        }
    }

    private var liveAudioTelemetryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(audioEngine.isListening ? "麦克风实时监测中" : "实时音频监测就绪",
                      systemImage: audioEngine.isListening ? "waveform.circle.fill" : "mic.circle")
                    .font(.caption.bold())
                    .foregroundStyle(audioEngine.isListening ? .green : .secondary)
                Spacer()
                if audioEngine.permissionDenied {
                    Text("请在系统设置中开启麦克风权限")
                        .font(.caption2.bold())
                        .foregroundStyle(.red)
                } else {
                    Text(currentTargetNoteLabel)
                        .font(.caption.bold())
                        .foregroundStyle(level.accentColor)
                }
            }

            // Live Input Volume Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.1))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [level.accentColor, .green],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, geo.size.width * audioEngine.inputLevel))
                        .animation(.easeOut(duration: 0.08), value: audioEngine.inputLevel)
                }
            }
            .frame(height: 10)

            HStack(spacing: 10) {
                telemetryBadge(
                    title: level.isChordAudioTest ? "扫弦响应" : "识别音高",
                    value: level.isChordAudioTest
                        ? (audioEngine.inputLevel > 0.15 ? "已捕获 ✓" : "等待扫弦")
                        : "\(audioEngine.detectedNoteName)\(audioEngine.currentBeatPitchMatched ? " ✓" : "")",
                    highlight: audioEngine.currentBeatPitchMatched || (level.isChordAudioTest && audioEngine.inputLevel > 0.15)
                )

                telemetryBadge(
                    title: "节奏偏差",
                    value: timingBadgeText,
                    highlight: (audioEngine.lastTimingOffsetMs.map { abs($0) <= 115 } ?? false)
                )

                telemetryBadge(
                    title: "音色清晰",
                    value: "\(Int(audioEngine.detectedClarity * 100))%",
                    highlight: audioEngine.detectedClarity >= 0.65
                )
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var timingBadgeText: String {
        guard let ms = audioEngine.lastTimingOffsetMs else { return "--" }
        if abs(ms) <= 45 { return "精准 \(ms)ms" }
        return ms < 0 ? "偏快 \(ms)ms" : "偏慢 +\(ms)ms"
    }

    private func telemetryBadge(title: String, value: String, highlight: Bool) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(highlight ? .green : .primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var manualWakeupCountersCard: some View {
        VStack(spacing: 10) {
            Text("考核中若出现明显抢拍或手指伴随翘起，可轻点记录：")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Button {
                    manualMistakes += 1
                } label: {
                    VStack(spacing: 4) {
                        Text("\(manualMistakes)")
                            .font(.title3.bold().monospacedDigit())
                        Text("记一次节奏失误")
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)

                Button {
                    manualLinkages += 1
                } label: {
                    VStack(spacing: 4) {
                        Text("\(manualLinkages)")
                            .font(.title3.bold().monospacedDigit())
                        Text("记一次手指联动")
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var actionButtons: some View {
        Group {
            if isTesting {
                Button {
                    finishCaptureAndShowPostCheck()
                } label: {
                    Text("结束考核并生成评分")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.green, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    startTest()
                } label: {
                    HStack {
                        Image(systemName: spec.usesAudioAnalysis ? "mic.fill" : "play.fill")
                        Text("开始 \(selectedTier.bpm) BPM 阶段考核")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(level.accentColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var postTestCheckCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("最后一步：1 秒肌肉放松度自检")
                .font(.headline)

            if let summary = lastAudioSummary {
                HStack(spacing: 10) {
                    telemetryBadge(title: level.isChordAudioTest ? "换弦响应" : "音准命中", value: "\(Int(summary.pitchAccuracy * 100))%", highlight: summary.pitchAccuracy >= 0.75)
                    telemetryBadge(title: "节奏同步", value: "\(Int(summary.rhythmAccuracy * 100))%", highlight: summary.rhythmAccuracy >= 0.75)
                    telemetryBadge(title: "音色清晰", value: "\(Int(summary.clarityScore * 100))%", highlight: summary.clarityScore >= 0.65)
                }
            }

            Toggle("刚才考核全程手背与前臂完全无酸胀感", isOn: $noForearmTension)
                .font(.subheadline)
                .tint(level.accentColor)

            Button {
                computeAndSaveFinalScore()
            } label: {
                Text("生成本阶段熟练度报告")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(level.accentColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func resultCard(score: Int, rank: ProficiencyRank) -> some View {
        VStack(spacing: 16) {
            Text("\(level.code) \(level.title) · 熟练度评级")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text("\(score)%")
                    .font(.system(size: 54, weight: .black, design: .rounded))
                    .foregroundStyle(level.accentColor)
                    .monospacedDigit()
                Text("\(rank.rawValue) 级")
                    .font(.title2.bold())
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(level.accentColor, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }

            if let summary = lastAudioSummary {
                HStack(spacing: 10) {
                    telemetryBadge(title: level.isChordAudioTest ? "扫弦响应" : "音准命中", value: "\(Int(summary.pitchAccuracy * 100))%", highlight: summary.pitchAccuracy >= 0.75)
                    telemetryBadge(title: "节奏同步", value: "\(Int(summary.rhythmAccuracy * 100))%", highlight: summary.rhythmAccuracy >= 0.75)
                    telemetryBadge(title: "平均偏差", value: "±\(summary.avgTimingOffsetMs)ms", highlight: summary.avgTimingOffsetMs <= 80)
                }
            }

            Text(rank.advice)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))

            HStack(spacing: 12) {
                Button {
                    resetTestState()
                } label: {
                    Text("重新考核")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)

                Button {
                    dismiss()
                } label: {
                    Text("返回路径")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(level.accentColor, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(level.accentColor.opacity(0.45), lineWidth: 1.5)
        )
    }

    // MARK: - Logic

    private func startTest() {
        remainingSeconds = spec.durationSeconds
        manualMistakes = 0
        manualLinkages = 0
        finalScore = nil
        showPostCheck = false
        lastAudioSummary = nil

        metronome.bpm = selectedTier.bpm
        metronome.isMuted = spec.usesAudioAnalysis ? silentVisualMetronome : false
        metronome.hapticsEnabled = store.hapticsEnabled
        metronome.countInEnabled = true

        if spec.usesAudioAnalysis {
            audioEngine.resetMetrics()
            audioEngine.startListening()
        }

        isTesting = true
        metronome.start(withCountIn: true)
    }

    private func finishCaptureAndShowPostCheck() {
        isTesting = false
        metronome.stop()
        if spec.usesAudioAnalysis {
            lastAudioSummary = audioEngine.computeSummary()
            audioEngine.stopListening()
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showPostCheck = true
    }

    private func computeAndSaveFinalScore() {
        let relaxPoints = noForearmTension ? 15.0 : 5.0
        let rawScore: Double

        if spec.usesAudioAnalysis, let audio = lastAudioSummary {
            if level.isChordAudioTest {
                // Chord stage: Onset rhythm sync 45% + clarity/sustain 40% + relaxation 15%, scaled by speed tier
                let perf = (audio.rhythmAccuracy * 45.0) + (max(audio.clarityScore, audio.pitchAccuracy * 0.85) * 40.0)
                rawScore = perf * selectedTier.speedWeight + relaxPoints
            } else {
                // Single-note stages (Lv.2–Lv.4): Pitch 40% + Rhythm 30% + Clarity 15% + Relaxation 15%
                let perf = (audio.pitchAccuracy * 40.0) + (audio.rhythmAccuracy * 30.0) + (audio.clarityScore * 15.0)
                rawScore = perf * selectedTier.speedWeight + relaxPoints
            }
        } else {
            // Lv.1 Wakeup (no audio): Speed tier 35% + Mistake-free 30% + Zero-linkage 20% + Relaxation 15%
            let speedPts = 35.0 * selectedTier.speedWeight
            let mistakePts = max(0.0, 30.0 - Double(manualMistakes) * 6.0)
            let linkagePts = max(0.0, 20.0 - Double(manualLinkages) * 7.0)
            rawScore = speedPts + mistakePts + linkagePts + relaxPoints
        }

        let clamped = min(100, max(0, Int(rawScore.rounded())))
        let rank = ProficiencyRank.from(score: clamped)
        finalScore = clamped
        finalRank = rank
        showPostCheck = false
        store.recordTestResult(for: level, score: clamped, tier: selectedTier)
    }

    private func resetTestState() {
        stopEverything()
        remainingSeconds = spec.durationSeconds
        manualMistakes = 0
        manualLinkages = 0
        finalScore = nil
        showPostCheck = false
        lastAudioSummary = nil
    }

    private func stopEverything() {
        isTesting = false
        metronome.stop()
        audioEngine.stopListening()
    }
}
