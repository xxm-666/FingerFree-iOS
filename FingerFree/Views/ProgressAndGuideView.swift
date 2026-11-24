import SwiftUI

struct ProgressAndGuideView: View {
    @EnvironmentObject private var store: PracticeStore
    @State private var selectedSection: DashboardTab = .settings
    @State private var isHistoryExpanded: Bool = false

    private enum DashboardTab: String, CaseIterable, Identifiable {
        case settings = "速度与偏好"
        case principles = "进阶原则"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statsBentoRow

                    Picker("视图切换", selection: $selectedSection) {
                        ForEach(DashboardTab.allCases) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)

                    if selectedSection == .settings {
                        bpmGridCard
                        preferencesCard
                        collapsibleHistoryCard
                    } else {
                        principlesListCard
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("进度与设置")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Top Bento Stats

    private var statsBentoRow: some View {
        HStack(spacing: 10) {
            statTile(value: "\(store.currentStreakDays)", unit: "天", title: "连续打卡", color: .orange)
            statTile(value: "\(store.records.count)", unit: "次", title: "累计训练", color: .blue)
            statTile(value: "\(store.totalPracticeMinutes)", unit: "分", title: "累计时长", color: .green)
        }
    }

    private func statTile(value: String, unit: String, title: String, color: Color) -> some View {
        VStack(spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title2.bold().monospacedDigit())
                    .foregroundStyle(color)
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - 2x2 BPM Grid

    private var bpmGridCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("各阶段目标速度")
                    .font(.subheadline.bold())
                Spacer()
                Text("稳定 2 分钟无酸胀再 +5")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(TrainingStageKind.allCases) { stage in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("0\(stage.index) \(stage.phaseTitle)")
                                .font(.caption.bold())
                                .foregroundStyle(stage.accentColor)
                            Spacer()
                            Text("\(store.bpm(for: stage))")
                                .font(.headline.bold().monospacedDigit())
                        }

                        HStack(spacing: 8) {
                            miniStepButton(label: "-5") {
                                store.setBPM(store.bpm(for: stage) - 5, for: stage)
                            }
                            miniStepButton(label: "+5") {
                                store.setBPM(store.bpm(for: stage) + 5, for: stage)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }

    private func miniStepButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption.bold().monospacedDigit())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Compact Preferences Card

    private var preferencesCard: some View {
        VStack(spacing: 0) {
            preferenceRow(title: "节拍器音色") {
                Picker("节拍器音色", selection: $store.metronomeSound) {
                    ForEach(MetronomeSound.allCases) { timbre in
                        Text(timbre.displayName).tag(timbre)
                    }
                }
                .labelsHidden()
            }
            Divider().padding(.leading, 14)

            preferenceRow(title: "第 2 阶段爬格子") {
                Picker("爬格子指型", selection: $store.spiderPattern) {
                    ForEach(SpiderPattern.allCases) { pattern in
                        Text(pattern.rawValue).tag(pattern)
                    }
                }
                .labelsHidden()
            }
            Divider().padding(.leading, 14)

            preferenceRow(title: "第 4 阶段 F 和弦") {
                Picker("F 和弦指法", selection: $store.fChordStyle) {
                    ForEach(FChordStyle.allCases) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .labelsHidden()
            }
            Divider().padding(.leading, 14)

            Toggle("开始前 4 拍预备拍", isOn: $store.countInEnabled)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            Divider().padding(.leading, 14)

            Toggle("节拍器触觉反馈 (震动)", isOn: $store.hapticsEnabled)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func preferenceRow<Control: View>(title: String, @ViewBuilder control: () -> Control) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            control()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Collapsible Training History (Collapsed by Default)

    private var collapsibleHistoryCard: some View {
        DisclosureGroup(isExpanded: $isHistoryExpanded) {
            VStack(spacing: 10) {
                if store.records.isEmpty {
                    Text("还没有打卡记录，去完成今天第一个 10 分钟吧！")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                } else {
                    ForEach(store.records.prefix(15)) { record in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(record.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption.weight(.semibold))
                                Text("完成 \(record.completedStages.count) 个阶段 · \(max(1, record.durationSeconds / 60)) 分钟")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if record.qualifiesForSpeedUp {
                                Text("可提速 +5")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.green.opacity(0.16), in: Capsule())
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding(.top, 6)
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.blue)
                Text("训练打卡记录")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                Spacer()
                Text("共 \(store.records.count) 次")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Principles Tab

    private var principlesListCard: some View {
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
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }
}
