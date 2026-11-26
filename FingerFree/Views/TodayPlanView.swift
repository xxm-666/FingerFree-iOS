import SwiftUI

struct TodayPlanView: View {
    @EnvironmentObject private var store: PracticeStore
    @State private var selectedLevel: TrainingLevel = .lv1
    @State private var activeSession: PracticeSessionConfig?
    @State private var activeTestLevel: TrainingLevel?
    @State private var showPrinciplesSheet: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    dailyRecommendationCard
                    levelStepperRow
                    selectedLevelBanner
                    if let warning = store.prerequisiteWarning(for: selectedLevel) {
                        prerequisiteWarningBanner(text: warning)
                    }
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
            .fullScreenCover(item: $activeTestLevel) { level in
                LevelTestView(level: level)
                    .environmentObject(store)
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
            selectedLevel = rec.level
            if rec.shouldTakeTest {
                activeTestLevel = rec.level
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

    private func prerequisiteWarningBanner(text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
                .padding(.top, 1)
            Text(text)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineSpacing(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Horizontal 6-Level Stepper (Easy -> Hard)

    private var levelStepperRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(TrainingLevel.allCases) { level in
                    let isSelected = (level == selectedLevel)
                    let m = store.mastery(for: level)

                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            selectedLevel = level
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(level.code)
                                    .font(.caption2.bold())
                                Spacer()
                                Text("\(m.bestScore)%")
                                    .font(.caption2.bold().monospacedDigit())
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
                                        .fill(isSelected ? Color.white : level.accentColor)
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
        let m = store.mastery(for: selectedLevel)
        let totalMins = selectedLevel.exercises.reduce(0) { $0 + $1.durationMinutes }
        let masteryLabel: String = {
            if m.bestScore == 0 { return "尚未考核" }
            if m.lastScore != m.bestScore {
                return "最高 \(m.bestScore)% · 最近 \(m.lastScore)%"
            }
            return "熟练度 \(m.bestScore)% (\(m.bestRank.rawValue))"
        }()
        return VStack(alignment: .leading, spacing: 11) {
            HStack {
                Label("\(selectedLevel.code) · \(selectedLevel.difficultyLabel)", systemImage: selectedLevel.symbolName)
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.2), in: Capsule())

                Spacer()

                Text(masteryLabel)
                    .font(.caption.bold().monospacedDigit())
            }

            Text("\(selectedLevel.title)阶段")
                .font(.title3.bold())

            Text(selectedLevel.summary)
                .font(.caption)
                .opacity(0.92)
                .lineSpacing(3)

            Button {
                activeSession = .fullLevel(selectedLevel)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.caption)
                    Text("一键连练本阶段全部练习")
                        .font(.subheadline.bold())
                    Spacer()
                    Text("\(selectedLevel.exercises.count) 项 · \(totalMins) 分钟")
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
        }
        .foregroundStyle(.white)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [selectedLevel.accentColor, Color(red: 0.13, green: 0.16, blue: 0.28)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .shadow(color: selectedLevel.accentColor.opacity(0.22), radius: 10, y: 5)
    }

    // MARK: - Detailed Sub-Exercises for Selected Level

    private var exercisesListSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("本阶段详细练习 (\(selectedLevel.exercises.count) 项)")
                    .font(.subheadline.bold())
                Spacer()
                Text("点击进入专注训练")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(selectedLevel.exercises.enumerated()), id: \.element.id) { idx, exercise in
                Button {
                    activeSession = .single(exercise)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(exercise.badge)
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(selectedLevel.accentColor.opacity(0.16), in: Capsule())
                                        .foregroundStyle(selectedLevel.accentColor)
                                    Text("\(exercise.durationMinutes) 分钟 · \(store.bpm(for: exercise)) BPM")
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                Text("\(idx + 1). \(exercise.name)")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)
                            }
                            Spacer()
                            Image(systemName: "play.circle.fill")
                                .font(.title2)
                                .foregroundStyle(selectedLevel.accentColor)
                        }

                        Text(exercise.steps.first ?? exercise.tip)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Stage Proficiency Test CTA

    private var stageTestCTACard: some View {
        let spec = selectedLevel.testSpec
        return Button {
            activeTestLevel = selectedLevel
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(selectedLevel.accentColor.opacity(0.16))
                        .frame(width: 46, height: 46)
                    Image(systemName: spec.usesAudioAnalysis ? "mic.badge.plus" : "trophy.fill")
                        .font(.title3)
                        .foregroundStyle(selectedLevel.accentColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(spec.usesAudioAnalysis ? "实时麦克风音频考核" : "阶段熟练度考核（免麦克风）")
                        .font(.caption.bold())
                        .foregroundStyle(selectedLevel.accentColor)
                    Text(spec.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text("测出你在 \(selectedLevel.code) 的熟练度百分比与 S/A/B/C 评级")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("去测试")
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(selectedLevel.accentColor, in: Capsule())
                    .foregroundStyle(.white)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(selectedLevel.accentColor.opacity(0.45), lineWidth: 1.5)
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
