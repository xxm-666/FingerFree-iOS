import SwiftUI

struct PracticeSessionConfig: Identifiable {
    let id = UUID()
    let exercises: [ExerciseItem]
    let title: String

    static var classicTenMinuteMix: PracticeSessionConfig {
        PracticeSessionConfig(exercises: ExerciseItem.classicDailyTenMinuteMix, title: "每日 10 分钟经典热身")
    }

    static func single(_ exercise: ExerciseItem) -> PracticeSessionConfig {
        PracticeSessionConfig(exercises: [exercise], title: "\(exercise.level.code) · \(exercise.name)")
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
    @State private var completedIds: Set<String> = []
    @State private var tensionDropToast: Bool = false
    @State private var showCompletionSheet: Bool = false

    // Transition prep overlay between exercises in multi-stage sessions
    @State private var pendingNextIndex: Int?
    @State private var transitionCountdown: Int = 10

    // Post-session check-in
    @State private var zeroMistakesTwoMinutes: Bool = false
    @State private var noForearmTension: Bool = false
    @State private var appliedSpeedUp: Bool = false

    private let secondTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var currentExercise: ExerciseItem {
        config.exercises[min(currentIndex, config.exercises.count - 1)]
    }

    private var accentColor: Color {
        currentExercise.level.accentColor
    }

    private var stageProgress: Double {
        let total = Double(currentExercise.durationSeconds)
        guard total > 0 else { return 0 }
        return min(1.0, max(0.0, (total - Double(remainingSeconds)) / total))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        accentColor.opacity(0.16),
                        Color(.systemBackground),
                        Color(.systemBackground)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        headerBar
                        timerAndBeatCard
                        ExerciseVisualizerView(
                            exercise: currentExercise,
                            currentBeat: metronome.currentBeat,
                            totalBeatCount: metronome.totalBeatCount,
                            isRunning: metronome.isRunning && !metronome.isCountingIn,
                            fChordStyle: store.fChordStyle
                        )

                        quickTipCard

                        // FOCUS MODE: Hide ALL settings while running; restore when paused/stopped
                        if metronome.isRunning {
                            tensionDropButton
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        } else {
                            Group {
                                stepsGuideCard
                                if currentExercise.visualizerKind == .chordsBasic {
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
                    transitionOverlay(nextExercise: config.exercises[nextIdx], nextIndex: nextIdx)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
            .animation(.easeInOut(duration: 0.22), value: pendingNextIndex != nil)
            .navigationTitle("\(currentExercise.level.code) · \(currentExercise.level.title)")
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
            }
            .onAppear {
                UIApplication.shared.isIdleTimerDisabled = true
                syncMetronomePreferences()
                loadExercise(at: 0, autoStart: false)
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
                        beginPendingExercise(at: nextIdx)
                    }
                    return
                }
                guard metronome.isRunning && !metronome.isCountingIn else { return }
                elapsedTotalSeconds += 1
                if remainingSeconds > 1 {
                    remainingSeconds -= 1
                } else {
                    remainingSeconds = 0
                    handleExerciseCompleted()
                }
            }
            .sheet(isPresented: $showCompletionSheet, onDismiss: { dismiss() }) {
                completionSheet
                    .interactiveDismissDisabled()
            }
        }
    }

    // MARK: - Subviews

    private var headerBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            if config.exercises.count > 1 {
                HStack(spacing: 6) {
                    ForEach(Array(config.exercises.enumerated()), id: \.element.id) { idx, ex in
                        let isDone = completedIds.contains(ex.id)
                        let isCurrent = idx == currentIndex
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(
                                isDone ? ex.level.accentColor :
                                isCurrent ? ex.level.accentColor.opacity(0.7) :
                                Color.primary.opacity(0.12)
                            )
                            .frame(height: 6)
                    }
                }
            }

            HStack {
                Text(currentExercise.name)
                    .font(.headline)
                Spacer()
                if metronome.isRunning {
                    Text("\(metronome.bpm) BPM")
                        .font(.caption.bold().monospacedDigit())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(accentColor.opacity(0.16), in: Capsule())
                        .foregroundStyle(accentColor)
                } else {
                    Text(currentExercise.recommendedBPMText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var timerAndBeatCard: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    if metronome.isCountingIn {
                        Text("预备拍 · 摆好手型")
                            .font(.caption.bold())
                            .foregroundStyle(.orange)
                        Text("预备 \(max(1, metronome.countInBeat)) / 4")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(.orange)
                            .monospacedDigit()
                    } else {
                        Text("本项剩余")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(formatTime(remainingSeconds))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .monospacedDigit()
                    }
                }

                Spacer()

                HStack(spacing: 10) {
                    ForEach(1...4, id: \.self) { beat in
                        let isCountLit = metronome.isCountingIn && metronome.countInBeat == beat
                        let isPlayLit = metronome.isRunning && !metronome.isCountingIn && metronome.currentBeat == beat
                        let isLit = isCountLit || isPlayLit
                        VStack(spacing: 3) {
                            Circle()
                                .fill(
                                    isCountLit ? Color.orange :
                                    isPlayLit ? (beat == 1 ? accentColor : Color.primary) :
                                    Color.primary.opacity(0.12)
                                )
                                .frame(width: beat == 1 ? 24 : 20, height: beat == 1 ? 24 : 20)
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
                .tint(metronome.isCountingIn ? .orange : accentColor)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(metronome.isCountingIn ? Color.orange.opacity(0.4) : Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var quickTipCard: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundStyle(accentColor)
            Text(currentExercise.tip)
                .font(.caption.weight(.medium))
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var stepsGuideCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("详细动作要领")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            ForEach(Array(currentExercise.steps.enumerated()), id: \.offset) { idx, step in
                HStack(alignment: .top, spacing: 6) {
                    Text("\(idx + 1).")
                        .font(.caption.bold())
                        .foregroundStyle(accentColor)
                    Text(step)
                        .font(.caption)
                        .foregroundStyle(.primary.opacity(0.9))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var fChordStylePicker: some View {
        Picker("F 和弦指法", selection: $store.fChordStyle) {
            ForEach(FChordStyle.allCases) { style in
                Text(style.rawValue).tag(style)
            }
        }
        .pickerStyle(.segmented)
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
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text("BPM")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                HStack(spacing: 8) {
                    bpmStepButton(delta: -5, label: "-5")
                    bpmStepButton(delta: 5, label: "+5")
                }
            }

            Slider(
                value: Binding(
                    get: { Double(metronome.bpm) },
                    set: {
                        let rounded = Int($0.rounded())
                        metronome.bpm = rounded
                        store.setBPM(rounded, for: currentExercise)
                    }
                ),
                in: 30...140,
                step: 1
            )
            .tint(accentColor)

            VStack(alignment: .leading, spacing: 6) {
                Text("节拍音色（点击试听）")
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
                                HStack(spacing: 4) {
                                    Image(systemName: timbre.iconName).font(.caption2)
                                    Text(timbre.displayName).font(.caption.weight(.semibold))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(selected ? accentColor : Color.primary.opacity(0.07), in: Capsule())
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
                .tint(accentColor)

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
                .tint(accentColor)

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
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var tensionDropButton: some View {
        Button {
            metronome.dropTenBPM()
            store.setBPM(metronome.bpm, for: currentExercise)
            withAnimation { tensionDropToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation { tensionDropToast = false }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle.fill").font(.title3)
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
            .padding(.vertical, 10)
            .foregroundStyle(.white)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.92, green: 0.30, blue: 0.38), Color(red: 0.85, green: 0.45, blue: 0.25)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 15, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }

    private func bpmStepButton(delta: Int, label: String) -> some View {
        Button {
            let next = min(max(metronome.bpm + delta, 30), 160)
            metronome.bpm = next
            store.setBPM(next, for: currentExercise)
        } label: {
            Text(label)
                .font(.subheadline.bold().monospacedDigit())
                .frame(width: 48, height: 38)
                .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var transportBar: some View {
        HStack(spacing: 10) {
            if config.exercises.count > 1 {
                Button {
                    guard currentIndex > 0 else { return }
                    loadExercise(at: currentIndex - 1, autoStart: false)
                } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.title3)
                        .frame(width: 52, height: 52)
                        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(currentIndex == 0)
                .opacity(currentIndex == 0 ? 0.35 : 1)
            }

            Button {
                metronome.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: metronome.isRunning ? "pause.fill" : "play.fill")
                    Text(metronome.isRunning ? "暂停节拍器（展开设置）" : "开始专注训练")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(accentColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)

            if config.exercises.count > 1 {
                Button {
                    if currentIndex + 1 < config.exercises.count {
                        enterTransition(to: currentIndex + 1)
                    } else {
                        metronome.stop()
                        showCompletionSheet = true
                    }
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.title3)
                        .frame(width: 52, height: 52)
                        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }

    private func transitionOverlay(nextExercise: ExerciseItem, nextIndex: Int) -> some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 16) {
                ZStack {
                    Circle().fill(nextExercise.level.accentColor.opacity(0.18)).frame(width: 64, height: 64)
                    Image(systemName: nextExercise.level.symbolName).font(.title).foregroundStyle(nextExercise.level.accentColor)
                }
                VStack(spacing: 6) {
                    Text("下一项 · \(nextExercise.level.code) \(nextExercise.level.title)")
                        .font(.subheadline.bold())
                        .foregroundStyle(nextExercise.level.accentColor)
                    Text(nextExercise.name).font(.title3.bold())
                    Text(nextExercise.transitionPrompt)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                Text("\(transitionCountdown) 秒后自动开始")
                    .font(.caption.bold().monospacedDigit())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.08), in: Capsule())

                Button {
                    beginPendingExercise(at: nextIndex)
                } label: {
                    Text("已就位，立即开始")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(nextExercise.level.accentColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(22)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .padding(.horizontal, 24)
        }
    }

    private var completionSheet: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill").font(.system(size: 46)).foregroundStyle(.green)
                        Text("训练完成！").font(.title2.bold())
                        Text("本次专注练习 \(max(1, elapsedTotalSeconds / 60)) 分钟")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }

                Section("提速自检（+5 BPM 标准）") {
                    Toggle("连续弹奏 2 分钟以上零失误", isOn: $zeroMistakesTwoMinutes)
                    Toggle("手背与前臂完全没有酸胀感", isOn: $noForearmTension)
                    if zeroMistakesTwoMinutes && noForearmTension {
                        if !appliedSpeedUp {
                            Button("一键将本次练习目标 +5 BPM") {
                                store.speedUp(exercises: config.exercises, by: 5)
                                appliedSpeedUp = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                        } else {
                            Label("已提速 +5 BPM", systemImage: "checkmark.circle.fill")
                                .font(.caption.bold())
                                .foregroundStyle(.green)
                        }
                    }
                }

                Section {
                    Button {
                        let record = PracticeRecord(
                            title: config.title,
                            durationSeconds: max(elapsedTotalSeconds, 60),
                            badgeText: "\(metronome.bpm) BPM",
                            isTest: false,
                            qualifiesForSpeedUp: zeroMistakesTwoMinutes && noForearmTension
                        )
                        store.addRecord(record)
                        showCompletionSheet = false
                    } label: {
                        Text("保存今日打卡")
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

    private func loadExercise(at index: Int, autoStart: Bool) {
        currentIndex = index
        let ex = config.exercises[index]
        remainingSeconds = ex.durationSeconds
        syncMetronomePreferences()
        metronome.bpm = store.bpm(for: ex)
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

    private func beginPendingExercise(at nextIndex: Int) {
        pendingNextIndex = nil
        loadExercise(at: nextIndex, autoStart: true)
    }

    private func handleExerciseCompleted() {
        completedIds.insert(currentExercise.id)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        if currentIndex + 1 < config.exercises.count {
            enterTransition(to: currentIndex + 1)
        } else {
            metronome.stop()
            showCompletionSheet = true
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
