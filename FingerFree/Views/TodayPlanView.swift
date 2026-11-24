import SwiftUI

struct TodayPlanView: View {
    @EnvironmentObject private var store: PracticeStore
    @State private var activeSession: PracticeSessionConfig?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    heroCard
                    goldenWindowBanner
                    stagesSection
                    principlesPreviewSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("指律 · 每日 10 分钟")
            .fullScreenCover(item: $activeSession) { config in
                PracticeSessionView(config: config)
                    .environmentObject(store)
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("左手独立性专项训练", systemImage: "hand.raised.fingers.spread.fill")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.18), in: Capsule())

                Spacer()

                if store.practicedToday {
                    Label("今日已打卡", systemImage: "checkmark.circle.fill")
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.green.opacity(0.28), in: Capsule())
                } else {
                    Text("连续 \(store.currentStreakDays) 天")
                        .font(.caption.weight(.semibold))
                        .opacity(0.9)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("打破中指与无名指联动")
                    .font(.title2.bold())
                Text("4 个渐进阶段 · 全程 4/4 节拍器引导 · 紧绷一键 -10 BPM")
                    .font(.subheadline)
                    .opacity(0.88)
            }

            Button {
                activeSession = .fullTenMinutePlan
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("开始今日 10 分钟完整训练")
                        .font(.headline)
                    Spacer()
                    Text("10 MIN")
                        .font(.caption.bold().monospacedDigit())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.2), in: Capsule())
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(.white.opacity(0.22), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.14, green: 0.19, blue: 0.36),
                    Color(red: 0.32, green: 0.22, blue: 0.38),
                    Color(red: 0.72, green: 0.35, blue: 0.22)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .shadow(color: .black.opacity(0.14), radius: 14, y: 8)
    }

    private var goldenWindowBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "sunrise.fill")
                .font(.title3)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("黄金练习时段建议")
                    .font(.subheadline.bold())
                Text("放在每天练琴最开始作为 10 分钟热身，肌肉最放松、神经通路建立效率最高。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var stagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("训练阶段")
                    .font(.headline)
                Spacer()
                Text("点击任意阶段单独练习")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(TrainingStageKind.allCases) { stage in
                Button {
                    activeSession = .single(stage)
                } label: {
                    stageRow(stage)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func stageRow(_ stage: TrainingStageKind) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(stage.accentColor.opacity(0.16))
                        .frame(width: 46, height: 46)
                    Image(systemName: stage.symbolName)
                        .font(.title3)
                        .foregroundStyle(stage.accentColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("\(stage.index). \(stage.phaseTitle)")
                            .font(.caption.bold())
                            .foregroundStyle(stage.accentColor)
                        Text("· \(stage.durationMinutes) 分钟")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(stage.exerciseName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(store.bpm(for: stage))")
                        .font(.title3.bold().monospacedDigit())
                        .foregroundStyle(.primary)
                    Text("BPM")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            Text(stage.coreRequirement)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var principlesPreviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("核心执行细节")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(PracticePrinciple.all) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        Image(systemName: item.icon)
                            .font(.headline)
                            .foregroundStyle(item.color)
                        Text(item.title)
                            .font(.subheadline.bold())
                        Text(item.subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
    }
}
