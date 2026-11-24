import SwiftUI

struct PracticeSessionConfig: Identifiable {
    let id = UUID()
    let stages: [TrainingStageKind]
    let title: String

    static var fullTenMinutePlan: PracticeSessionConfig {
        PracticeSessionConfig(stages: TrainingStageKind.allCases, title: "今日 10 分钟完整训练")
    }

    static func single(_ stage: TrainingStageKind) -> PracticeSessionConfig {
        PracticeSessionConfig(stages: [stage], title: "阶段 \(stage.index) · \(stage.phaseTitle)")
    }
}

struct PracticeSessionView: View {
    let config: PracticeSessionConfig
    @EnvironmentObject private var store: PracticeStore
    @Environment(\.dismiss) private var dismiss

    @StateObject private var metronome = MetronomeEngine()
    @State private var currentIndex: Int = 0
    @State private var remainingSeconds: Int = 120
    @State private var elapsedTotalSeconds: Int = 0
    @State private var completedStages: Set<TrainingStageKind> = []
    @State private var tensionDropToast: Bool = false
    @State private var showCompletionSheet: Bool = false
    @State private var showRequirementDetail: Bool = false

    // Stage transition rest/prep state
    @State private var pendingNextIndex: Int?
    @State private var transitionCountdown: Int = 10

    // Post-session assessment
    @State private var zeroMistakesTwoMinutes: Bool = false
    @State private var noForearmTension: Bool = false
    @State private var appliedSpeedUp: Bool = false

    private let secondTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var currentStage: TrainingStageKind {
        config.stages[min(currentIndex, config.stages.count - 1)]
    }

    private var stageProgress: Double {
        let total = Double(currentStage.durationSeconds)
        guard total > 0 else { return 0 }
        return min(1.0, max(0.0, (total - Double(remainingSeconds)) / total))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        currentStage.accentColor.opacity(0.16),
                        Color(.systemBackground),
                        Color(.systemBackground)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 15) {
                        stageProgressHeader
                        timerAndBeatCard
                        StageVisualizerView(
                            stage: currentStage,
                            currentBeat: metronome.currentBeat,
                            totalBeatCount: metronome.totalBeatCount,
                            isRunning: metronome.isRunning && !metronome.isCountingIn,
                            fChordStyle: store.fChordStyle,
                            spiderPattern: store.spiderPattern
                        )

                        quickTipCard

                        if metronome.isRunning {
                            tensionDropButton
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        } else {
                            Group {
                                if currentStage == .spiderWalk {
                                    spiderPatternPicker
                                } else if currentStage == .chordTransition {
                                    fChordStylePicker
                                }
                                metronomeControlPanel
                            }
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }

                        transportBar
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .animation(.spring(response: 0.34, dampingFraction: 0.86), value: metronome.isRunning)
                }

                if let nextIdx = pendingNextIndex {
                    stageTransitionOverlay(nextStage: config.stages[nextIdx], nextIndex: nextIdx)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
            .animation(.easeInOut(duration: 0.22), value: pendingNextIndex != nil)
            .navigationTitle("阶段 \(currentStage.index)/\(config.stages.count) · \(currentStage.phaseTitle)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("结束") {
                        metronome.stop()
                        pendingNextIndex = nil
                        if elapsedTotalSeconds >= 20 {
                            showCompletionSheet = true
                        } else {
                            dismiss()
                        }
                    }
                }
                if !metronome.isRunning {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showRequirementDetail = true
                        } label: {
                            Image(systemName: "info.circle")
                        }
                    }
                }
            }
            .onAppear {
                UIApplication.shared.isIdleTimerDisabled = true
                syncMetronomePreferences()
                loadStage(at: 0, autoStart: false)
            }
            .onDisappear {
                UIApplication.shared.isIdleTimerDisabled = false
                metronome.stop()
            }
            .onReceive(secondTimer) { _ in
                if let nextIdx = pendingNextIndex {
                    if transitionCountdown > 1 {
                        transitionCountdown -= 1
                    } else {
                        beginPendingStage(at: nextIdx)
                    }
                    return
                }

                guard metronome.isRunning && !metronome.isCountingIn else { return }
                elapsedTotalSeconds += 1
                if remainingSeconds > 1 {
                    remainingSeconds -= 1
                } else {
                    remainingSeconds = 0
                    handleStageCompleted()
                }
            }
            .sheet(isPresented: $showRequirementDetail) {
                stageDetailSheet
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showCompletionSheet, onDismiss: {
                dismiss()
            }) {
                completionSummarySheet
                    .interactiveDismissDisabled()
            }
        }
    }

    // MARK: - Subviews

    private var stageProgressHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ForEach(Array(config.stages.enumerated()), id: \.element.id) { idx, stage in
                    let isDone = completedStages.contains(stage)
                    let isCurrent = idx == currentIndex
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(
                            isDone ? stage.accentColor :
                            isCurrent ? stage.accentColor.opacity(0.65) :
                            Color.primary.opacity(0.12)
                        )
                        .frame(height: 6)
                }
            }

            HStack {
                Text(currentStage.exerciseName)
                    .font(.headline)
                Spacer()
                if metronome.isRunning {
                    Text("\(metronome.bpm) BPM")
                        .font(.caption.bold().monospacedDigit())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(currentStage.accentColor.opacity(0.16), in: Capsule())
                        .foregroundStyle(currentStage.accentColor)
                } else {
                    Text(currentStage.recommendedBPMText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var timerAndBeatCard: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    if metronome.isCountingIn {
                        Text("预备拍 · 摆好手型")
                            .font(.caption.bold())
                            .foregroundStyle(.orange)
                        Text("预备 \(max(1, metronome.countInBeat)) / 4")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(.orange)
                            .monospacedDigit()
                    } else {
                        Text("本阶段剩余")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(formatTime(remainingSeconds))
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .monospacedDigit()
                    }
                }

                Spacer()

                // 4/4 Beat LED indicator
                HStack(spacing: 10) {
                    ForEach(1...4, id: \.self) { beat in
                        let isCountInLit = metronome.isCountingIn && metronome.countInBeat == beat
                        let isPlayLit = metronome.isRunning && !metronome.isCountingIn && metronome.currentBeat == beat
                        let isLit = isCountInLit || isPlayLit
                        let isAccent = (beat == 1)

                        VStack(spacing: 4) {
                            Circle()
                                .fill(
                                    isCountInLit
                                        ? Color.orange
                                        : isPlayLit
                                            ? (isAccent ? currentStage.accentColor : Color.primary)
                                            : Color.primary.opacity(0.12)
                                )
                                .frame(width: isAccent ? 24 : 20, height: isAccent ? 24 : 20)
                                .scaleEffect(isLit ? 1.18 : 1.0)
                                .animation(.spring(response: 0.14, dampingFraction: 0.6), value: isLit)
                            Text("\(beat)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(isLit ? .primary : .secondary)
                        }
                    }
                }
            }

            ProgressView(value: stageProgress)
                .tint(metronome.isCountingIn ? .orange : currentStage.accentColor)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    metronome.isCountingIn ? Color.orange.opacity(0.4) : Color.primary.opacity(0.08),
                    lineWidth: 1
                )
        )
    }

    private var spiderPatternPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("爬格子指型")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(store.spiderPattern.badgeText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(TrainingStageKind.spiderWalk.accentColor)
            }
            Picker("爬格子指型", selection: $store.spiderPattern) {
                ForEach(SpiderPattern.allCases) { pattern in
                    Text(pattern.rawValue).tag(pattern)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var fChordStylePicker: some View {
        Picker("F 和弦指法", selection: $store.fChordStyle) {
            ForEach(FChordStyle.allCases) { style in
                Text(style.rawValue).tag(style)
            }
        }
        .pickerStyle(.segmented)
    }

    private var quickTipCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundStyle(currentStage.accentColor)
            Text(currentStage.quickTip)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(currentStage.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var metronomeControlPanel: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("节拍器速度 (4/4 拍)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(metronome.bpm)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text("BPM")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    bpmStepButton(delta: -5, label: "-5")
                    bpmStepButton(delta: 5, label: "+5")
                }
            }

            // Smooth BPM slider
            Slider(
                value: Binding(
                    get: { Double(metronome.bpm) },
                    set: { newVal in
                        let rounded = Int(newVal.rounded())
                        metronome.bpm = rounded
                        store.setBPM(rounded, for: currentStage)
                    }
                ),
                in: 30...140,
                step: 1
            )
            .tint(currentStage.accentColor)

            // Metronome timbre selector with live audition
            VStack(alignment: .leading, spacing: 6) {
                Text("节拍音色（点击试听切换）")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(MetronomeSound.allCases) { timbre in
                            let selected = store.metronomeSound == timbre
                            Button {
                                store.metronomeSound = timbre
                                metronome.preview(sound: timbre)
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: timbre.iconName)
                                        .font(.caption2)
                                    Text(timbre.displayName)
                                        .font(.caption.weight(.semibold))
                                }
                                .padding(.horizontal, 11)
                                .padding(.vertical, 7)
                                .background(
                                    selected ? currentStage.accentColor : Color.primary.opacity(0.07),
                                    in: Capsule()
                                )
                                .foregroundStyle(selected ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            tensionDropButton

            HStack(spacing: 8) {
                Toggle(isOn: Binding(
                    get: { !metronome.isMuted },
                    set: { metronome.isMuted = !$0 }
                )) {
                    Label("声音", systemImage: metronome.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.caption.weight(.medium))
                }
                .toggleStyle(.button)
                .tint(currentStage.accentColor)

                Toggle(isOn: Binding(
                    get: { store.hapticsEnabled },
                    set: {
                        store.hapticsEnabled = $0
                        metronome.hapticsEnabled = $0
                    }
                )) {
                    Label("震动", systemImage: "iphone.radiowaves.left.and.right")
                        .font(.caption.weight(.medium))
                }
                .toggleStyle(.button)
                .tint(currentStage.accentColor)

                Toggle(isOn: Binding(
                    get: { store.countInEnabled },
                    set: {
                        store.countInEnabled = $0
                        metronome.countInEnabled = $0
                    }
                )) {
                    Label("4拍预备", systemImage: "123.rectangle.fill")
                        .font(.caption.weight(.medium))
                }
                .toggleStyle(.button)
                .tint(.orange)

                Spacer()
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var tensionDropButton: some View {
        Button {
            metronome.dropTenBPM()
            store.setBPM(metronome.bpm, for: currentStage)
            withAnimation {
                tensionDropToast = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation {
                    tensionDropToast = false
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title3)
                VStack(alignment: .leading, spacing: 1) {
                    Text("手指紧绷或联动？立刻 -10 BPM")
                        .font(.subheadline.bold())
                    Text(tensionDropToast ? "已下调至 \(metronome.bpm) BPM，放松手背继续！" : "保护神经控制通路，宁慢勿僵")
                        .font(.caption2)
                        .opacity(0.9)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .foregroundStyle(.white)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.92, green: 0.30, blue: 0.38), Color(red: 0.85, green: 0.45, blue: 0.25)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }

    private func bpmStepButton(delta: Int, label: String) -> some View {
        Button {
            let next = min(max(metronome.bpm + delta, 30), 160)
            metronome.bpm = next
            store.setBPM(next, for: currentStage)
        } label: {
            Text(label)
                .font(.subheadline.bold().monospacedDigit())
                .frame(width: 50, height: 40)
                .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var transportBar: some View {
        HStack(spacing: 12) {
            if config.stages.count > 1 {
                Button {
                    guard currentIndex > 0 else { return }
                    loadStage(at: currentIndex - 1, autoStart: false)
                } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.title3)
                        .frame(width: 54, height: 54)
                        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .disabled(currentIndex == 0)
                .opacity(currentIndex == 0 ? 0.35 : 1)
            }

            Button {
                metronome.toggle()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: metronome.isRunning ? "pause.fill" : "play.fill")
                        .font(.title3)
                    Text(metronome.isRunning ? "暂停节拍器" : "开始本阶段训练")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(currentStage.accentColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)

            if config.stages.count > 1 {
                Button {
                    if currentIndex + 1 < config.stages.count {
                        enterTransition(to: currentIndex + 1)
                    } else {
                        metronome.stop()
                        showCompletionSheet = true
                    }
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.title3)
                        .frame(width: 54, height: 54)
                        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
    }

    // MARK: - Stage Transition Overlay

    private func stageTransitionOverlay(nextStage: TrainingStageKind, nextIndex: Int) -> some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(nextStage.accentColor.opacity(0.18))
                        .frame(width: 68, height: 68)
                    Image(systemName: nextStage.symbolName)
                        .font(.title)
                        .foregroundStyle(nextStage.accentColor)
                }

                VStack(spacing: 6) {
                    Text("即将进入阶段 \(nextStage.index) · \(nextStage.phaseTitle)")
                        .font(.headline)
                        .foregroundStyle(nextStage.accentColor)
                    Text(nextStage.exerciseName)
                        .font(.title3.bold())
                    Text(nextStage.transitionPrompt)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }

                Text("\(transitionCountdown) 秒后自动开始")
                    .font(.caption.bold().monospacedDigit())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.08), in: Capsule())

                Button {
                    beginPendingStage(at: nextIndex)
                } label: {
                    Text("已就位，立即开始")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(nextStage.accentColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(.horizontal, 24)
        }
    }

    private var stageDetailSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Label("阶段 \(currentStage.index) · \(currentStage.phaseTitle)", systemImage: currentStage.symbolName)
                        .font(.title3.bold())
                        .foregroundStyle(currentStage.accentColor)

                    Text(currentStage.exerciseName)
                        .font(.headline)

                    Text(currentStage.coreRequirement)
                        .font(.body)
                        .lineSpacing(5)

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("执行要点")
                            .font(.subheadline.bold())
                        Text("• 一毫米原则：抬起手指换弦时指尖离弦控制在 1–2 毫米以内。")
                        Text("• 紧绷降速：只要出现手指僵硬或无名指失控翘起，立刻 -10 BPM。")
                        Text("• 每周提速：当前速度连续 2 分钟零失误且前臂无酸胀，下周再 +5 BPM。")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .navigationTitle("动作规范")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("知道了") { showRequirementDetail = false }
                }
            }
        }
    }

    private var completionSummarySheet: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 10) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.green)
                        Text("训练完成！")
                            .font(.title2.bold())
                        Text("本次专注练习 \(max(1, elapsedTotalSeconds / 60)) 分钟 · 完成 \(max(completedStages.count, 1)) 个阶段")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                Section("每周提速自检（+5 BPM 标准）") {
                    Toggle("连续弹奏 2 分钟以上零失误", isOn: $zeroMistakesTwoMinutes)
                    Toggle("手背与前臂完全没有酸胀感", isOn: $noForearmTension)

                    if zeroMistakesTwoMinutes && noForearmTension {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("已达标！你的神经控制已稳定，可为各阶段提速 +5 BPM。")
                                .font(.caption)
                                .foregroundStyle(.green)
                            if !appliedSpeedUp {
                                Button("一键将所有阶段目标 +5 BPM") {
                                    store.applyWeeklySpeedUp()
                                    appliedSpeedUp = true
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.green)
                            } else {
                                Label("已将各阶段速度提升 +5 BPM", systemImage: "checkmark.circle.fill")
                                    .font(.caption.bold())
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    Button {
                        saveRecordAndFinish()
                    } label: {
                        Text("保存今日打卡记录")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("训练打卡")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Helpers

    private func syncMetronomePreferences() {
        metronome.sound = store.metronomeSound
        metronome.hapticsEnabled = store.hapticsEnabled
        metronome.countInEnabled = store.countInEnabled
    }

    private func loadStage(at index: Int, autoStart: Bool) {
        currentIndex = index
        let stage = config.stages[index]
        remainingSeconds = stage.durationSeconds
        syncMetronomePreferences()
        metronome.bpm = store.bpm(for: stage)
        metronome.stop()
        if autoStart {
            metronome.start(withCountIn: store.countInEnabled)
        }
    }

    private func enterTransition(to nextIndex: Int) {
        metronome.stop()
        transitionCountdown = 10
        pendingNextIndex = nextIndex
    }

    private func beginPendingStage(at nextIndex: Int) {
        pendingNextIndex = nil
        loadStage(at: nextIndex, autoStart: true)
    }

    private func handleStageCompleted() {
        completedStages.insert(currentStage)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        if currentIndex + 1 < config.stages.count {
            enterTransition(to: currentIndex + 1)
        } else {
            metronome.stop()
            showCompletionSheet = true
        }
    }

    private func saveRecordAndFinish() {
        var bpmSnapshot: [String: Int] = [:]
        for stage in config.stages {
            bpmSnapshot[stage.rawValue] = store.bpm(for: stage)
        }
        let finished = completedStages.isEmpty ? [currentStage] : Array(completedStages)
        let record = PracticeRecord(
            durationSeconds: max(elapsedTotalSeconds, 60),
            completedStages: finished,
            stageBPMs: bpmSnapshot,
            zeroMistakesTwoMinutes: zeroMistakesTwoMinutes,
            noForearmTension: noForearmTension
        )
        store.addRecord(record)
        showCompletionSheet = false
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}
