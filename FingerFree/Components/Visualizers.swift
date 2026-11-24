import SwiftUI

struct StageVisualizerView: View {
    let stage: TrainingStageKind
    let currentBeat: Int
    let totalBeatCount: Int
    let isRunning: Bool
    let fChordStyle: FChordStyle

    var body: some View {
        Group {
            switch stage {
            case .neuralWakeup:
                HandTapVisualizer(
                    totalBeatCount: totalBeatCount,
                    isRunning: isRunning
                )
            case .spiderWalk:
                SpiderFretboardVisualizer(
                    totalBeatCount: totalBeatCount,
                    isRunning: isRunning
                )
            case .middleRingIsolation:
                IsolationFretboardVisualizer(
                    currentBeat: currentBeat,
                    isRunning: isRunning
                )
            case .chordTransition:
                ChordTransitionVisualizer(
                    currentBeat: currentBeat,
                    totalBeatCount: totalBeatCount,
                    isRunning: isRunning,
                    fChordStyle: fChordStyle
                )
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

// MARK: - Stage 1: 无琴桌面独立敲击
private struct HandTapVisualizer: View {
    let totalBeatCount: Int
    let isRunning: Bool

    private var activeFinger: Int {
        guard isRunning, totalBeatCount > 0 else { return 0 }
        // Alternate Middle (2) and Ring (3) on every beat
        return (totalBeatCount % 2 == 1) ? 2 : 3
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Label("桌面手势引导", systemImage: "hand.tap.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(activeFinger == 2 ? "单抬中指 (2)" : activeFinger == 3 ? "单抬无名指 (3)" : "食指与小指贴桌面")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(TrainingStageKind.neuralWakeup.accentColor.opacity(0.16), in: Capsule())
                    .foregroundStyle(TrainingStageKind.neuralWakeup.accentColor)
            }

            ZStack(alignment: .bottom) {
                // Desk surface line
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.14))
                    .frame(height: 6)
                    .padding(.horizontal, 8)
                    .offset(y: 4)

                HStack(alignment: .bottom, spacing: 14) {
                    fingerColumn(number: 1, name: "食指", height: 96, isLocked: true, isLifted: false)
                    fingerColumn(number: 2, name: "中指", height: 114, isLocked: false, isLifted: activeFinger == 2)
                    fingerColumn(number: 3, name: "无名指", height: 106, isLocked: false, isLifted: activeFinger == 3)
                    fingerColumn(number: 4, name: "小指", height: 82, isLocked: true, isLifted: false)
                }
                .padding(.bottom, 10)
                .animation(.spring(response: 0.22, dampingFraction: 0.68), value: activeFinger)
            }
            .frame(height: 165)

            HStack(spacing: 16) {
                legendDot(color: Color.cyan, text: "固定贴桌")
                legendDot(color: TrainingStageKind.neuralWakeup.accentColor, text: "独立抬起 1–2 cm")
                legendDot(color: Color.secondary.opacity(0.4), text: "保持静止不翘起")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private func fingerColumn(number: Int, name: String, height: CGFloat, isLocked: Bool, isLifted: Bool) -> some View {
        let fill: Color = isLocked
            ? Color.cyan.opacity(0.25)
            : (isLifted ? TrainingStageKind.neuralWakeup.accentColor : Color.secondary.opacity(0.18))
        let border: Color = isLocked
            ? Color.cyan
            : (isLifted ? TrainingStageKind.neuralWakeup.accentColor : Color.secondary.opacity(0.35))

        return VStack(spacing: 6) {
            if isLifted {
                Text("↑ 1-2cm")
                    .font(.caption2.bold())
                    .foregroundStyle(TrainingStageKind.neuralWakeup.accentColor)
                    .transition(.opacity)
            } else if isLocked {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                    .foregroundStyle(.cyan)
            } else {
                Text("静止")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 4) {
                Text("\(number)")
                    .font(.headline.bold())
                    .foregroundStyle(isLifted ? .white : .primary)
                Text(name)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(isLifted ? .white.opacity(0.9) : .secondary)
            }
            .frame(width: 56, height: height)
            .background(fill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(border, lineWidth: isLifted || isLocked ? 2 : 1)
            )
            .offset(y: isLifted ? -20 : 0)
        }
    }

    private func legendDot(color: Color, text: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text)
        }
    }
}

// MARK: - Stage 2: 低把位保留指爬格子 (6弦5品 1-2-3-4)
private struct SpiderFretboardVisualizer: View {
    let totalBeatCount: Int
    let isRunning: Bool

    // 6 strings ascending (6->1) then descending (2->5): 10 string phases * 4 fingers = 40 steps
    private static let stringSequence = [6, 5, 4, 3, 2, 1, 2, 3, 4, 5]

    private struct FingerPlacement {
        let finger: Int   // 1..4
        let fret: Int     // 5..8
        let string: Int   // 1..6 (1 = high E top, 6 = low E bottom)
        let isActive: Bool
    }

    private var currentStepIndex: Int {
        guard isRunning, totalBeatCount > 0 else { return 0 }
        return (totalBeatCount - 1) % (Self.stringSequence.count * 4)
    }

    private var placements: [FingerPlacement] {
        let phase = currentStepIndex / 4
        let activeFingerIdx = currentStepIndex % 4 // 0..3 -> finger 1..4
        let currentString = Self.stringSequence[phase]
        let previousPhase = (phase == 0) ? 0 : (phase - 1)
        let previousString = Self.stringSequence[previousPhase]

        return (0..<4).map { idx in
            let finger = idx + 1
            let fret = 5 + idx
            // Fingers up to activeFingerIdx have moved to currentString; remaining fingers stay anchored on previousString!
            let stringNum = (idx <= activeFingerIdx) ? currentString : previousString
            return FingerPlacement(
                finger: finger,
                fret: fret,
                string: stringNum,
                isActive: isRunning && totalBeatCount > 0 && idx == activeFingerIdx
            )
        }
    }

    private var statusText: String {
        guard isRunning, totalBeatCount > 0 else { return "准备：6弦 5品 (食指)" }
        if let active = placements.first(where: { $0.isActive }) {
            let names = ["", "食指", "中指", "无名指", "小指"]
            return "移动 \(names[active.finger]) → \(active.string)弦 \(active.fret)品"
        }
        return "保留指爬格子"
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Label("保留指爬格子 (5–8品)", systemImage: "guitars.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(statusText)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(TrainingStageKind.spiderWalk.accentColor.opacity(0.16), in: Capsule())
                    .foregroundStyle(TrainingStageKind.spiderWalk.accentColor)
            }

            FretboardGrid(
                frets: [5, 6, 7, 8],
                nodes: placements.map { p in
                    FretboardNode(
                        string: p.string,
                        fret: p.fret,
                        label: "\(p.finger)",
                        style: p.isActive ? .active(TrainingStageKind.spiderWalk.accentColor) : .held
                    )
                }
            )
            .frame(height: 168)

            HStack(spacing: 16) {
                HStack(spacing: 5) {
                    Circle().fill(TrainingStageKind.spiderWalk.accentColor).frame(width: 8, height: 8)
                    Text("当前移动手指")
                }
                HStack(spacing: 5) {
                    Circle().fill(Color.secondary.opacity(0.45)).frame(width: 8, height: 8)
                    Text("保留指（死贴原弦不抬起）")
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Stage 3: 中指/无名指跨弦交替
private struct IsolationFretboardVisualizer: View {
    let currentBeat: Int
    let isRunning: Bool

    private struct PatternStep {
        let beat: Int
        let finger: Int // 2 = 中指, 3 = 无名指
        let string: Int
        let fret: Int
        let label: String
    }

    private let steps: [PatternStep] = [
        PatternStep(beat: 1, finger: 2, string: 4, fret: 6, label: "4弦6品"),
        PatternStep(beat: 2, finger: 3, string: 2, fret: 7, label: "2弦7品"),
        PatternStep(beat: 3, finger: 2, string: 2, fret: 6, label: "2弦6品"),
        PatternStep(beat: 4, finger: 3, string: 4, fret: 7, label: "4弦7品")
    ]

    private var activeStep: PatternStep? {
        guard isRunning, currentBeat >= 1, currentBeat <= 4 else { return nil }
        return steps[currentBeat - 1]
    }

    private var nodes: [FretboardNode] {
        var result: [FretboardNode] = [
            FretboardNode(string: 3, fret: 5, label: "1", style: .locked),
            FretboardNode(string: 3, fret: 8, label: "4", style: .locked)
        ]

        if let step = activeStep {
            let color: Color = (step.finger == 2)
                ? Color(red: 0.96, green: 0.65, blue: 0.22)
                : TrainingStageKind.middleRingIsolation.accentColor
            result.append(FretboardNode(string: step.string, fret: step.fret, label: "\(step.finger)", style: .active(color)))
        } else {
            result.append(FretboardNode(string: 4, fret: 6, label: "2", style: .preview))
            result.append(FretboardNode(string: 2, fret: 7, label: "3", style: .preview))
        }
        return result
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Label("跨弦剥离指板", systemImage: "scope")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let step = activeStep {
                    Text("\(step.finger == 2 ? "中指" : "无名指") → \(step.label)")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(TrainingStageKind.middleRingIsolation.accentColor.opacity(0.16), in: Capsule())
                        .foregroundStyle(TrainingStageKind.middleRingIsolation.accentColor)
                } else {
                    Text("食指3弦5品 · 小指3弦8品锁定")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.cyan)
                }
            }

            FretboardGrid(frets: [5, 6, 7, 8], nodes: nodes)
                .frame(height: 160)

            // 4-beat sequence pill bar
            HStack(spacing: 6) {
                ForEach(steps, id: \.beat) { step in
                    let isCurrent = activeStep?.beat == step.beat
                    VStack(spacing: 2) {
                        Text("拍 \(step.beat)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(isCurrent ? .white.opacity(0.85) : .secondary)
                        Text(step.label)
                            .font(.caption2.bold())
                            .foregroundStyle(isCurrent ? .white : .primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        isCurrent
                            ? TrainingStageKind.middleRingIsolation.accentColor
                            : Color.primary.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                }
            }
        }
    }
}

// MARK: - Stage 4: C - Am - F - G 慢速转换
private struct ChordTransitionVisualizer: View {
    let currentBeat: Int
    let totalBeatCount: Int
    let isRunning: Bool
    let fChordStyle: FChordStyle

    private struct ChordSpec {
        let name: String
        let subtitle: String
        // string: 1..6 (1 = high E, 6 = low E), fret: 1..3, finger: 1..4
        let dots: [(string: Int, fret: Int, finger: Int)]
        let mutedStrings: Set<Int>
        let openStrings: Set<Int>
        let barreFret: Int?
        let barreStringRange: ClosedRange<Int>?
        let focusNote: String
    }

    private var chords: [ChordSpec] {
        let fChord: ChordSpec = (fChordStyle == .barre)
            ? ChordSpec(
                name: "F",
                subtitle: "大横按",
                dots: [(3, 2, 2), (5, 3, 3), (4, 3, 4)],
                mutedStrings: [],
                openStrings: [],
                barreFret: 1,
                barreStringRange: 1...6,
                focusNote: "Am→F：中指稳落3弦2品，无名指落5弦3品"
            )
            : ChordSpec(
                name: "F",
                subtitle: "小横按",
                dots: [(3, 2, 2), (4, 3, 3)],
                mutedStrings: [6, 5],
                openStrings: [],
                barreFret: 1,
                barreStringRange: 1...2,
                focusNote: "Am→F：食指横按1-2弦1品，中指3弦2品、无名指4弦3品"
            )

        return [
            ChordSpec(
                name: "C",
                subtitle: "大三和弦",
                dots: [(2, 1, 1), (4, 2, 2), (5, 3, 3)],
                mutedStrings: [6],
                openStrings: [1, 3],
                barreFret: nil,
                barreStringRange: nil,
                focusNote: "保持指尖立起，避免无名指碰到4弦"
            ),
            ChordSpec(
                name: "Am",
                subtitle: "小三和弦",
                dots: [(2, 1, 1), (4, 2, 2), (3, 2, 3)],
                mutedStrings: [6],
                openStrings: [1, 5],
                barreFret: nil,
                barreStringRange: nil,
                focusNote: "准备切 F：中指与无名指即将分叉移动"
            ),
            fChord,
            ChordSpec(
                name: "G",
                subtitle: "大三和弦",
                dots: [(5, 2, 2), (6, 3, 3), (1, 3, 4)],
                mutedStrings: [],
                openStrings: [2, 3, 4],
                barreFret: nil,
                barreStringRange: nil,
                focusNote: "F→G：中指5弦2品、无名指6弦3品同步清晰落指"
            )
        ]
    }

    private var currentChordIndex: Int {
        guard isRunning, totalBeatCount > 0 else { return 0 }
        return ((totalBeatCount - 1) / 4) % chords.count
    }

    private var currentChord: ChordSpec { chords[currentChordIndex] }
    private var nextChord: ChordSpec { chords[(currentChordIndex + 1) % chords.count] }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    ForEach(0..<chords.count, id: \.self) { idx in
                        let active = idx == currentChordIndex
                        Text(chords[idx].name)
                            .font(.subheadline.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(
                                active ? TrainingStageKind.chordTransition.accentColor : Color.primary.opacity(0.07),
                                in: Capsule()
                            )
                            .foregroundStyle(active ? .white : .secondary)
                    }
                }
                Spacer()
                Text("下一和弦: \(nextChord.name)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 20) {
                chordDiagram(currentChord)
                    .frame(width: 146, height: 152)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(currentChord.name)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                        Text(currentChord.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(currentChord.focusNote)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        Label("2 中指", systemImage: "circle.fill")
                            .foregroundStyle(Color(red: 0.96, green: 0.65, blue: 0.22))
                        Label("3 无名指", systemImage: "circle.fill")
                            .foregroundStyle(Color(red: 0.95, green: 0.36, blue: 0.45))
                    }
                    .font(.caption2.weight(.semibold))

                    if isRunning && currentBeat == 4 {
                        Text("准备换 \(nextChord.name) !")
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
            let rightPad: CGFloat = 14
            let topPad: CGFloat = 22
            let bottomPad: CGFloat = 10
            let gridW = geo.size.width - leftPad - rightPad
            let gridH = geo.size.height - topPad - bottomPad
            let colW = gridW / 5.0
            let rowH = gridH / 3.0

            // Helper: guitar chord box puts 6th string on LEFT (col 0) and 1st string on RIGHT (col 5)
            let xForString: (Int) -> CGFloat = { string in
                leftPad + CGFloat(6 - string) * colW
            }
            let yForFretCenter: (Int) -> CGFloat = { fret in
                topPad + (CGFloat(fret) - 0.5) * rowH
            }

            ZStack {
                // Nut
                Path { path in
                    path.move(to: CGPoint(x: leftPad, y: topPad))
                    path.addLine(to: CGPoint(x: leftPad + gridW, y: topPad))
                }
                .stroke(Color.primary, lineWidth: 3.5)

                // Frets 1..3
                ForEach(1...3, id: \.self) { fret in
                    Path { path in
                        let y = topPad + CGFloat(fret) * rowH
                        path.move(to: CGPoint(x: leftPad, y: y))
                        path.addLine(to: CGPoint(x: leftPad + gridW, y: y))
                    }
                    .stroke(Color.primary.opacity(0.25), lineWidth: 1)
                }

                // 6 vertical strings
                ForEach(1...6, id: \.self) { string in
                    Path { path in
                        let x = xForString(string)
                        path.move(to: CGPoint(x: x, y: topPad))
                        path.addLine(to: CGPoint(x: x, y: topPad + gridH))
                    }
                    .stroke(Color.primary.opacity(0.35), lineWidth: CGFloat(0.9 + Double(string) * 0.16))
                }

                // Open / Muted markers above nut
                ForEach(1...6, id: \.self) { string in
                    if chord.mutedStrings.contains(string) {
                        Text("×")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                            .position(x: xForString(string), y: 9)
                    } else if chord.openStrings.contains(string) {
                        Circle()
                            .stroke(Color.secondary, lineWidth: 1.3)
                            .frame(width: 7, height: 7)
                            .position(x: xForString(string), y: 9)
                    }
                }

                // Barre bar if present
                if let barreFret = chord.barreFret, let range = chord.barreStringRange {
                    let xStart = xForString(range.upperBound)
                    let xEnd = xForString(range.lowerBound)
                    Capsule()
                        .fill(Color.cyan.opacity(0.88))
                        .frame(width: max(18, xEnd - xStart + 16), height: 18)
                        .overlay(
                            Text("1")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                        )
                        .position(x: (xStart + xEnd) / 2, y: yForFretCenter(barreFret))
                }

                // Finger dots
                ForEach(Array(chord.dots.enumerated()), id: \.offset) { _, dot in
                    let dotColor: Color = {
                        switch dot.finger {
                        case 2: return Color(red: 0.96, green: 0.65, blue: 0.22)
                        case 3: return Color(red: 0.95, green: 0.36, blue: 0.45)
                        default: return Color.cyan
                        }
                    }()
                    Circle()
                        .fill(dotColor)
                        .frame(width: 21, height: 21)
                        .overlay(
                            Text("\(dot.finger)")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                        )
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
    let string: Int // 1..6 (1 = top, 6 = bottom)
    let fret: Int   // e.g. 5..8
    let label: String
    let style: Style
}

private struct FretboardGrid: View {
    let frets: [Int]
    let nodes: [FretboardNode]

    var body: some View {
        GeometryReader { geo in
            let leftMargin: CGFloat = 26
            let topMargin: CGFloat = 20
            let bottomMargin: CGFloat = 8
            let boardW = geo.size.width - leftMargin - 8
            let boardH = geo.size.height - topMargin - bottomMargin
            let colW = boardW / CGFloat(max(frets.count, 1))
            let rowSpacing = boardH / 5.0

            let yForString: (Int) -> CGFloat = { s in
                topMargin + CGFloat(s - 1) * rowSpacing
            }
            let xForFret: (Int) -> CGFloat = { fret in
                let idx = frets.firstIndex(of: fret) ?? 0
                return leftMargin + (CGFloat(idx) + 0.5) * colW
            }

            ZStack {
                // Fretboard wood tint
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
                    .frame(width: boardW, height: boardH + 14)
                    .position(x: leftMargin + boardW / 2, y: topMargin + boardH / 2)

                // Fret numbers & vertical fret bars
                ForEach(0...frets.count, id: \.self) { i in
                    let x = leftMargin + CGFloat(i) * colW
                    Path { path in
                        path.move(to: CGPoint(x: x, y: topMargin - 6))
                        path.addLine(to: CGPoint(x: x, y: topMargin + boardH + 6))
                    }
                    .stroke(Color.primary.opacity(0.22), lineWidth: 1.5)
                }

                ForEach(Array(frets.enumerated()), id: \.offset) { idx, fret in
                    Text("\(fret)品")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .position(x: leftMargin + (CGFloat(idx) + 0.5) * colW, y: 8)
                }

                // 6 horizontal strings (1 top -> 6 bottom)
                ForEach(1...6, id: \.self) { string in
                    let y = yForString(string)
                    Text("\(string)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .position(x: 11, y: y)

                    Path { path in
                        path.move(to: CGPoint(x: leftMargin, y: y))
                        path.addLine(to: CGPoint(x: leftMargin + boardW, y: y))
                    }
                    .stroke(Color.primary.opacity(0.32), lineWidth: CGFloat(0.9 + Double(string) * 0.28))
                }

                // Finger nodes
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
                Circle()
                    .fill(color.opacity(0.28))
                    .frame(width: 34, height: 34)
                Circle()
                    .fill(color)
                    .frame(width: 24, height: 24)
                Text(node.label)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
            }
        case .locked:
            ZStack {
                Circle()
                    .fill(Color.cyan)
                    .frame(width: 22, height: 22)
                Text(node.label)
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                Image(systemName: "lock.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.white)
                    .padding(2)
                    .background(Color.blue, in: Circle())
                    .offset(x: 10, y: -10)
            }
        case .held:
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.72))
                    .frame(width: 21, height: 21)
                Text(node.label)
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
            }
        case .preview:
            ZStack {
                Circle()
                    .strokeBorder(Color.orange, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                    .frame(width: 22, height: 22)
                Text(node.label)
                    .font(.caption2.bold())
                    .foregroundStyle(.orange)
            }
        }
    }
}
