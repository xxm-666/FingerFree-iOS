import SwiftUI

struct TodayPlanView: View {
    @EnvironmentObject private var store: PracticeStore

    private enum TrainingTrack: String, CaseIterable, Identifiable {
        case main = "指法主线 (Lv.1–5)"
        case chords = "和弦实战 (6项)"
        var id: String { rawValue }
    }

    private struct TestLaunchConfig: Identifiable {
        let id = UUID()
        let level: TrainingLevel
        let customExercise: ExerciseItem?
    }

    private struct LockedPromptItem {
        let level: TrainingLevel
        let exercise: ExerciseItem?
        let message: String
    }

    @State private var selectedTrack: TrainingTrack = .main
    @State private var selectedMainLevel: TrainingLevel = .lv1
    @State private var activeSession: PracticeSessionConfig?
    @State private var activeTest: TestLaunchConfig?
    @State private var lockedPrompt: LockedPromptItem?
    @State private var showPrinciplesSheet: Bool = false

    private var currentLevel: TrainingLevel {
        selectedTrack == .main ? selectedMainLevel : .chords
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    dailyRecommendationCard

                    Picker("训练模式", selection: $selectedTrack) {
                        ForEach(TrainingTrack.allCases) { track in
                            Text(track.rawValue).tag(track)
                        }
                    }
                    .pickerStyle(.segmented)

                    if selectedTrack == .main {
                        levelStepperRow
                    }

                    selectedLevelBanner
                    exercisesListSection
                    stageTestCTACard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("指律 · 进阶路径")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showPrinciplesSheet = true
                    } label: {
                        Label("原则", systemImage: "book.closed.fill")
                            .font(.subheadline.weight(.medium))
                    }
                }
            }
            .fullScreenCover(item: $activeSession) { config in
                PracticeSessionView(config: config)
                    .environmentObject(store)
            }
            .fullScreenCover(item: $activeTest) { cfg in
                LevelTestView(level: cfg.level, customExercise: cfg.customExercise)
                    .environmentObject(store)
            }
            .alert(
                "尚未解锁",
                isPresented: Binding(
                    get: { lockedPrompt != nil },
                    set: { if !$0 { lockedPrompt = nil } }
                ),
                presenting: lockedPrompt
            ) { item in
                Button(item.exercise != nil ? "跳级考核本套和弦" : "直接跳级考核") {
                    lockedPrompt = nil
                    activeTest = TestLaunchConfig(level: item.level, customExercise: item.exercise)
                }
                Button("知道了", role: .cancel) {
                    lockedPrompt = nil
                }
            } message: { item in
                Text(item.message)
            }
            .sheet(isPresented: $showPrinciplesSheet) {
                principlesSheet
                    .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Daily Recommendation Card

    private var dailyRecommendationCard: some View {
        let rec = store.dailyRecommendation
        return Button {
            if rec.level.isMainTrack {
                selectedTrack = .main
                selectedMainLevel = rec.level
            } else {
                selectedTrack = .chords
            }
            if rec.shouldTakeTest {
                activeTest = TestLaunchConfig(
                    level: rec.level,
                    customExercise: rec.level == .chords ? store.nextChordTestExercise : nil
                )
            } else {
                activeSession = .single(rec.exercise)
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(rec.level.accentColor.opacity(0.16))
                        .frame(width: 40, height: 40)
                    Image(systemName: rec.shouldTakeTest ? "trophy.fill" : "sparkles")
                        .font(.subheadline.bold())
                        .foregroundStyle(rec.level.accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("今日推荐")
                            .font(.caption2.bold())
                            .foregroundStyle(rec.level.accentColor)
                        if store.practicedToday {
                            Text("今日已打卡 ✓")
                                .font(.caption2.bold())
                                .foregroundStyle(.green)
                        }
                    }
                    Text(rec.headline)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(rec.subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Text(rec.shouldTakeTest ? "去考核" : "去练")
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(rec.level.accentColor, in: Capsule())
                    .foregroundStyle(.white)
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(rec.level.accentColor.opacity(0.28), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Horizontal 5-Level Main Track Stepper (Lv.1 -> Lv.5 征服指板)

    private var levelStepperRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(TrainingLevel.mainTrackLevels) { level in
                    let isSelected = (level == selectedMainLevel)
                    let unlocked = store.isUnlocked(level)
                    let m = store.mastery(for: level)

                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            selectedMainLevel = level
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(level.code)
                                    .font(.caption2.bold())
                                Spacer()
                                if !unlocked {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 10, weight: .bold))
                                } else {
                                    Text("\(m.bestScore)%")
                                        .font(.caption2.bold().monospacedDigit())
                                }
                            }
                            .opacity(isSelected ? 0.95 : 0.72)

                            Text(level.title)
                                .font(.caption.bold())
                                .lineLimit(1)

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(isSelected ? Color.white.opacity(0.28) : Color.primary.opacity(0.1))
                                    Capsule()
                                        .fill(isSelected ? Color.white : (unlocked ? level.accentColor : Color.secondary))
                                        .frame(width: max(4, geo.size.width * CGFloat(m.bestScore) / 100.0))
                                }
                            }
                            .frame(height: 4)
                        }
                        .padding(11)
                        .frame(width: 96)
                        .background(
                            isSelected ? level.accentColor : Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                        .foregroundStyle(isSelected ? .white : .primary)
                        .opacity(unlocked || isSelected ? 1.0 : 0.68)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(isSelected ? level.accentColor : Color.primary.opacity(0.06), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Selected Level Banner

    private var selectedLevelBanner: some View {
        let level = currentLevel
        let unlocked = store.isUnlocked(level)
        let m = store.mastery(for: level)
        let playableExercises = store.unlockedExercises(for: level)
        let totalMins = playableExercises.reduce(0) { $0 + $1.durationMinutes }

        let masteryLabel: String = {
            if !unlocked { return "🔒 未解锁" }
            if level == .chords {
                return "已解锁 \(playableExercises.count)/\(level.exercises.count) 套"
            }
            if m.bestScore == 0 { return "尚未考核" }
            if m.lastScore != m.bestScore {
                return "最高 \(m.bestScore)% · 最近 \(m.lastScore)%"
            }
            return "熟练度 \(m.bestScore)% (\(m.bestRank.rawValue))"
        }()

        return VStack(alignment: .leading, spacing: 11) {
            HStack {
                Label("\(level.code) · \(level.difficultyLabel)", systemImage: level.symbolName)
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.2), in: Capsule())

                Spacer()

                Text(masteryLabel)
                    .font(.caption.bold().monospacedDigit())
            }

            Text(level.isMainTrack ? "\(level.title)阶段" : "和弦实战专项区")
                .font(.title3.bold())

            Text(level.summary)
                .font(.caption)
                .opacity(0.92)
                .lineSpacing(3)

            if unlocked && !playableExercises.isEmpty {
                Button {
                    activeSession = PracticeSessionConfig(
                        exercises: playableExercises,
                        title: level.isMainTrack
                            ? "\(level.code) \(level.title) · 全套连练"
                            : "和弦实战 · 已解锁连练"
                    )
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.caption)
                        Text(level.isMainTrack
                             ? "一键连练本阶段全部练习"
                             : "一键连练已解锁和弦 (\(playableExercises.count)/\(level.exercises.count))")
                            .font(.subheadline.bold())
                        Spacer()
                        Text("\(playableExercises.count) 项 · \(totalMins) 分钟")
                            .font(.caption2.bold().monospacedDigit())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.22), in: Capsule())
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(.white.opacity(0.22), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    if let reason = store.lockReason(for: level) {
                        Label(reason, systemImage: "lock.fill")
                            .font(.caption2.weight(.medium))
                            .opacity(0.92)
                    }

                    Button {
                        activeTest = TestLaunchConfig(
                            level: level,
                            customExercise: level == .chords ? level.exercises.first : nil
                        )
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.open.fill")
                                .font(.caption)
                            Text("我有基础 · 直接跳级考核（达 B 级即解锁）")
                                .font(.subheadline.bold())
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 2)
            }
        }
        .foregroundStyle(.white)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    unlocked ? level.accentColor : Color(.systemGray),
                    Color(red: 0.13, green: 0.16, blue: 0.28)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .shadow(color: (unlocked ? level.accentColor : .black).opacity(0.20), radius: 10, y: 5)
    }

    // MARK: - Detailed Sub-Exercises for Selected Level

    private var exercisesListSection: some View {
        let level = currentLevel
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(level.isMainTrack
                     ? "本阶段详细练习 (\(level.exercises.count) 项)"
                     : "渐进和弦实战课程 (逐套考核达 B 级依次解锁)")
                    .font(.subheadline.bold())
                Spacer()
                Text(level.isMainTrack ? (store.isUnlocked(level) ? "点击专注训练" : "预览模式") : "由易到难")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(level.exercises.enumerated()), id: \.element.id) { idx, exercise in
                let exUnlocked = store.isExerciseUnlocked(exercise)
                let chordScore = level == .chords ? store.chordDrillBestScore(for: exercise) : 0

                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        if exUnlocked {
                            activeSession = .single(exercise)
                        } else {
                            lockedPrompt = LockedPromptItem(
                                level: level,
                                exercise: level == .chords ? exercise : nil,
                                message: store.exerciseLockReason(for: exercise) ?? "完成前置考核达 B 级（65%）解锁。"
                            )
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text(exercise.badge)
                                            .font(.caption2.bold())
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background((exUnlocked ? level.accentColor : Color.secondary).opacity(0.16), in: Capsule())
                                            .foregroundStyle(exUnlocked ? level.accentColor : .secondary)
                                        Text("\(exercise.durationMinutes) 分钟 · \(store.bpm(for: exercise)) BPM")
                                            .font(.caption2.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                        if level == .chords && chordScore > 0 {
                                            Text("\(chordScore)%")
                                                .font(.caption2.bold().monospacedDigit())
                                                .foregroundStyle(chordScore >= PracticeStore.unlockScoreThreshold ? .green : .orange)
                                        }
                                    }
                                    Text("\(idx + 1). \(exercise.name)")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(exUnlocked ? .primary : .secondary)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer()
                                Image(systemName: exUnlocked ? "play.circle.fill" : "lock.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(exUnlocked ? level.accentColor : .secondary.opacity(0.6))
                            }

                            Text(exercise.steps.first ?? exercise.tip)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .buttonStyle(.plain)

                    // For Chord Lab: give each unlocked drill a direct mini test button to unlock the next chord tier
                    if level == .chords && exUnlocked {
                        HStack {
                            Text(chordScore >= PracticeStore.unlockScoreThreshold
                                 ? "已通过 B 级考核（最高 \(chordScore)%）"
                                 : (idx + 1 < level.exercises.count ? "考核达 B 级 (65%) 解锁下一套和弦" : "考核验收大师级和弦掌控"))
                                .font(.caption2)
                                .foregroundStyle(chordScore >= PracticeStore.unlockScoreThreshold ? .green : .secondary)
                            Spacer()
                            Button {
                                activeTest = TestLaunchConfig(level: .chords, customExercise: exercise)
                            } label: {
                                Label(chordScore > 0 ? "复测" : "考核本套", systemImage: "mic.fill")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(level.accentColor.opacity(0.14), in: Capsule())
                                    .foregroundStyle(level.accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .opacity(exUnlocked ? 1.0 : 0.78)
            }
        }
    }

    // MARK: - Stage Proficiency Test CTA

    private var stageTestCTACard: some View {
        let level = currentLevel
        let unlocked = store.isUnlocked(level)
        let spec = level.testSpec
        let targetChordDrill: ExerciseItem? = (level == .chords) ? store.nextChordTestExercise : nil

        return Button {
            activeTest = TestLaunchConfig(level: level, customExercise: targetChordDrill)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(level.accentColor.opacity(0.16))
                        .frame(width: 46, height: 46)
                    Image(systemName: unlocked ? (spec.usesAudioAnalysis ? "mic.badge.plus" : "trophy.fill") : "lock.open.fill")
                        .font(.title3)
                        .foregroundStyle(level.accentColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(unlocked
                         ? (spec.usesAudioAnalysis ? "实时麦克风音频考核" : "阶段熟练度考核（免麦克风）")
                         : "跳级考核通道（达 B 级 65% 即刻解锁）")
                        .font(.caption.bold())
                        .foregroundStyle(unlocked ? level.accentColor : .orange)
                    Text(targetChordDrill != nil ? "和弦考核 · \(targetChordDrill!.name)" : spec.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(unlocked
                         ? (level == .chords ? "完成当前套和弦考核达 B 级解锁下一套" : "测出你在 \(level.code) 的熟练度百分比，达 B 级解锁下一阶段")
                         : "有基础的琴友可直接参加本阶段考核解锁")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(unlocked ? "去测试" : "跳级考")
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(unlocked ? level.accentColor : Color.orange, in: Capsule())
                    .foregroundStyle(.white)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder((unlocked ? level.accentColor : Color.orange).opacity(0.45), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var principlesSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(PracticePrinciple.all) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Label(item.title, systemImage: item.icon)
                                .font(.subheadline.bold())
                                .foregroundStyle(item.color)
                            Text(item.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineSpacing(4)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("进阶与执行细节")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { showPrinciplesSheet = false }
                }
            }
        }
    }
}
