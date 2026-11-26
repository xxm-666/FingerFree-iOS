import SwiftUI

struct ProgressAndGuideView: View {
    @EnvironmentObject private var store: PracticeStore
    @State private var selectedSection: ProfileSection = .radar
    @State private var isHistoryExpanded: Bool = false
    @State private var retestLevel: TrainingLevel?

    private enum ProfileSection: String, CaseIterable, Identifiable {
        case radar = "能力雷达"
        case settings = "偏好与原则"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statsBentoRow

                    Picker("视图切换", selection: $selectedSection) {
                        ForEach(ProfileSection.allCases) { sec in
                            Text(sec.rawValue).tag(sec)
                        }
                    }
                    .pickerStyle(.segmented)

                    if selectedSection == .radar {
                        radarCard
                        masteryGrid
                        collapsibleHistoryCard
                    } else {
                        preferencesCard
                        principlesListCard
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("能力画像")
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(item: $retestLevel) { lv in
                LevelTestView(level: lv)
                    .environmentObject(store)
            }
        }
    }

    // MARK: - Top Bento Stats

    private var statsBentoRow: some View {
        HStack(spacing: 10) {
            statTile(value: "\(store.overallMasteryPercent)%", title: "综合熟练度", color: .cyan)
            statTile(value: "\(store.currentStreakDays)天", title: "连续打卡", color: .orange)
            statTile(value: "\(store.totalPracticeMinutes)分", title: "累计时长", color: .green)
        }
    }

    private func statTile(value: String, title: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(color)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - 5-Axis Skill Radar Chart

    private var radarCard: some View {
        let values = TrainingLevel.allCases.map { Double(store.mastery(for: $0).bestScore) / 100.0 }
        let labels = TrainingLevel.allCases.map { $0.title }

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("五维左手独立性雷达")
                    .font(.subheadline.bold())
                Spacer()
                Text("基于各阶段考核实时更新")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            SkillRadarView(values: values, labels: labels)
                .frame(height: 215)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Per-Level Mastery Compact Grid

    private var masteryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(TrainingLevel.allCases) { level in
                let m = store.mastery(for: level)
                Button {
                    retestLevel = level
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("\(level.code) \(level.title)")
                                .font(.caption.bold())
                                .foregroundStyle(level.accentColor)
                            Spacer()
                            Text(m.bestRank.rawValue)
                                .font(.caption.bold())
                                .foregroundStyle(.primary)
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.primary.opacity(0.1))
                                Capsule()
                                    .fill(level.accentColor)
                                    .frame(width: max(4, geo.size.width * CGFloat(m.bestScore) / 100.0))
                            }
                        }
                        .frame(height: 6)

                        Text(m.bestScore > 0 ? "熟练度 \(m.bestScore)% · 点击复测" : "未考核 · 点击测试")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Collapsible Training & Test History (Collapsed by Default)

    private var collapsibleHistoryCard: some View {
        DisclosureGroup(isExpanded: $isHistoryExpanded) {
            VStack(spacing: 10) {
                if store.records.isEmpty {
                    Text("还没有训练或考核记录，去完成今天第一个练习吧！")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                } else {
                    ForEach(store.records.prefix(20)) { record in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(record.title)
                                    .font(.caption.weight(.semibold))
                                Text("\(record.date.formatted(date: .abbreviated, time: .shortened)) · \(max(1, record.durationSeconds / 60)) 分钟")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(record.badgeText)
                                .font(.caption2.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    (record.isTest ? Color.purple : Color.blue).opacity(0.14),
                                    in: Capsule()
                                )
                                .foregroundStyle(record.isTest ? .purple : .blue)
                        }
                        .padding(.top, 6)
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.blue)
                Text("训练与考核记录")
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

    // MARK: - Preferences & Principles

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

            preferenceRow(title: "Lv.5 F 和弦指法") {
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
            Text(title).font(.subheadline)
            Spacer()
            control()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var principlesListCard: some View {
        VStack(spacing: 10) {
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
    }
}

// MARK: - Native SwiftUI 5-Axis Radar Chart
private struct SkillRadarView: View {
    let values: [Double] // 5 values in 0...1
    let labels: [String]

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2 + 4)
            let radius = min(geo.size.width, geo.size.height) * 0.34
            let count = max(values.count, 5)

            ZStack {
                // Concentric pentagon grids
                ForEach([0.33, 0.66, 1.0], id: \.self) { scale in
                    polygonPath(center: center, radius: radius * scale, values: Array(repeating: 1.0, count: count))
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                }

                // Spokes
                ForEach(0..<count, id: \.self) { i in
                    Path { p in
                        p.move(to: center)
                        p.addLine(to: point(center: center, radius: radius, index: i, total: count))
                    }
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                }

                // Filled data polygon
                let safeValues = values.map { max(0.10, min(1.0, $0)) }
                polygonPath(center: center, radius: radius, values: safeValues)
                    .fill(Color.cyan.opacity(0.28))
                polygonPath(center: center, radius: radius, values: safeValues)
                    .stroke(Color.cyan, lineWidth: 2)

                // Vertex dots & axis labels
                ForEach(0..<count, id: \.self) { i in
                    let dotPt = point(center: center, radius: radius * safeValues[i], index: i, total: count)
                    Circle()
                        .fill(Color.cyan)
                        .frame(width: 7, height: 7)
                        .position(dotPt)

                    let labelPt = point(center: center, radius: radius + 24, index: i, total: count)
                    Text(labels[i])
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .position(labelPt)
                }
            }
        }
    }

    private func point(center: CGPoint, radius: CGFloat, index: Int, total: Int) -> CGPoint {
        let angle = (-Double.pi / 2.0) + (Double(index) * 2.0 * Double.pi / Double(total))
        return CGPoint(
            x: center.x + CGFloat(cos(angle)) * radius,
            y: center.y + CGFloat(sin(angle)) * radius
        )
    }

    private func polygonPath(center: CGPoint, radius: CGFloat, values: [Double]) -> Path {
        Path { path in
            for i in 0..<values.count {
                let pt = point(center: center, radius: radius * values[i], index: i, total: values.count)
                if i == 0 {
                    path.move(to: pt)
                } else {
                    path.addLine(to: pt)
                }
            }
            path.closeSubpath()
        }
    }
}
