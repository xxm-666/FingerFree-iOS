import SwiftUI

struct TodayPlanView: View {
    @EnvironmentObject private var store: PracticeStore
    @State private var activeSession: PracticeSessionConfig?
    @State private var selectedStage: TrainingStageKind = .neuralWakeup
    @State private var showPrinciplesSheet: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                heroCard
                    .padding(.horizontal, 16)

                stageSelectorBar
                    .padding(.horizontal, 16)

                // Horizontal paged carousel instead of a long vertical list
                TabView(selection: $selectedStage) {
                    ForEach(TrainingStageKind.allCases) { stage in
                        stageCarouselCard(stage)
                            .padding(.horizontal, 16)
                            .tag(stage)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxHeight: .infinity)

                principlesCompactBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
            .padding(.top, 8)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("指律")
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
            .sheet(isPresented: $showPrinciplesSheet) {
                principlesSheet
                    .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("黄金热身 · 练琴前 10 分钟", systemImage: "sunrise.fill")
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
                        .background(Color.green.opacity(0.32), in: Capsule())
                } else {
                    Text("连续 \(store.currentStreakDays) 天")
                        .font(.caption.weight(.semibold))
                        .opacity(0.9)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("打破中指与无名指联动")
                    .font(.title3.bold())
                Text("4 阶段渐进训练 · \(store.metronomeSound.displayName)节拍器")
                    .font(.caption)
                    .opacity(0.86)
            }

            Button {
                activeSession = .fullTenMinutePlan
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("开始今日 10 分钟完整训练")
                        .font(.subheadline.bold())
                    Spacer()
                    Text("10 MIN")
                        .font(.caption2.bold().monospacedDigit())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.22), in: Capsule())
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(.white.opacity(0.22), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.white)
        .padding(18)
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
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
    }

    // MARK: - Stage Selector Pills

    private var stageSelectorBar: some View {
        HStack(spacing: 8) {
            ForEach(TrainingStageKind.allCases) { stage in
                let isSelected = (stage == selectedStage)
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        selectedStage = stage
                    }
                } label: {
                    VStack(spacing: 2) {
                        Text("0\(stage.index)")
                            .font(.caption2.bold().monospacedDigit())
                            .opacity(isSelected ? 0.9 : 0.6)
                        Text(stage.phaseTitle)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        isSelected ? stage.accentColor : Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .foregroundStyle(isSelected ? .white : .primary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Horizontal Stage Card

    private func stageCarouselCard(_ stage: TrainingStageKind) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(stage.accentColor.opacity(0.16))
                            .frame(width: 46, height: 46)
                        Image(systemName: stage.symbolName)
                            .font(.title3)
                            .foregroundStyle(stage.accentColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("阶段 \(stage.index) · \(stage.phaseTitle)")
                            .font(.caption.bold())
                            .foregroundStyle(stage.accentColor)
                        Text(stage.exerciseName)
                            .font(.headline)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(store.bpm(for: stage))")
                        .font(.title2.bold().monospacedDigit())
                        .foregroundStyle(stage.accentColor)
                    Text("BPM")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                Label("\(stage.durationMinutes) 分钟", systemImage: "timer")
                Text("·")
                Text(stage.recommendedBPMText)
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)

            Divider()

            Text(stage.coreRequirement)
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.88))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 4)

            HStack {
                Label("左右滑动切换阶段", systemImage: "hand.draw")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    activeSession = .single(stage)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.caption)
                        Text("单独练习本阶段")
                            .font(.subheadline.bold())
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(stage.accentColor, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(stage.accentColor.opacity(0.22), lineWidth: 1)
        )
    }

    // MARK: - Compact Bottom Bar & Sheet

    private var principlesCompactBar: some View {
        Button {
            showPrinciplesSheet = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "ruler.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 1) {
                    Text("一毫米原则 · 紧绷降速与提速标准")
                        .font(.caption.bold())
                        .foregroundStyle(.primary)
                    Text("点击查看全部核心动作细节")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
