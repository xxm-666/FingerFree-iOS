import SwiftUI

struct ProgressAndGuideView: View {
    @EnvironmentObject private var store: PracticeStore

    var body: some View {
        NavigationStack {
            List {
                Section("训练统计") {
                    HStack(spacing: 12) {
                        statTile(value: "\(store.currentStreakDays)", unit: "天", title: "连续打卡", color: .orange)
                        statTile(value: "\(store.records.count)", unit: "次", title: "累计训练", color: .blue)
                        statTile(value: "\(store.totalPracticeMinutes)", unit: "分", title: "累计时长", color: .green)
                    }
                    .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
                }

                Section {
                    ForEach(TrainingStageKind.allCases) { stage in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(stage.index). \(stage.phaseTitle)")
                                    .font(.subheadline.bold())
                                Text(stage.recommendedBPMText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Stepper(
                                value: Binding(
                                    get: { store.bpm(for: stage) },
                                    set: { store.setBPM($0, for: stage) }
                                ),
                                in: 30...160,
                                step: 5
                            ) {
                                Text("\(store.bpm(for: stage)) BPM")
                                    .font(.subheadline.bold().monospacedDigit())
                                    .foregroundStyle(stage.accentColor)
                            }
                            .fixedSize()
                        }
                    }
                } header: {
                    Text("各阶段当前目标速度")
                } footer: {
                    Text("每周提速标准：连续弹奏 2 分钟零失误且前臂完全无酸胀感后，再统一 +5 BPM。")
                }

                Section("训练偏好") {
                    Picker("第 4 阶段 F 和弦指法", selection: $store.fChordStyle) {
                        ForEach(FChordStyle.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    Toggle("节拍器触觉反馈 (震动)", isOn: $store.hapticsEnabled)
                }

                Section("进阶原则详解") {
                    ForEach(PracticePrinciple.all) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Label(item.title, systemImage: item.icon)
                                .font(.subheadline.bold())
                                .foregroundStyle(item.color)
                            Text(item.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("最近打卡记录") {
                    if store.records.isEmpty {
                        Text("还没有打卡记录，去完成今天第一个 10 分钟吧！")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.records.prefix(15)) { record in
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(record.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.subheadline.weight(.medium))
                                    Text("完成 \(record.completedStages.count) 个阶段 · \(max(1, record.durationSeconds / 60)) 分钟")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if record.qualifiesForSpeedUp {
                                    Text("可提速 +5")
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.green.opacity(0.16), in: Capsule())
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("进度与原则")
        }
    }

    private func statTile(value: String, unit: String, title: String, color: Color) -> some View {
        VStack(spacing: 4) {
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
        .padding(.vertical, 10)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
