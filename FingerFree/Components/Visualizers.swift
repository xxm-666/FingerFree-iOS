import SwiftUI

struct ExerciseVisualizerView: View {
    let exercise: ExerciseItem
    let currentBeat: Int
    let totalBeatCount: Int
    let isRunning: Bool
    let fChordStyle: FChordStyle

    private var accentColor: Color { exercise.level.accentColor }

    var body: some View {
        Group {
            switch exercise.visualizerKind {
            case .handTap:
                HandTapVisualizer(totalBeatCount: totalBeatCount, isRunning: isRunning, accentColor: accentColor)
            case .handStar:
                HandSpreadVisualizer(totalBeatCount: totalBeatCount, isRunning: isRunning, accentColor: accentColor, mode: .star)
            case .handVulcan:
                HandSpreadVisualizer(totalBeatCount: totalBeatCount, isRunning: isRunning, accentColor: accentColor, mode: .vulcan)
            case .handRoll:
                HandRollVisualizer(totalBeatCount: totalBeatCount, isRunning: isRunning, accentColor: accentColor)
            case .spider(let order, let frets):
                SpiderFretboardVisualizer(totalBeatCount: totalBeatCount, isRunning: isRunning, fingerOrder: order, frets: frets, accentColor: accentColor)
            case .isolation:
                IsolationFretboardVisualizer(currentBeat: currentBeat, isRunning: isRunning, accentColor: accentColor, ringPinkyMode: false)
            case .ringPinkyIsolation:
                IsolationFretboardVisualizer(currentBeat: currentBeat, isRunning: isRunning, accentColor: accentColor, ringPinkyMode: true)
            case .scissor:
                ScissorFretboardVisualizer(currentBeat: currentBeat, isRunning: isRunning, accentColor: accentColor)
            case .xStretch:
                XStretchFretboardVisualizer(currentBeat: currentBeat, isRunning: isRunning, accentColor: accentColor)
            case .trill:
                TrillFretboardVisualizer(currentBeat: currentBeat, isRunning: isRunning, accentColor: accentColor)
            case .chordsBasic:
                ChordTransitionVisualizer(currentBeat: currentBeat, totalBeatCount: totalBeatCount, isRunning: isRunning, fChordStyle: fChordStyle, mode: .basic, accentColor: accentColor)
            case .chordsExtended:
                ChordTransitionVisualizer(currentBeat: currentBeat, totalBeatCount: totalBeatCount, isRunning: isRunning, fChordStyle: fChordStyle, mode: .extended, accentColor: accentColor)
            case .chordsWideVoicing:
                ChordTransitionVisualizer(currentBeat: currentBeat, totalBeatCount: totalBeatCount, isRunning: isRunning, fChordStyle: fChordStyle, mode: .wideVoicing, accentColor: accentColor)
            case .chordsBarreShift:
                ChordTransitionVisualizer(currentBeat: currentBeat, totalBeatCount: totalBeatCount, isRunning: isRunning, fChordStyle: fChordStyle, mode: .barreShift, accentColor: accentColor)
            case .chordsAShapeBarre:
                ChordTransitionVisualizer(currentBeat: currentBeat, totalBeatCount: totalBeatCount, isRunning: isRunning, fChordStyle: fChordStyle, mode: .aShapeBarre, accentColor: accentColor)
            case .chordsJazz251:
                ChordTransitionVisualizer(currentBeat: currentBeat, totalBeatCount: totalBeatCount, isRunning: isRunning, fChordStyle: fChordStyle, mode: .jazz251, accentColor: accentColor)
            case .fretboardCruise(let order):
                FretboardCruiseVisualizer(totalBeatCount: totalBeatCount, isRunning: isRunning, order: order, accentColor: accentColor)
            case .fretboardDiagonal:
                FretboardDiagonalVisualizer(totalBeatCount: totalBeatCount, isRunning: isRunning, accentColor: accentColor)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Lv.1-1: 无琴桌面独立敲击
private struct HandTapVisualizer: View {
    let totalBeatCount: Int
    let isRunning: Bool
    let accentColor: Color

    private var activeFinger: Int {
        guard isRunning, totalBeatCount > 0 else { return 0 }
        return (totalBeatCount % 2 == 1) ? 2 : 3
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Label("桌面手势引导", systemImage: "hand.tap.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(activeFinger == 2 ? "单抬中指 (2)" : activeFinger == 3 ? "单抬无名指 (3)" : "食指与小指贴桌面")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(accentColor.opacity(0.16), in: Capsule())
                    .foregroundStyle(accentColor)
            }

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.14))
                    .frame(height: 6)
                    .padding(.horizontal, 8)
                    .offset(y: 4)

                HStack(alignment: .bottom, spacing: 14) {
                    fingerColumn(number: 1, name: "食指", height: 90, isLocked: true, isLifted: false)
                    fingerColumn(number: 2, name: "中指", height: 108, isLocked: false, isLifted: activeFinger == 2)
                    fingerColumn(number: 3, name: "无名指", height: 100, isLocked: false, isLifted: activeFinger == 3)
                    fingerColumn(number: 4, name: "小指", height: 78, isLocked: true, isLifted: false)
                }
                .padding(.bottom, 10)
                .animation(.spring(response: 0.22, dampingFraction: 0.68), value: activeFinger)
            }
            .frame(height: 156)
        }
    }

    private func fingerColumn(number: Int, name: String, height: CGFloat, isLocked: Bool, isLifted: Bool) -> some View {
        let fill: Color = isLocked ? Color.cyan.opacity(0.24) : (isLifted ? accentColor : Color.secondary.opacity(0.18))
        let border: Color = isLocked ? Color.cyan : (isLifted ? accentColor : Color.secondary.opacity(0.32))

        return VStack(spacing: 5) {
            if isLifted {
                Text("↑ 1-2cm").font(.caption2.bold()).foregroundStyle(accentColor)
            } else if isLocked {
                Image(systemName: "lock.fill").font(.caption2).foregroundStyle(.cyan)
            } else {
                Text("静止").font(.caption2).foregroundStyle(.secondary)
            }

            VStack(spacing: 3) {
                Text("\(number)").font(.headline.bold()).foregroundStyle(isLifted ? .white : .primary)
                Text(name).font(.caption2.weight(.medium)).foregroundStyle(isLifted ? .white.opacity(0.9) : .secondary)
            }
            .frame(width: 54, height: height)
            .background(fill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(border, lineWidth: isLifted || isLocked ? 2 : 1)
            )
            .offset(y: isLifted ? -18 : 0)
        }
    }
}

// MARK: - Lv.1-2 & 1-3: 开合星 & 瓦肯分组分裂
private struct HandSpreadVisualizer: View {
    enum Mode { case star, vulcan }

    let totalBeatCount: Int
    let isRunning: Bool
    let accentColor: Color
    let mode: Mode

    private var isOpen: Bool {
        guard isRunning, totalBeatCount > 0 else { return false }
        return totalBeatCount % 2 == 1
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Label(mode == .star ? "指尖开合星" : "瓦肯分组分裂", systemImage: "hand.raised.fingers.spread.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(isOpen ? (mode == .star ? "中指/无名指同步外张" : "分组横向张开") : "平稳收回并拢")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(accentColor.opacity(0.16), in: Capsule())
                    .foregroundStyle(accentColor)
            }

            HStack(alignment: .bottom, spacing: 10) {
                let offset1: CGFloat = (mode == .vulcan && isOpen) ? -14 : 0
                let offset2: CGFloat = isOpen ? (mode == .star ? -10 : -14) : 0
                let offset3: CGFloat = isOpen ? (mode == .star ? 10 : 14) : 0
                let offset4: CGFloat = (mode == .vulcan && isOpen) ? 14 : 0

                pillFinger(1, "食指", height: 92, locked: mode == .star, active: mode == .vulcan && isOpen).offset(x: offset1)
                pillFinger(2, "中指", height: 108, locked: false, active: isOpen).offset(x: offset2)
                pillFinger(3, "无名", height: 102, locked: false, active: isOpen).offset(x: offset3)
                pillFinger(4, "小指", height: 80, locked: mode == .star, active: mode == .vulcan && isOpen).offset(x: offset4)
            }
            .frame(height: 146)
            .animation(.spring(response: 0.25, dampingFraction: 0.72), value: isOpen)
        }
    }

    private func pillFinger(_ num: Int, _ title: String, height: CGFloat, locked: Bool, active: Bool) -> some View {
        VStack(spacing: 4) {
            if locked {
                Image(systemName: "lock.fill").font(.caption2).foregroundStyle(.cyan)
            } else {
                Text(active ? "↔" : "·").font(.caption.bold()).foregroundStyle(active ? accentColor : .secondary)
            }
            VStack(spacing: 2) {
                Text("\(num)").font(.headline.bold()).foregroundStyle(active ? .white : .primary)
                Text(title).font(.caption2).foregroundStyle(active ? .white.opacity(0.9) : .secondary)
            }
            .frame(width: 52, height: height)
            .background(
                locked ? Color.cyan.opacity(0.24) : (active ? accentColor : Color.secondary.opacity(0.16)),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(locked ? Color.cyan : (active ? accentColor : Color.secondary.opacity(0.3)), lineWidth: 1.5)
            )
        }
    }
}

// MARK: - Lv.1-4: 桌面四指波浪滚奏 (1-2-3-4-3-2)
private struct HandRollVisualizer: View {
    let totalBeatCount: Int
    let isRunning: Bool
    let accentColor: Color

    private static let sequence = [1, 2, 3, 4, 3, 2]

    private var activeFinger: Int {
        guard isRunning, totalBeatCount > 0 else { return 0 }
        return Self.sequence[(totalBeatCount - 1) % Self.sequence.count]
    }

    var body: some View {
        let names = ["", "食指", "中指", "无名指", "小指"]
        VStack(spacing: 12) {
            HStack {
                Label("波浪滚奏 (1-2-3-4-3-2)", systemImage: "water.waves")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(activeFinger > 0 ? "轻敲 \(names[activeFinger]) (\(activeFinger))" : "四指轻贴桌面")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(accentColor.opacity(0.16), in: Capsule())
                    .foregroundStyle(accentColor)
            }

            HStack(alignment: .bottom, spacing: 14) {
                ForEach([(1, "食指", 90.0), (2, "中指", 108.0), (3, "无名", 100.0), (4, "小指", 78.0)], id: \.0) { num, title, h in
                    let active = (activeFinger == num)
                    VStack(spacing: 4) {
                        Text(active ? "↓ 轻敲" : "·")
                            .font(.caption2.bold())
                            .foregroundStyle(active ? accentColor : .secondary)
                        VStack(spacing: 2) {
                            Text("\(num)").font(.headline.bold()).foregroundStyle(active ? .white : .primary)
                            Text(title).font(.caption2).foregroundStyle(active ? .white.opacity(0.9) : .secondary)
                        }
                        .frame(width: 54, height: h)
                        .background(active ? accentColor : Color.secondary.opacity(0.16), in: RoundedRectangle(cornerRadius: 18))
                        .offset(y: active ? -14 : 0)
                    }
                }
            }
            .frame(height: 148)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: activeFinger)
        }
    }
}

// MARK: - Lv.2 & Lv.3/4: 保留指爬格子 & 隔品拉伸
private struct SpiderFretboardVisualizer: View {
    let totalBeatCount: Int
    let isRunning: Bool
    let fingerOrder: [Int]
    let frets: [Int]
    let accentColor: Color

    private static let stringSequence = [6, 5, 4, 3, 2, 1, 2, 3, 4, 5]

    private var currentStepIndex: Int {
        guard isRunning, totalBeatCount > 0 else { return 0 }
        return (totalBeatCount - 1) % (Self.stringSequence.count * 4)
    }

    private var directionLabel: String {
        (currentStepIndex / 4) < 5 ? "↑ 向1弦" : "↓ 向6弦"
    }

    private var nodes: [FretboardNode] {
        let phase = currentStepIndex / 4
        let stepInPhase = currentStepIndex % 4
        let movedFingers = Set(fingerOrder.prefix(stepInPhase + 1))
        let activeIdx = fingerOrder[stepInPhase]
        let curString = Self.stringSequence[phase]
        let prevString = Self.stringSequence[phase == 0 ? 0 : phase - 1]

        return (0..<4).map { idx in
            let hasMoved = (isRunning && totalBeatCount > 0) ? movedFingers.contains(idx) : true
            let s = hasMoved ? curString : prevString
            let isActive = isRunning && totalBeatCount > 0 && idx == activeIdx
            return FretboardNode(
                string: s,
                fret: frets[idx],
                label: "\(idx + 1)",
                style: isActive ? .active(accentColor) : .held
            )
        }
    }

    private var statusText: String {
        guard isRunning, totalBeatCount > 0 else { return "准备：6弦 \(frets[0])品" }
        let phase = currentStepIndex / 4
        let activeIdx = fingerOrder[currentStepIndex % 4]
        let names = ["食指", "中指", "无名指", "小指"]
        let s = Self.stringSequence[phase]
        return "\(names[activeIdx]) → \(s)弦\(frets[activeIdx])品"
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Label("保留指 · \(directionLabel)", systemImage: "guitars.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(statusText)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(accentColor.opacity(0.16), in: Capsule())
                    .foregroundStyle(accentColor)
            }
            FretboardGrid(frets: frets, nodes: nodes)
                .frame(height: 162)
        }
    }
}

// MARK: - Lv.3-1 & Lv.3-4: 2-3指 / 3-4指 跨弦剥离
private struct IsolationFretboardVisualizer: View {
    let currentBeat: Int
    let isRunning: Bool
    let accentColor: Color
    let ringPinkyMode: Bool

    private var steps: [(beat: Int, finger: Int, string: Int, fret: Int, label: String)] {
        if ringPinkyMode {
            return [
                (1, 3, 4, 7, "4弦7品"),
                (2, 4, 2, 8, "2弦8品"),
                (3, 3, 2, 7, "2弦7品"),
                (4, 4, 4, 8, "4弦8品")
            ]
        }
        return [
            (1, 2, 4, 6, "4弦6品"),
            (2, 3, 2, 7, "2弦7品"),
            (3, 2, 2, 6, "2弦6品"),
            (4, 3, 4, 7, "4弦7品")
        ]
    }

    private var activeStep: (beat: Int, finger: Int, string: Int, fret: Int, label: String)? {
        guard isRunning, currentBeat >= 1, currentBeat <= 4 else { return nil }
        return steps[currentBeat - 1]
    }

    private var nodes: [FretboardNode] {
        var result: [FretboardNode] = ringPinkyMode
            ? [
                FretboardNode(string: 3, fret: 5, label: "1", style: .locked),
                FretboardNode(string: 3, fret: 6, label: "2", style: .locked)
            ]
            : [
                FretboardNode(string: 3, fret: 5, label: "1", style: .locked),
                FretboardNode(string: 3, fret: 8, label: "4", style: .locked)
            ]

        if let st = activeStep {
            let color: Color = (st.finger == 2 || st.finger == 3) && st.beat % 2 == 1
                ? Color(red: 0.96, green: 0.65, blue: 0.22)
                : accentColor
            result.append(FretboardNode(string: st.string, fret: st.fret, label: "\(st.finger)", style: .active(color)))
        } else if ringPinkyMode {
            result.append(FretboardNode(string: 4, fret: 7, label: "3", style: .preview))
            result.append(FretboardNode(string: 2, fret: 8, label: "4", style: .preview))
        } else {
            result.append(FretboardNode(string: 4, fret: 6, label: "2", style: .preview))
            result.append(FretboardNode(string: 2, fret: 7, label: "3", style: .preview))
        }
        return result
    }

    var body: some View {
        let names = ["", "食指", "中指", "无名指", "小指"]
        VStack(spacing: 10) {
            HStack {
                Label(ringPinkyMode ? "食/中指锁定 3弦" : "食/小指锁定 3弦", systemImage: "scope")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(activeStep.map { "\(names[$0.finger]) → \($0.label)" } ?? (ringPinkyMode ? "食3弦5品 · 中3弦6品" : "食3弦5品 · 小3弦8品"))
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(accentColor.opacity(0.16), in: Capsule())
                    .foregroundStyle(accentColor)
            }
            FretboardGrid(frets: [5, 6, 7, 8], nodes: nodes)
                .frame(height: 152)

            HStack(spacing: 6) {
                ForEach(steps, id: \.beat) { st in
                    let isCur = activeStep?.beat == st.beat
                    Text(st.label)
                        .font(.caption2.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(isCur ? accentColor : Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(isCur ? .white : .primary)
                }
            }
        }
    }
}

// MARK: - Lv.3-2: 2-3 交叉剪刀同步对调
private struct ScissorFretboardVisualizer: View {
    let currentBeat: Int
    let isRunning: Bool
    let accentColor: Color

    private var isOdd: Bool { !isRunning || (currentBeat % 2 == 1) }

    var body: some View {
        let nodes = [
            FretboardNode(string: 3, fret: 5, label: "1", style: .locked),
            FretboardNode(string: 3, fret: 8, label: "4", style: .locked),
            FretboardNode(string: isOdd ? 4 : 2, fret: 6, label: "2", style: .active(Color(red: 0.96, green: 0.65, blue: 0.22))),
            FretboardNode(string: isOdd ? 2 : 4, fret: 7, label: "3", style: .active(accentColor))
        ]
        VStack(spacing: 10) {
            HStack {
                Label("2-3 交叉剪刀同步", systemImage: "scissors")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(isOdd ? "同时：中4弦 + 无名2弦" : "同步对调：中2弦 + 无名4弦")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(accentColor.opacity(0.16), in: Capsule())
                    .foregroundStyle(accentColor)
            }
            FretboardGrid(frets: [5, 6, 7, 8], nodes: nodes)
                .frame(height: 162)
        }
    }
}

// MARK: - Lv.4-3: X 型四角对角拉伸
private struct XStretchFretboardVisualizer: View {
    let currentBeat: Int
    let isRunning: Bool
    let accentColor: Color

    private var isOdd: Bool { !isRunning || (currentBeat % 2 == 1) }

    var body: some View {
        let nodes = [
            FretboardNode(string: 6, fret: 5, label: "1", style: .locked),
            FretboardNode(string: 1, fret: 8, label: "4", style: .locked),
            FretboardNode(string: 4, fret: 6, label: "2", style: isOdd ? .active(accentColor) : .held),
            FretboardNode(string: 3, fret: 7, label: "3", style: isOdd ? .held : .active(accentColor))
        ]
        VStack(spacing: 10) {
            HStack {
                Label("X 型对角锁定", systemImage: "arrow.up.left.and.arrow.down.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(isOdd ? "中指击 4弦6品" : "无名指击 3弦7品")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(accentColor.opacity(0.16), in: Capsule())
                    .foregroundStyle(accentColor)
            }
            FretboardGrid(frets: [5, 6, 7, 8], nodes: nodes)
                .frame(height: 162)
        }
    }
}

// MARK: - Lv.4-4: 3-4 指纯左手双颤音
private struct TrillFretboardVisualizer: View {
    let currentBeat: Int
    let isRunning: Bool
    let accentColor: Color

    private var isHammer: Bool { isRunning && (currentBeat % 2 == 0) }

    var body: some View {
        let nodes = [
            FretboardNode(string: 3, fret: 5, label: "1", style: .locked),
            FretboardNode(string: 3, fret: 6, label: "2", style: .locked),
            FretboardNode(string: 3, fret: 7, label: "3", style: isHammer ? .held : .active(Color(red: 0.95, green: 0.36, blue: 0.45))),
            FretboardNode(string: 3, fret: 8, label: "4", style: isHammer ? .active(accentColor) : .preview)
        ]
        VStack(spacing: 10) {
            HStack {
                Label("3-4 指纯左手打勾弦", systemImage: "bolt.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(isHammer ? "小指击弦 8品 (H)" : "无名指 7品 (P)")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(accentColor.opacity(0.16), in: Capsule())
                    .foregroundStyle(accentColor)
            }
            FretboardGrid(frets: [5, 6, 7, 8], nodes: nodes)
                .frame(height: 162)
        }
    }
}

// MARK: - Lv.6-1 & 6-3: 全指板蛇形巡航 (1–12 品动态滑动视窗)
private struct FretboardCruiseVisualizer: View {
    let totalBeatCount: Int
    let isRunning: Bool
    let order: [Int]
    let accentColor: Color

    var body: some View {
        let pos = FretboardCruiseHelper.state(atBeat: max(1, totalBeatCount), order: order)
        let names = ["食指", "中指", "无名指", "小指"]

        let nodes: [FretboardNode] = (0..<4).map { idx in
            let hasMoved = (isRunning && totalBeatCount > 0) ? pos.movedSet.contains(idx) : true
            let s = hasMoved ? pos.string : pos.prevString
            let isActive = isRunning && totalBeatCount > 0 && idx == pos.activeFingerIdx
            return FretboardNode(
                string: s,
                fret: pos.frets[idx],
                label: "\(idx + 1)",
                style: isActive ? .active(accentColor) : .held
            )
        }

        VStack(spacing: 10) {
            HStack {
                Label("把位 \(pos.baseFret)–\(pos.baseFret + 3)品 · \(pos.isAscendingFrets ? "→ 推向12品" : "← 返回1品")", systemImage: "crown.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(isRunning && totalBeatCount > 0 ? "\(names[pos.activeFingerIdx]) → \(pos.string)弦\(pos.activeFret)品" : "起点：6弦1品")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(accentColor.opacity(0.16), in: Capsule())
                    .foregroundStyle(accentColor)
            }

            FullFretboardOverviewBar(activeRange: pos.baseFret...(pos.baseFret + 3), accentColor: accentColor)

            FretboardGrid(frets: pos.frets, nodes: nodes)
                .frame(height: 150)
        }
    }
}

// MARK: - Lv.6-2: 斜穿全指板 (对角线跨把换弦 1–12 品)
private struct FretboardDiagonalVisualizer: View {
    let totalBeatCount: Int
    let isRunning: Bool
    let accentColor: Color

    var body: some View {
        let pos = FretboardDiagonalHelper.state(atBeat: max(1, totalBeatCount))
        let names = ["食指", "中指", "无名指", "小指"]

        let nodes: [FretboardNode] = (0..<4).map { idx in
            let isActive = isRunning && totalBeatCount > 0 && idx == pos.activeFingerIdx
            return FretboardNode(
                string: pos.string,
                fret: pos.frets[idx],
                label: "\(idx + 1)",
                style: isActive ? .active(accentColor) : .preview
            )
        }

        VStack(spacing: 10) {
            HStack {
                Label("斜穿把位 \(pos.baseFret)–\(pos.baseFret + 3)品 · \(pos.isAscending ? "↗ 冲向12品" : "↙ 折返1品")", systemImage: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(isRunning && totalBeatCount > 0 ? "\(names[pos.activeFingerIdx]) → \(pos.string)弦\(pos.activeFret)品" : "起点：6弦1品")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(accentColor.opacity(0.16), in: Capsule())
                    .foregroundStyle(accentColor)
            }

            FullFretboardOverviewBar(activeRange: pos.baseFret...(pos.baseFret + 3), accentColor: accentColor)

            FretboardGrid(frets: pos.frets, nodes: nodes)
                .frame(height: 150)
        }
    }
}

// MARK: - 1–12 Fret Global Overview Strip for Lv.6
private struct FullFretboardOverviewBar: View {
    let activeRange: ClosedRange<Int>
    let accentColor: Color

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...12, id: \.self) { fret in
                let active = activeRange.contains(fret)
                Text("\(fret)")
                    .font(.system(size: 9, weight: active ? .bold : .medium, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(active ? accentColor : Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 5))
                    .foregroundStyle(active ? .white : .secondary)
            }
        }
    }
}

// MARK: - 和弦实战支线: 6 套渐进和弦转换可视化
private struct ChordTransitionVisualizer: View {
    enum Mode { case basic, extended, wideVoicing, barreShift, aShapeBarre, jazz251 }

    let currentBeat: Int
    let totalBeatCount: Int
    let isRunning: Bool
    let fChordStyle: FChordStyle
    let mode: Mode
    let accentColor: Color

    private struct ChordSpec {
        let name: String
        let subtitle: String
        let baseFretLabel: String?
        let dots: [(string: Int, fret: Int, finger: Int)]
        let mutedStrings: Set<Int>
        let openStrings: Set<Int>
        let barreFret: Int?
        let barreStringRange: ClosedRange<Int>?
        let focusNote: String
    }

    private var chords: [ChordSpec] {
        switch mode {
        case .extended:
            return [
                ChordSpec(name: "Fmaj7", subtitle: "大七和弦", baseFretLabel: nil, dots: [(2, 1, 1), (3, 2, 2), (4, 3, 3)], mutedStrings: [6, 5], openStrings: [1], barreFret: nil, barreStringRange: nil, focusNote: "1弦空弦保持明亮，中指无名指阶梯立起"),
                ChordSpec(name: "Bm7", subtitle: "小七横按", baseFretLabel: nil, dots: [(2, 3, 2), (4, 4, 3)], mutedStrings: [6], openStrings: [], barreFret: 2, barreStringRange: 1...5, focusNote: "食指2品横按，中指2弦3品与无名指4弦4品分叉"),
                ChordSpec(name: "Cadd9", subtitle: "加九和弦", baseFretLabel: nil, dots: [(4, 2, 1), (5, 3, 2), (2, 3, 3), (1, 3, 4)], mutedStrings: [6], openStrings: [3], barreFret: nil, barreStringRange: nil, focusNote: "无名指与小指锁死1-2弦3品作保留指"),
                ChordSpec(name: "G", subtitle: "大三和弦", baseFretLabel: nil, dots: [(5, 2, 1), (6, 3, 2), (2, 3, 3), (1, 3, 4)], mutedStrings: [], openStrings: [3, 4], barreFret: nil, barreStringRange: nil, focusNote: "3-4指不动，仅食指与中指同步上移一根弦")
            ]
        case .wideVoicing:
            return [
                ChordSpec(name: "Gadd9", subtitle: "宽指距加九", baseFretLabel: nil, dots: [(5, 2, 1), (3, 2, 2), (6, 3, 3), (1, 3, 4)], mutedStrings: [], openStrings: [2, 4], barreFret: nil, barreStringRange: nil, focusNote: "四指同时分叉按弦，2弦与4弦空弦必须保持通透"),
                ChordSpec(name: "Em9", subtitle: "小九扩张", baseFretLabel: nil, dots: [(5, 2, 1), (2, 3, 2), (4, 4, 4)], mutedStrings: [], openStrings: [1, 3, 6], barreFret: nil, barreStringRange: nil, focusNote: "小指跨至4弦4品，指尖立起绝不碰闷3弦空弦"),
                ChordSpec(name: "Cmaj9", subtitle: "大九色彩", baseFretLabel: nil, dots: [(4, 2, 1), (5, 3, 2), (2, 3, 3), (3, 4, 4)], mutedStrings: [6], openStrings: [1], barreFret: nil, barreStringRange: nil, focusNote: "四指各自落位，小指3弦4品与无名指2弦3品独立分开"),
                ChordSpec(name: "Dadd9/F#", subtitle: "转位加九", baseFretLabel: nil, dots: [(6, 2, 1), (3, 2, 2), (2, 3, 3)], mutedStrings: [], openStrings: [1, 4, 5], barreFret: nil, barreStringRange: nil, focusNote: "食指跨按6弦2品低音，保持1弦空弦清亮共鸣")
            ]
        case .barreShift:
            return [
                ChordSpec(name: "F", subtitle: "1品大横按", baseFretLabel: "1品", dots: [(3, 2, 2), (5, 3, 3), (4, 3, 4)], mutedStrings: [], openStrings: [], barreFret: 1, barreStringRange: 1...6, focusNote: "1品稳固压实，准备第4拍尾微松滑向3品"),
                ChordSpec(name: "G", subtitle: "3品大横按", baseFretLabel: "3品", dots: [(3, 2, 2), (5, 3, 3), (4, 3, 4)], mutedStrings: [], openStrings: [], barreFret: 1, barreStringRange: 1...6, focusNote: "保持E型手型整体平移2品，绝不散架"),
                ChordSpec(name: "Am", subtitle: "5品小调横按", baseFretLabel: "5品", dots: [(5, 3, 3), (4, 3, 4)], mutedStrings: [], openStrings: [], barreFret: 1, barreStringRange: 1...6, focusNote: "抬起中指转为Em型大横按，手腕保持松弛"),
                ChordSpec(name: "Em", subtitle: "7品A型横按", baseFretLabel: "7品", dots: [(2, 2, 2), (4, 3, 3), (3, 3, 4)], mutedStrings: [6], openStrings: [], barreFret: 1, barreStringRange: 1...5, focusNote: "食指7品横按1–5弦，中无名小指紧凑落位")
            ]
        case .aShapeBarre:
            return [
                ChordSpec(name: "C#m7", subtitle: "4品A型小七", baseFretLabel: "4品", dots: [(2, 2, 2), (4, 3, 3)], mutedStrings: [6], openStrings: [], barreFret: 1, barreStringRange: 1...5, focusNote: "食指4品横按1–5弦，中指与无名指精准分叉"),
                ChordSpec(name: "B", subtitle: "2品A型大横按", baseFretLabel: "2品", dots: [(4, 3, 2), (3, 3, 3), (2, 3, 4)], mutedStrings: [6], openStrings: [], barreFret: 1, barreStringRange: 1...5, focusNote: "2-3-4指紧凑落于4品，保持1弦2品清晰发声"),
                ChordSpec(name: "Aadd9", subtitle: "小指跨度加九", baseFretLabel: nil, dots: [(4, 2, 1), (2, 2, 2), (3, 4, 4)], mutedStrings: [6], openStrings: [1, 5], barreFret: nil, barreStringRange: nil, focusNote: "小指独立伸展至3弦4品，绝不拖倒1弦空弦"),
                ChordSpec(name: "E", subtitle: "开放大三", baseFretLabel: nil, dots: [(3, 1, 1), (5, 2, 2), (4, 2, 3)], mutedStrings: [], openStrings: [1, 2, 6], barreFret: nil, barreStringRange: nil, focusNote: "迅速卸力归位，体会6根弦全开的松弛共鸣")
            ]
        case .jazz251:
            return [
                ChordSpec(name: "Dm9", subtitle: "爵士小九 (II)", baseFretLabel: "3品", dots: [(4, 1, 1), (5, 3, 2), (3, 3, 3), (2, 3, 4)], mutedStrings: [1, 6], openStrings: [], barreFret: nil, barreStringRange: nil, focusNote: "食指4弦3品，2-3-4指分别独立按5/3/2弦5品"),
                ChordSpec(name: "G13", subtitle: "属十三 (V)", baseFretLabel: "3品", dots: [(6, 1, 1), (4, 1, 2), (3, 2, 3), (2, 3, 4)], mutedStrings: [1, 5], openStrings: [], barreFret: nil, barreStringRange: nil, focusNote: "食指6弦3品、中指4弦3品、无名指3弦4品、小指2弦5品"),
                ChordSpec(name: "Cmaj9", subtitle: "爵士大九 (I)", baseFretLabel: nil, dots: [(4, 2, 1), (5, 3, 2), (2, 3, 3), (3, 4, 4)], mutedStrings: [1, 6], openStrings: [], barreFret: nil, barreStringRange: nil, focusNote: "四指无空弦依赖，内侧四根弦同步精准落位"),
                ChordSpec(name: "A7#5", subtitle: "属七增五 (VI)", baseFretLabel: "5品", dots: [(6, 1, 1), (4, 1, 2), (3, 2, 3), (2, 2, 4)], mutedStrings: [1, 5], openStrings: [], barreFret: nil, barreStringRange: nil, focusNote: "整体滑移至5品，四指紧凑成型准备回到 Dm9")
            ]
        case .basic:
            let fChord: ChordSpec = (fChordStyle == .barre)
                ? ChordSpec(name: "F", subtitle: "大横按", baseFretLabel: nil, dots: [(3, 2, 2), (5, 3, 3), (4, 3, 4)], mutedStrings: [], openStrings: [], barreFret: 1, barreStringRange: 1...6, focusNote: "Am→F：中指稳落3弦2品，无名指落5弦3品")
                : ChordSpec(name: "F", subtitle: "小横按", baseFretLabel: nil, dots: [(3, 2, 2), (4, 3, 3)], mutedStrings: [6, 5], openStrings: [], barreFret: 1, barreStringRange: 1...2, focusNote: "Am→F：食指横按1-2弦1品，中指3弦2品、无名指4弦3品")

            return [
                ChordSpec(name: "C", subtitle: "大三和弦", baseFretLabel: nil, dots: [(2, 1, 1), (4, 2, 2), (5, 3, 3)], mutedStrings: [6], openStrings: [1, 3], barreFret: nil, barreStringRange: nil, focusNote: "保持指尖立起，避免无名指碰到4弦"),
                ChordSpec(name: "Am", subtitle: "小三和弦", baseFretLabel: nil, dots: [(2, 1, 1), (4, 2, 2), (3, 2, 3)], mutedStrings: [6], openStrings: [1, 5], barreFret: nil, barreStringRange: nil, focusNote: "准备切 F：中指与无名指即将分叉移动"),
                fChord,
                ChordSpec(name: "G", subtitle: "大三和弦", baseFretLabel: nil, dots: [(5, 2, 2), (6, 3, 3), (1, 3, 4)], mutedStrings: [], openStrings: [2, 3, 4], barreFret: nil, barreStringRange: nil, focusNote: "F→G：中指5弦2品、无名指6弦3品同步清晰落指")
            ]
        }
    }

    private var currentChordIndex: Int {
        guard isRunning, totalBeatCount > 0 else { return 0 }
        return ((totalBeatCount - 1) / 4) % chords.count
    }

    var body: some View {
        let cur = chords[currentChordIndex]
        let next = chords[(currentChordIndex + 1) % chords.count]

        VStack(spacing: 10) {
            HStack {
                HStack(spacing: 5) {
                    ForEach(0..<chords.count, id: \.self) { idx in
                        let active = idx == currentChordIndex
                        Text(chords[idx].name)
                            .font(.caption.bold())
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(active ? accentColor : Color.primary.opacity(0.07), in: Capsule())
                            .foregroundStyle(active ? .white : .secondary)
                    }
                }
                Spacer()
                Text("下一: \(next.name)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                chordDiagram(cur)
                    .frame(width: 138, height: 146)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(cur.name)
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                        Text(cur.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(cur.focusNote)
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)

                    if isRunning && currentBeat == 4 {
                        Text("准备换 \(next.name) !")
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.orange.opacity(0.2), in: Capsule())
                            .foregroundStyle(.orange)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func chordDiagram(_ chord: ChordSpec) -> some View {
        GeometryReader { geo in
            let leftPad: CGFloat = 14
            let rightPad: CGFloat = 12
            let topPad: CGFloat = 20
            let bottomPad: CGFloat = 8
            let gridW = geo.size.width - leftPad - rightPad
            let gridH = geo.size.height - topPad - bottomPad
            let colW = gridW / 5.0
            let rowH = gridH / 4.0

            let xForString: (Int) -> CGFloat = { s in leftPad + CGFloat(6 - s) * colW }
            let yForFretCenter: (Int) -> CGFloat = { f in topPad + (CGFloat(f) - 0.5) * rowH }

            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: leftPad, y: topPad))
                    p.addLine(to: CGPoint(x: leftPad + gridW, y: topPad))
                }.stroke(Color.primary, lineWidth: chord.baseFretLabel == nil ? 3 : 1.5)

                if let fretBadge = chord.baseFretLabel {
                    Text(fretBadge)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(accentColor)
                        .position(x: 6, y: yForFretCenter(1))
                }

                ForEach(1...4, id: \.self) { fret in
                    Path { p in
                        let y = topPad + CGFloat(fret) * rowH
                        p.move(to: CGPoint(x: leftPad, y: y))
                        p.addLine(to: CGPoint(x: leftPad + gridW, y: y))
                    }.stroke(Color.primary.opacity(0.22), lineWidth: 1)
                }

                ForEach(1...6, id: \.self) { s in
                    Path { p in
                        let x = xForString(s)
                        p.move(to: CGPoint(x: x, y: topPad))
                        p.addLine(to: CGPoint(x: x, y: topPad + gridH))
                    }.stroke(Color.primary.opacity(0.35), lineWidth: CGFloat(0.9 + Double(s) * 0.14))

                    if chord.mutedStrings.contains(s) {
                        Text("×").font(.caption2.bold()).foregroundStyle(.secondary).position(x: xForString(s), y: 8)
                    } else if chord.openStrings.contains(s) {
                        Circle().stroke(Color.secondary, lineWidth: 1.2).frame(width: 6, height: 6).position(x: xForString(s), y: 8)
                    }
                }

                if let bf = chord.barreFret, let range = chord.barreStringRange {
                    let xStart = xForString(range.upperBound)
                    let xEnd = xForString(range.lowerBound)
                    Capsule()
                        .fill(Color.cyan.opacity(0.88))
                        .frame(width: max(16, xEnd - xStart + 14), height: 16)
                        .overlay(Text("1").font(.caption2.bold()).foregroundStyle(.white))
                        .position(x: (xStart + xEnd) / 2, y: yForFretCenter(bf))
                }

                ForEach(Array(chord.dots.enumerated()), id: \.offset) { _, dot in
                    let dotColor: Color = dot.finger == 2 ? Color(red: 0.96, green: 0.65, blue: 0.22)
                        : dot.finger == 3 ? Color(red: 0.95, green: 0.36, blue: 0.45)
                        : Color.cyan
                    Circle()
                        .fill(dotColor)
                        .frame(width: 19, height: 19)
                        .overlay(Text("\(dot.finger)").font(.caption2.bold()).foregroundStyle(.white))
                        .position(x: xForString(dot.string), y: yForFretCenter(dot.fret))
                }
            }
        }
    }
}

// MARK: - Reusable Horizontal Fretboard Grid
private struct FretboardNode: Identifiable {
    enum Style {
        case active(Color)
        case locked
        case held
        case preview
    }
    let id = UUID()
    let string: Int
    let fret: Int
    let label: String
    let style: Style
}

private struct FretboardGrid: View {
    let frets: [Int]
    let nodes: [FretboardNode]

    var body: some View {
        GeometryReader { geo in
            let leftMargin: CGFloat = 24
            let topMargin: CGFloat = 18
            let bottomMargin: CGFloat = 8
            let boardW = geo.size.width - leftMargin - 8
            let boardH = geo.size.height - topMargin - bottomMargin
            let colW = boardW / CGFloat(max(frets.count, 1))
            let rowSpacing = boardH / 5.0

            let yForString: (Int) -> CGFloat = { s in topMargin + CGFloat(s - 1) * rowSpacing }
            let xForFret: (Int) -> CGFloat = { fret in
                let idx = frets.firstIndex(of: fret) ?? 0
                return leftMargin + (CGFloat(idx) + 0.5) * colW
            }

            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
                    .frame(width: boardW, height: boardH + 14)
                    .position(x: leftMargin + boardW / 2, y: topMargin + boardH / 2)

                ForEach(0...frets.count, id: \.self) { i in
                    let x = leftMargin + CGFloat(i) * colW
                    Path { p in
                        p.move(to: CGPoint(x: x, y: topMargin - 5))
                        p.addLine(to: CGPoint(x: x, y: topMargin + boardH + 5))
                    }.stroke(Color.primary.opacity(0.22), lineWidth: 1.4)
                }

                ForEach(Array(frets.enumerated()), id: \.offset) { idx, fret in
                    Text("\(fret)品")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .position(x: leftMargin + (CGFloat(idx) + 0.5) * colW, y: 7)
                }

                ForEach(1...6, id: \.self) { string in
                    let y = yForString(string)
                    Text("\(string)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .position(x: 10, y: y)
                    Path { p in
                        p.move(to: CGPoint(x: leftMargin, y: y))
                        p.addLine(to: CGPoint(x: leftMargin + boardW, y: y))
                    }.stroke(Color.primary.opacity(0.32), lineWidth: CGFloat(0.9 + Double(string) * 0.25))
                }

                ForEach(nodes) { node in
                    nodeBadge(node)
                        .position(x: xForFret(node.fret), y: yForString(node.string))
                }
            }
            .animation(.spring(response: 0.2, dampingFraction: 0.72), value: nodes.map { "\($0.string)-\($0.fret)-\($0.label)" })
        }
    }

    @ViewBuilder
    private func nodeBadge(_ node: FretboardNode) -> some View {
        switch node.style {
        case .active(let color):
            ZStack {
                Circle().fill(color.opacity(0.26)).frame(width: 32, height: 32)
                Circle().fill(color).frame(width: 22, height: 22)
                Text(node.label).font(.caption2.bold()).foregroundStyle(.white)
            }
        case .locked:
            ZStack {
                Circle().fill(Color.cyan).frame(width: 21, height: 21)
                Text(node.label).font(.caption2.bold()).foregroundStyle(.white)
                Image(systemName: "lock.fill")
                    .font(.system(size: 7))
                    .foregroundStyle(.white)
                    .padding(2)
                    .background(Color.blue, in: Circle())
                    .offset(x: 9, y: -9)
            }
        case .held:
            ZStack {
                Circle().fill(Color.secondary.opacity(0.72)).frame(width: 20, height: 20)
                Text(node.label).font(.caption2.bold()).foregroundStyle(.white)
            }
        case .preview:
            ZStack {
                Circle().strokeBorder(Color.orange, style: StrokeStyle(lineWidth: 1.4, dash: [3, 2])).frame(width: 20, height: 20)
                Text(node.label).font(.caption2.bold()).foregroundStyle(.orange)
            }
        }
    }
}
