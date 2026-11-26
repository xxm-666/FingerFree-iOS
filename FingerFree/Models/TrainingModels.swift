import SwiftUI

// MARK: - 5-Level Progressive Main Track (Lv.1–Lv.5) + Dedicated Chord Lab Branch

enum TrainingLevel: Int, CaseIterable, Identifiable, Codable {
    case lv1 = 1
    case lv2 = 2
    case lv3 = 3
    case lv4 = 4
    case lv5 = 6       // 征服指板 (preserves rawValue 6 for saved mastery compatibility)
    case chords = 5    // 和弦实战支线 (preserves rawValue 5 for saved mastery compatibility)

    static let mainTrackLevels: [TrainingLevel] = [.lv1, .lv2, .lv3, .lv4, .lv5]
    static let displayOrder: [TrainingLevel] = [.lv1, .lv2, .lv3, .lv4, .lv5, .chords]

    var id: Int { rawValue }

    var isMainTrack: Bool { self != .chords }

    var code: String {
        switch self {
        case .lv1: return "Lv.1"
        case .lv2: return "Lv.2"
        case .lv3: return "Lv.3"
        case .lv4: return "Lv.4"
        case .lv5: return "Lv.5"
        case .chords: return "和弦"
        }
    }

    var title: String {
        switch self {
        case .lv1: return "神经唤醒"
        case .lv2: return "基础定型"
        case .lv3: return "专项剥离"
        case .lv4: return "扩张与爆发"
        case .lv5: return "征服指板"
        case .chords: return "和弦实战"
        }
    }

    var difficultyLabel: String {
        switch self {
        case .lv1: return "入门 · 无琴可练"
        case .lv2: return "基础 · 保留指"
        case .lv3: return "核心 · 破联动"
        case .lv4: return "高阶 · 跨度/圆滑音"
        case .lv5: return "终极 · 1–12品全指板"
        case .chords: return "专项 · 从开放到爵士"
        }
    }

    var summary: String {
        switch self {
        case .lv1: return "建立大脑皮层对单指的独立控制通路，彻底消除中指与无名指下意识伴随翘起。"
        case .lv2: return "落实「一毫米原则」与「保留指」，覆盖顺序、逆序与交错指法，消除换弦乱飞。"
        case .lv3: return "双指锁定锚点，集中撕开中指/无名指以及无名指/小指的共享肌腱联动。"
        case .lv4: return "循序拉伸指间蹼膜解决大横按吃力，并用纯左手打勾弦练出指尖独立爆发力。"
        case .lv5: return "主线终极挑战：打通 1–4 品宽品距到 9–12 品窄品距，在全指板移动换把中保持绝对独立。"
        case .chords: return "独立实战支线：从经典开放和弦、宽指距色彩和弦、E/A 型大横按平移一路进阶到爵士/R&B 独立声部。"
        }
    }

    var symbolName: String {
        switch self {
        case .lv1: return "hand.raised.fingers.spread.fill"
        case .lv2: return "guitars.fill"
        case .lv3: return "scope"
        case .lv4: return "bolt.fill"
        case .lv5: return "crown.fill"
        case .chords: return "music.quarternote.3"
        }
    }

    var accentColor: Color {
        switch self {
        case .lv1: return Color(red: 0.22, green: 0.72, blue: 0.98)
        case .lv2: return Color(red: 0.96, green: 0.62, blue: 0.16)
        case .lv3: return Color(red: 0.95, green: 0.30, blue: 0.42)
        case .lv4: return Color(red: 0.65, green: 0.35, blue: 0.96)
        case .lv5: return Color(red: 0.93, green: 0.46, blue: 0.18)
        case .chords: return Color(red: 0.14, green: 0.76, blue: 0.52)
        }
    }

    /// Lv.1 Wakeup requires NO microphone audio test; Lv.2–Lv.5 & Chords use real-time microphone audio analysis.
    var usesAudioTest: Bool {
        self != .lv1
    }

    var isChordAudioTest: Bool {
        self == .chords
    }

    var exercises: [ExerciseItem] {
        ExerciseItem.all.filter { $0.level == self }
    }

    var testSpec: LevelTestSpec {
        switch self {
        case .lv1:
            return LevelTestSpec(
                level: .lv1,
                title: "Lv.1 神经独立性考核",
                durationSeconds: 45,
                usesAudioAnalysis: false,
                testExerciseId: "lv1_desk",
                tiers: [
                    TestSpeedTier(name: "达标", bpm: 60, speedWeight: 0.85),
                    TestSpeedTier(name: "进阶", bpm: 70, speedWeight: 0.95),
                    TestSpeedTier(name: "大师", bpm: 80, speedWeight: 1.00)
                ],
                requirement: "食指与小指稳贴桌面，随节拍交替单抬中指/无名指（高度 1–2 cm），严禁另一根手指翘起。本阶段无需麦克风收音。"
            )
        case .lv2:
            return LevelTestSpec(
                level: .lv2,
                title: "Lv.2 保留指爬格子实时音频考核",
                durationSeconds: 48,
                usesAudioAnalysis: true,
                testExerciseId: "lv2_1324",
                tiers: [
                    TestSpeedTier(name: "达标", bpm: 60, speedWeight: 0.85),
                    TestSpeedTier(name: "进阶", bpm: 75, speedWeight: 0.95),
                    TestSpeedTier(name: "大师", bpm: 90, speedWeight: 1.00)
                ],
                requirement: "从 6 弦 5 品开始按 1-3-2-4 爬格子，麦克风实时检测每个单音的音准、节拍同步与清脆度。"
            )
        case .lv3:
            return LevelTestSpec(
                level: .lv3,
                title: "Lv.3 中指/无名指剥离实时音频考核",
                durationSeconds: 48,
                usesAudioAnalysis: true,
                testExerciseId: "lv3_cross",
                tiers: [
                    TestSpeedTier(name: "达标", bpm: 55, speedWeight: 0.85),
                    TestSpeedTier(name: "进阶", bpm: 65, speedWeight: 0.95),
                    TestSpeedTier(name: "大师", bpm: 80, speedWeight: 1.00)
                ],
                requirement: "食指 3 弦 5 品与小指 3 弦 8 品全程锁定，麦克风实时检测 4弦6品→2弦7品→2弦6品→4弦7品 的音准与无杂音清晰度。"
            )
        case .lv4:
            return LevelTestSpec(
                level: .lv4,
                title: "Lv.4 隔品扩张实时音频考核",
                durationSeconds: 48,
                usesAudioAnalysis: true,
                testExerciseId: "lv4_wide",
                tiers: [
                    TestSpeedTier(name: "达标", bpm: 55, speedWeight: 0.85),
                    TestSpeedTier(name: "进阶", bpm: 70, speedWeight: 0.95),
                    TestSpeedTier(name: "大师", bpm: 85, speedWeight: 1.00)
                ],
                requirement: "按 5-6-8-9 隔品扩张把位从 6 弦爬至 1 弦再折返，麦克风实时检测大跨度按弦的音准、节拍同步与无打品清晰度。"
            )
        case .lv5:
            return LevelTestSpec(
                level: .lv5,
                title: "Lv.5 征服全指板实时音频通关赛",
                durationSeconds: 60,
                usesAudioAnalysis: true,
                testExerciseId: "lv6_diagonal",
                tiers: [
                    TestSpeedTier(name: "达标", bpm: 60, speedWeight: 0.85),
                    TestSpeedTier(name: "进阶", bpm: 75, speedWeight: 0.95),
                    TestSpeedTier(name: "大师", bpm: 90, speedWeight: 1.00)
                ],
                requirement: "从 6 弦 1 品一路斜穿换把直达 1 弦 12 品并折返，麦克风逐音验收宽把位与窄把位的音准、换把同步与清晰度。"
            )
        case .chords:
            return LevelTestSpec(
                level: .chords,
                title: "和弦实战转换实时音频考核",
                durationSeconds: 48,
                usesAudioAnalysis: true,
                testExerciseId: "lv5_camfg",
                tiers: [
                    TestSpeedTier(name: "达标", bpm: 60, speedWeight: 0.85),
                    TestSpeedTier(name: "进阶", bpm: 75, speedWeight: 0.95),
                    TestSpeedTier(name: "大师", bpm: 90, speedWeight: 1.00)
                ],
                requirement: "C - Am - F - G 每四拍切换一次，麦克风通过 FFT 多频段实时检测第 1 拍换和弦准点率与和弦音色饱满度。"
            )
        }
    }
}

// MARK: - Visualizer Kinds & Detailed Exercises (25 Curated Drills)

enum ExerciseVisualizerKind: Hashable, Codable {
    case handTap
    case handStar
    case handVulcan
    case handRoll
    case spider(order: [Int], frets: [Int])
    case isolation
    case scissor
    case ringPinkyIsolation
    case xStretch
    case trill
    case chordsBasic
    case chordsExtended
    case chordsWideVoicing
    case chordsBarreShift
    case chordsAShapeBarre
    case chordsJazz251
    case fretboardCruise(order: [Int])
    case fretboardDiagonal
}

struct ExerciseItem: Identifiable, Hashable {
    let id: String
    let level: TrainingLevel
    let name: String
    let badge: String
    let durationMinutes: Int
    let defaultBPM: Int
    let recommendedBPMText: String
    let tip: String
    let transitionPrompt: String
    let steps: [String]
    let visualizerKind: ExerciseVisualizerKind

    var durationSeconds: Int { durationMinutes * 60 }

    /// Expected target guitar MIDI note for beat `beatNumber` (1-indexed), or `nil` for non-pitched/chord exercises.
    func expectedTargetNote(atBeat beatNumber: Int) -> (midi: Int, label: String)? {
        guard beatNumber > 0 else { return nil }
        switch visualizerKind {
        case .spider(let order, let frets):
            let seq = [6, 5, 4, 3, 2, 1, 2, 3, 4, 5]
            let idx = (beatNumber - 1) % (seq.count * 4)
            let phase = idx / 4
            let stepInPhase = idx % 4
            let stringNum = seq[phase]
            let fingerIdx = order[stepInPhase]
            let fret = frets[fingerIdx]
            let midi = GuitarPitchHelper.midiNote(string: stringNum, fret: fret)
            return (midi, "\(stringNum)弦\(fret)品 \(GuitarPitchHelper.noteName(forMIDI: midi))")

        case .isolation:
            let steps: [(Int, Int)] = [(4, 6), (2, 7), (2, 6), (4, 7)]
            let (s, f) = steps[(beatNumber - 1) % 4]
            let midi = GuitarPitchHelper.midiNote(string: s, fret: f)
            return (midi, "\(s)弦\(f)品 \(GuitarPitchHelper.noteName(forMIDI: midi))")

        case .ringPinkyIsolation:
            let steps: [(Int, Int)] = [(4, 7), (2, 8), (2, 7), (4, 8)]
            let (s, f) = steps[(beatNumber - 1) % 4]
            let midi = GuitarPitchHelper.midiNote(string: s, fret: f)
            return (midi, "\(s)弦\(f)品 \(GuitarPitchHelper.noteName(forMIDI: midi))")

        case .scissor:
            let odd = (beatNumber % 2 == 1)
            let (s, f) = odd ? (4, 6) : (4, 7)
            let midi = GuitarPitchHelper.midiNote(string: s, fret: f)
            return (midi, "\(s)弦\(f)品 \(GuitarPitchHelper.noteName(forMIDI: midi))")

        case .xStretch:
            let odd = (beatNumber % 2 == 1)
            let (s, f) = odd ? (4, 6) : (3, 7)
            let midi = GuitarPitchHelper.midiNote(string: s, fret: f)
            return (midi, "\(s)弦\(f)品 \(GuitarPitchHelper.noteName(forMIDI: midi))")

        case .trill:
            let odd = (beatNumber % 2 == 1)
            let f = odd ? 7 : 8
            let midi = GuitarPitchHelper.midiNote(string: 3, fret: f)
            return (midi, "3弦\(f)品 \(GuitarPitchHelper.noteName(forMIDI: midi))")

        case .fretboardCruise(let order):
            let pos = FretboardCruiseHelper.state(atBeat: beatNumber, order: order)
            let midi = GuitarPitchHelper.midiNote(string: pos.string, fret: pos.activeFret)
            return (midi, "\(pos.string)弦\(pos.activeFret)品 \(GuitarPitchHelper.noteName(forMIDI: midi))")

        case .fretboardDiagonal:
            let pos = FretboardDiagonalHelper.state(atBeat: beatNumber)
            let midi = GuitarPitchHelper.midiNote(string: pos.string, fret: pos.activeFret)
            return (midi, "\(pos.string)弦\(pos.activeFret)品 \(GuitarPitchHelper.noteName(forMIDI: midi))")

        case .handTap, .handStar, .handVulcan, .handRoll,
             .chordsBasic, .chordsExtended, .chordsWideVoicing, .chordsBarreShift, .chordsAShapeBarre, .chordsJazz251:
            return nil
        }
    }

    static let all: [ExerciseItem] = [
        // ==================== Lv.1 神经唤醒 (4项) ====================
        ExerciseItem(
            id: "lv1_desk",
            level: .lv1,
            name: "无琴桌面独立敲击",
            badge: "经典必练",
            durationMinutes: 2,
            defaultBPM: 60,
            recommendedBPMText: "60 BPM · 一拍一下",
            tip: "抬起 1–2 cm 即可，紧盯另一根手指不跟着翘起",
            transitionPrompt: "手掌自然虚握轻放桌面，固定食指与小指，准备开始神经唤醒。",
            steps: [
                "手掌虚握轻放桌面，手腕保持平直完全放松。",
                "食指（1）与小指（4）指尖轻贴桌面固定不动。",
                "随节拍交替单抬中指（2）、无名指（3）轻敲桌面，高度仅 1–2 厘米。"
            ],
            visualizerKind: .handTap
        ),
        ExerciseItem(
            id: "lv1_star",
            level: .lv1,
            name: "指尖对指尖「开合星」",
            badge: "神经隔离",
            durationMinutes: 2,
            defaultBPM: 55,
            recommendedBPMText: "55 BPM · 一拍一开合",
            tip: "拇/食/小指尖紧紧顶住，仅中指与无名指同步分合",
            transitionPrompt: "双手合十指尖相对，掌心悬空，准备做指尖开合星。",
            steps: [
                "双手合十指尖相对，掌心留出自然拱形空隙。",
                "拇指、食指、小指指尖用力互相顶死绝不分离。",
                "随节拍将中指与无名指同步向外分开再闭合，两组指尖互不碰擦。"
            ],
            visualizerKind: .handStar
        ),
        ExerciseItem(
            id: "lv1_vulcan",
            level: .lv1,
            name: "瓦肯分组分裂操",
            badge: "指蹼放松",
            durationMinutes: 2,
            defaultBPM: 50,
            recommendedBPMText: "50 BPM · 慢速平移",
            tip: "指尖全程贴桌面平滑横向滑动，感受手背骨间肌发力",
            transitionPrompt: "手掌轻放桌面，准备练习两两分组横向分合。",
            steps: [
                "基础：食指+中指并拢为一组，无名指+小指并拢为一组，在桌面如剪刀般横向分合。",
                "进阶：中指+无名指并拢居中，食指与小指同时向两侧张开再合拢。",
                "全程保持指尖贴桌面不翘起，呼吸平稳不耸肩。"
            ],
            visualizerKind: .handVulcan
        ),
        ExerciseItem(
            id: "lv1_roll",
            level: .lv1,
            name: "桌面四指波浪滚奏 (1-2-3-4-3-2)",
            badge: "流畅连贯",
            durationMinutes: 2,
            defaultBPM: 65,
            recommendedBPMText: "65 BPM · 均匀波浪",
            tip: "重点听无名指落桌的声音是否与食指/中指完全等距均匀",
            transitionPrompt: "四指虚握贴桌面，准备按 1-2-3-4-3-2 顺序做均匀波浪敲击。",
            steps: [
                "四指自然弯曲轻放桌面，随节拍依次单指轻敲：食→中→无名→小→无名→中。",
                "特别留意「中→无名→小」这一段是否出现黏连或抢拍。",
                "像钢琴滚奏一样追求每一拍时值完全均匀，手背保持松弛。"
            ],
            visualizerKind: .handRoll
        ),

        // ==================== Lv.2 基础定型 (4项) ====================
        ExerciseItem(
            id: "lv2_1234",
            level: .lv2,
            name: "低把位保留指爬格子 1-2-3-4",
            badge: "经典必练",
            durationMinutes: 3,
            defaultBPM: 65,
            recommendedBPMText: "60–70 BPM · 一拍一音",
            tip: "一毫米原则：未轮到的手指死死贴在上一根弦不抬起",
            transitionPrompt: "甩手放松几秒，拿起吉他，将食指放到 6 弦 5 品准备保留指爬格子。",
            steps: [
                "从 6 弦 5 品开始，食-中-无名-小指依次按 5-6-7-8 品。",
                "换到 5 弦时，只移动食指到 5 弦 5 品，其余三指死贴 6 弦直到轮到它。",
                "逐弦上行至 1 弦后再逐弦返回 6 弦，指尖离弦控制在 1–2 毫米以内。"
            ],
            visualizerKind: .spider(order: [0, 1, 2, 3], frets: [5, 6, 7, 8])
        ),
        ExerciseItem(
            id: "lv2_4321",
            level: .lv2,
            name: "逆序弱指起手爬格子 4-3-2-1",
            badge: "弱指激活",
            durationMinutes: 2,
            defaultBPM: 60,
            recommendedBPMText: "55–65 BPM · 小指先动",
            tip: "由小指率先换弦定位，彻底扭转「只靠食指带路」的惯性",
            transitionPrompt: "四指放到 6 弦 5–8 品，准备从小指（8品）起手逆序爬格子。",
            steps: [
                "每根弦按「小指(8品) → 无名指(7品) → 中指(6品) → 食指(5品)」顺序弹奏。",
                "换弦时先单独移动小指，其余三指继续保留在上一根弦上。",
                "确保小指指尖立起垂直压弦，不要塌陷倒平。"
            ],
            visualizerKind: .spider(order: [3, 2, 1, 0], frets: [5, 6, 7, 8])
        ),
        ExerciseItem(
            id: "lv2_1324",
            level: .lv2,
            name: "交错指法密码 1-3-2-4",
            badge: "破顺指惯性",
            durationMinutes: 3,
            defaultBPM: 58,
            recommendedBPMText: "55–65 BPM · 一拍一音",
            tip: "跳过中指先落无名指，再精准收回中指，打破顺指惯性",
            transitionPrompt: "拿起吉他放到 6 弦 5–8 品，准备 1-3-2-4 交错指法爬格子。",
            steps: [
                "每根弦按「食指(5品) → 无名指(7品) → 中指(6品) → 小指(8品)」顺序移动。",
                "先落无名指时，严防中指跟着高高翘起。",
                "一旦前臂发紧立刻点击 -10 BPM 降速。"
            ],
            visualizerKind: .spider(order: [0, 2, 1, 3], frets: [5, 6, 7, 8])
        ),
        ExerciseItem(
            id: "lv2_1423",
            level: .lv2,
            name: "外侧定桩内卷 1-4-2-3",
            badge: "弱指强化",
            durationMinutes: 2,
            defaultBPM: 55,
            recommendedBPMText: "50–60 BPM · 一拍一音",
            tip: "先用食指与小指撑开把位，中指与无名指在内部独立落指",
            transitionPrompt: "食指 6 弦 5 品准备，先落食指与小指定桩。",
            steps: [
                "每根弦按「食指(5品) → 小指(8品) → 中指(6品) → 无名指(7品)」顺序行进。",
                "在食指与小指撑住外侧把位时，让中指和无名指独立落弦。",
                "虎口放松不死捏琴颈，保持指尖垂直触弦。"
            ],
            visualizerKind: .spider(order: [0, 3, 1, 2], frets: [5, 6, 7, 8])
        ),

        // ==================== Lv.3 专项剥离 (4项) ====================
        ExerciseItem(
            id: "lv3_cross",
            level: .lv3,
            name: "中指/无名指跨弦交替",
            badge: "核心王牌",
            durationMinutes: 3,
            defaultBPM: 55,
            recommendedBPMText: "50–60 BPM · 一拍一音",
            tip: "食指 3弦5品 + 小指 3弦8品 全程锁定不松开",
            transitionPrompt: "放松手腕，食指按稳 3 弦 5 品、小指按稳 3 弦 8 品锁定准备。",
            steps: [
                "食指固定在 3 弦 5 品、小指固定在 3 弦 8 品（全程绝不松开）。",
                "四拍循环：4弦6品(中) → 2弦7品(无名) → 2弦6品(中) → 4弦7品(无名)。",
                "换弦时指尖贴弦掠过，确保 3 弦不被误碰且每个音颗粒清晰。"
            ],
            visualizerKind: .isolation
        ),
        ExerciseItem(
            id: "lv3_scissor",
            level: .lv3,
            name: "2-3 交叉剪刀同步对调",
            badge: "同步反向",
            durationMinutes: 3,
            defaultBPM: 48,
            recommendedBPMText: "45–55 BPM · 同步换弦",
            tip: "中指与无名指必须同一拍「同时离弦、同时对调落指」",
            transitionPrompt: "食指 3 弦 5 品、小指 3 弦 8 品锁定，准备 2-3 指剪刀同步对调。",
            steps: [
                "食指（3弦5品）与小指（3弦8品）全程固定不抬起。",
                "第 1、3 拍：中指按 4 弦 6 品 + 无名指按 2 弦 7 品同时落指。",
                "第 2、4 拍：两指像剪刀一样同一瞬间反向对调至 中指 2 弦 6 品 + 无名指 4 弦 7 品。"
            ],
            visualizerKind: .scissor
        ),
        ExerciseItem(
            id: "lv3_2413",
            level: .lv3,
            name: "无底弱指对抗 2-4-1-3",
            badge: "弱指独立",
            durationMinutes: 2,
            defaultBPM: 55,
            recommendedBPMText: "50–60 BPM · 一拍一音",
            tip: "没有食指先打底，锻炼中指与小指率先独立精准定位",
            transitionPrompt: "从 6 弦 5–8 品起，以中指率先落弦开始 2-4-1-3 爬格子。",
            steps: [
                "每根弦按「中指(6品) → 小指(8品) → 食指(5品) → 无名指(7品)」顺序换弦。",
                "中指先落弦时禁止食指借力靠拢，四指各自保持独立垂直弧度。",
                "速度宁慢勿乱，确保每个音时值与音量完全均匀。"
            ],
            visualizerKind: .spider(order: [1, 3, 0, 2], frets: [5, 6, 7, 8])
        ),
        ExerciseItem(
            id: "lv3_34cross",
            level: .lv3,
            name: "无名指/小指跨弦剥离",
            badge: "解放 3-4 指",
            durationMinutes: 2,
            defaultBPM: 50,
            recommendedBPMText: "45–55 BPM · 锁定1-2指",
            tip: "食指 3弦5品 + 中指 3弦6品锁定，专注剥离最弱的 3-4 指",
            transitionPrompt: "食指 3 弦 5 品、中指 3 弦 6 品按稳锁定，准备 3-4 指跨弦剥离。",
            steps: [
                "食指固定 3 弦 5 品、中指固定 3 弦 6 品全程不松开。",
                "四拍循环：4弦7品(无名) → 2弦8品(小) → 2弦7品(无名) → 4弦8品(小)。",
                "手肘自然下垂，避免靠翻转手腕来帮小指够弦。"
            ],
            visualizerKind: .ringPinkyIsolation
        ),

        // ==================== Lv.4 扩张与爆发 (4项) ====================
        ExerciseItem(
            id: "lv4_wide12",
            level: .lv4,
            name: "食中隔品扩张 (5-7-8-9)",
            badge: "1-2指热身拉伸",
            durationMinutes: 2,
            defaultBPM: 55,
            recommendedBPMText: "50–60 BPM · 温和扩张",
            tip: "食指(5品)与中指(7品)隔开一品，为大跨度和弦建立基础柔韧性",
            transitionPrompt: "拇指放于琴颈背面中线偏下，准备 5-7-8-9 食中隔品拉伸。",
            steps: [
                "把位调整为 5品(食) - 7品(中) - 8品(无名) - 9品(小)。",
                "食指向琴头方向自然微倾，其余三指保持紧凑立起。",
                "感受 1、2 指间指蹼温和展开，全程不耸肩不僵硬。"
            ],
            visualizerKind: .spider(order: [0, 1, 2, 3], frets: [5, 7, 8, 9])
        ),
        ExerciseItem(
            id: "lv4_wide",
            level: .lv4,
            name: "中无名隔品拉伸 (5-6-8-9)",
            badge: "2-3指扩张",
            durationMinutes: 3,
            defaultBPM: 52,
            recommendedBPMText: "50–60 BPM · 温和拉伸",
            tip: "中指(6品)与无名指(8品)隔开一品，温和打开最紧的指间蹼膜",
            transitionPrompt: "拇指移至琴颈背面中线偏下，准备 5-6-8-9 隔品拉伸。",
            steps: [
                "把位调整为 5品(食) - 6品(中) - 8品(无名) - 9品(小)，重点拉开 2、3 指间距。",
                "拇指自然下移至琴颈中线偏下，为指间展开留出舒适空间。",
                "若感到手背明显撕扯痛，请移至 7-8-10-11 高把位保护肌腱。"
            ],
            visualizerKind: .spider(order: [0, 1, 2, 3], frets: [5, 6, 8, 9])
        ),
        ExerciseItem(
            id: "lv4_xstretch",
            level: .lv4,
            name: "X 型四角对角拉伸",
            badge: "极限分叉",
            durationMinutes: 2,
            defaultBPM: 48,
            recommendedBPMText: "45–55 BPM · 对角锁定",
            tip: "食指 6弦5品 + 小指 1弦8品 拉开对角线，内部 2-3 指交替",
            transitionPrompt: "食指按 6 弦 5 品，小指跨 6 根弦按 1 弦 8 品准备。",
            steps: [
                "食指按稳 6 弦 5 品，小指按稳 1 弦 8 品，形成最大斜向对角线。",
                "保持外侧两指不动，中指按 4 弦 6 品、无名指按 3 弦 7 品随拍交替弹响。",
                "每 4 小节可放松甩手 2 秒，切忌硬撑僵硬。"
            ],
            visualizerKind: .xStretch
        ),
        ExerciseItem(
            id: "lv4_trill",
            level: .lv4,
            name: "弱指双颤音 (3-4指 Trill)",
            badge: "纯左手爆发",
            durationMinutes: 2,
            defaultBPM: 60,
            recommendedBPMText: "55–65 BPM · 纯打勾弦",
            tip: "右手不拨弦！靠无名指与小指独立打弦(H)与勾弦(P)发声",
            transitionPrompt: "食指 3 弦 5 品、中指 3 弦 6 品轻贴按稳，准备纯左手 3-4 指颤音。",
            steps: [
                "食指固定 3 弦 5 品、中指固定 3 弦 6 品。",
                "无名指按稳 3 弦 7 品，小指随拍交替击打 3 弦 8 品(H)并向掌心勾弦(P)回到 7 品。",
                "追求纯左手发出的音量饱满清脆，且前臂保持放松。"
            ],
            visualizerKind: .trill
        ),

        // ==================== Lv.5 征服指板 (3项 · 主线终极 Boss) ====================
        ExerciseItem(
            id: "lv6_cruise",
            level: .lv5,
            name: "全指板蛇形巡航 (1品 ↔ 12品)",
            badge: "宽窄品距通吃",
            durationMinutes: 4,
            defaultBPM: 60,
            recommendedBPMText: "60 BPM · 动态换把",
            tip: "每到 1 弦或 6 弦边界自动顺移一品，拇指务必随食指同步平移",
            transitionPrompt: "主线终极挑战！从 6 弦 1 品起步，跟随指板滑动一路征服到 12 品。",
            steps: [
                "从 6 弦 1 品起步（1–4 品宽把位），按 1-2-3-4 逐弦爬上 1 弦。",
                "到达 1 弦后整体右移 1 品（2–5 品），再从 1 弦退回 6 弦，一路蛇形推进至 9–12 品。",
                "感受低把位宽品距拉伸与高把位窄品距精准控制的无缝切换。"
            ],
            visualizerKind: .fretboardCruise(order: [0, 1, 2, 3])
        ),
        ExerciseItem(
            id: "lv6_diagonal",
            level: .lv5,
            name: "斜穿全指板 (对角线跨把换弦)",
            badge: "换弦+换把合一",
            durationMinutes: 3,
            defaultBPM: 58,
            recommendedBPMText: "55–65 BPM · 每弦+2品",
            tip: "每换一根弦顺移 2 品，眼睛提前盯住下一把位食指落点",
            transitionPrompt: "食指就位 6 弦 1 品，准备每换一弦右移 2 品斜穿至 1 弦 12 品。",
            steps: [
                "上行路线：6弦(1-4品) → 5弦(3-6品) → 4弦(5-8品) → 3弦(7-10品) → 2弦(9-12品) → 1弦(9-12品)。",
                "到达 1 弦 12 品后沿原路倒序斜穿返回 6 弦 1 品。",
                "这是 Solo 与指弹大跨度跑动的核心基本功，换把时手臂带动手腕整体平移。"
            ],
            visualizerKind: .fretboardDiagonal
        ),
        ExerciseItem(
            id: "lv6_demon_cruise",
            level: .lv5,
            name: "全指板魔鬼指序巡航 (1-3-2-4)",
            badge: "终极 Boss",
            durationMinutes: 4,
            defaultBPM: 55,
            recommendedBPMText: "50–60 BPM · 极限独立",
            tip: "在 1–4 品最宽品距下完成 1-3-2-4 零联动，是左手独立性的终极试金石",
            transitionPrompt: "终极 Boss 挑战！从 6 弦 1 品起用 1-3-2-4 指序征服 1–12 品。",
            steps: [
                "全程使用 1-3-2-4 交错指序，从 1–4 品宽把位蛇形推进至 9–12 品。",
                "低把位 1–4 品极易诱发中指无名指联动，务必放慢速度坚守一毫米原则。",
                "能以 60 BPM 全程无酸胀完成，你的左手独立性已达到准演奏级水准！"
            ],
            visualizerKind: .fretboardCruise(order: [0, 2, 1, 3])
        ),

        // ==================== 和弦实战支线 (6项 · 由浅入深) ====================
        ExerciseItem(
            id: "lv5_camfg",
            level: .chords,
            name: "C - Am - F - G 经典开放转换",
            badge: "入门 · 开放/横按",
            durationMinutes: 2,
            defaultBPM: 60,
            recommendedBPMText: "60 BPM · 四拍一换",
            tip: "重点关注 Am→F 与 F→G 时中指与无名指在 3、4、5 弦同步分叉",
            transitionPrompt: "轻甩左手回到低把位，准备 C - Am - F - G 四拍一换。",
            steps: [
                "每 4 拍切换一次和弦：C → Am → F（可切换大/小横按）→ G。",
                "第 4 拍后半拍提前在脑海预演下一和弦指型，做到全指同步落弦。",
                "每换一个和弦可分解弹响 6 根弦自检，保证颗颗清晰无杂音。"
            ],
            visualizerKind: .chordsBasic
        ),
        ExerciseItem(
            id: "lv5_ext",
            level: .chords,
            name: "指弹保留指 (Fmaj7 - Bm7 - Cadd9 - G)",
            badge: "进阶 · 保留指",
            durationMinutes: 3,
            defaultBPM: 58,
            recommendedBPMText: "55–65 BPM · 四拍一换",
            tip: "结合小指保留指与中指/无名指反向跨弦的高阶实战转换",
            transitionPrompt: "回到低把位，准备指弹保留指和弦 Fmaj7 - Bm7 - Cadd9 - G。",
            steps: [
                "Fmaj7 → Bm7 练习横按与中指、无名指快速精准重组。",
                "Cadd9 → G 时保持无名指/小指固定在 1-2 弦 3 品作保留指，仅移动食指与中指。",
                "追求声部不断裂的丝滑衔接感。"
            ],
            visualizerKind: .chordsExtended
        ),
        ExerciseItem(
            id: "chord_wide_voicing",
            level: .chords,
            name: "宽指距色彩和弦 (Gadd9 - Em9 - Cmaj9 - Dadd9/F#)",
            badge: "中阶 · 跨度扩张",
            durationMinutes: 3,
            defaultBPM: 54,
            recommendedBPMText: "50–60 BPM · 色彩扩展",
            tip: "将 Lv.4 隔品扩张直接融入流行与指弹高频色彩和弦，空弦音必须清亮不闷",
            transitionPrompt: "拇指放于琴颈中线偏下，准备宽指距色彩和弦 Gadd9 - Em9 - Cmaj9 - Dadd9/F#。",
            steps: [
                "Gadd9(3-2-0-2-0-3) → Em9(0-2-4-0-3-0)：小指跨到 4 弦 4 品，注意绝不碰闷 3 弦空弦。",
                "Em9 → Cmaj9(x-3-2-4-3-0)：中指 5 弦 3 品、小指 3 弦 4 品形成大跨度分叉。",
                "Cmaj9 → Dadd9/F#(2-0-0-2-3-0)：食指稳按 6 弦 2 品低音，保持 4 弦与 1 弦空弦通透。"
            ],
            visualizerKind: .chordsWideVoicing
        ),
        ExerciseItem(
            id: "lv5_barre_shift",
            level: .chords,
            name: "大横按全把位平移 (F - G - Am - Em)",
            badge: "高阶 · 横按耐力",
            durationMinutes: 3,
            defaultBPM: 55,
            recommendedBPMText: "50–60 BPM · 1/3/5/7品",
            tip: "换把瞬间虎口与食指微松「滑过去」再落力，绝不死捏琴颈硬拖",
            transitionPrompt: "食指准备 1 品大横按 F，体验 1→3→5→7 品呼吸式横按平移。",
            steps: [
                "全部使用大横按指型：F(1品) → G(3品) → Am(5品) → Em(7品)。",
                "第 4 拍末尾瞬间卸力轻触琴弦滑移到目标品位，第 1 拍干脆压实发声。",
                "养成「按响即松、借力不硬捏」的高手省力习惯。"
            ],
            visualizerKind: .chordsBarreShift
        ),
        ExerciseItem(
            id: "chord_ashape_barre",
            level: .chords,
            name: "A型横按与弱指独立 (C#m7 - B - Aadd9 - E)",
            badge: "高阶 · 弱指横按",
            durationMinutes: 3,
            defaultBPM: 54,
            recommendedBPMText: "50–60 BPM · E调经典",
            tip: "专攻 A 型大横按中无名指/小指独立折指与精准让开 1 弦",
            transitionPrompt: "食指移至 4 品准备 C#m7，进入 E 调 A 型横按与弱指独立训练。",
            steps: [
                "C#m7(4品横按) → B(2品 A 型横按)：中无名小指紧凑贴合或无名指小横按，注意 1 弦 2 品清晰。",
                "B → Aadd9(x-0-2-4-2-0)：食指按 4 弦 2 品、中指 2 弦 2 品、小指跨 3 弦 4 品。",
                "Aadd9 → E(0-2-2-1-0-0)：体会松弛归位后的丰满共鸣。"
            ],
            visualizerKind: .chordsAShapeBarre
        ),
        ExerciseItem(
            id: "chord_jazz_251",
            level: .chords,
            name: "爵士/R&B 独立声部 (Dm9 - G13 - Cmaj9 - A7#5)",
            badge: "大师 · 四指全独立",
            durationMinutes: 3,
            defaultBPM: 52,
            recommendedBPMText: "48–58 BPM · 爵士 2-5-1-6",
            tip: "无任何空弦依赖，四根手指每拍同步落到完全不同的品格与弦位",
            transitionPrompt: "移至 3–6 品中把位，准备爵士/R&B 终极四指独立声部 Dm9 - G13 - Cmaj9 - A7#5。",
            steps: [
                "Dm9(x-5-3-5-5-x) → G13(3-x-3-4-5-x)：食指同时控制低音与 4 弦，中指与无名指精准错位。",
                "G13 → Cmaj9(x-3-2-4-3-x)：四指独立落弦，每根弦都由不同手指负责。",
                "Cmaj9 → A7#5(5-x-5-6-6-x)：整体滑至 5 品完成极具律动感的属七增五解决。"
            ],
            visualizerKind: .chordsJazz251
        )
    ]

    static func find(id: String) -> ExerciseItem? {
        all.first(where: { $0.id == id })
    }
}

// MARK: - Full Fretboard (1–12) Position Calculators

enum FretboardCruiseHelper {
    struct StepState {
        let baseFret: Int    // 1...9 (window covers baseFret ... baseFret+3, reaching 12)
        let string: Int      // 1...6
        let activeFingerIdx: Int // 0...3
        let activeFret: Int
        let frets: [Int]
        let movedSet: Set<Int>
        let prevString: Int
        let isAscendingFrets: Bool
    }

    // 16 positions: 1->9 ascending, then 8->2 descending (cycle of 16 positions * 6 strings * 4 beats)
    private static let baseFretCycle = [1, 2, 3, 4, 5, 6, 7, 8, 9, 8, 7, 6, 5, 4, 3, 2]

    static func state(atBeat beatNumber: Int, order: [Int]) -> StepState {
        let zeroBased = max(0, beatNumber - 1)
        let totalStringsPerPos = 6
        let beatsPerPos = totalStringsPerPos * 4 // 24 beats per position

        let posIdx = (zeroBased / beatsPerPos) % baseFretCycle.count
        let baseFret = baseFretCycle[posIdx]
        let frets = [baseFret, baseFret + 1, baseFret + 2, baseFret + 3]

        let beatInPos = zeroBased % beatsPerPos
        let stringStep = beatInPos / 4 // 0...5
        let stepInString = beatInPos % 4 // 0...3

        // Snake: even posIdx goes 6->1, odd posIdx goes 1->6
        let goingHighToLow = (posIdx % 2 == 1)
        let stringNum = goingHighToLow ? (1 + stringStep) : (6 - stringStep)
        let prevStringNum: Int
        if stringStep == 0 {
            prevStringNum = stringNum
        } else {
            prevStringNum = goingHighToLow ? (stringNum - 1) : (stringNum + 1)
        }

        let activeFingerIdx = order[stepInString]
        let movedSet = Set(order.prefix(stepInString + 1))

        return StepState(
            baseFret: baseFret,
            string: stringNum,
            activeFingerIdx: activeFingerIdx,
            activeFret: frets[activeFingerIdx],
            frets: frets,
            movedSet: movedSet,
            prevString: prevStringNum,
            isAscendingFrets: posIdx < 9
        )
    }
}

enum FretboardDiagonalHelper {
    struct StepState {
        let baseFret: Int
        let string: Int
        let activeFingerIdx: Int
        let activeFret: Int
        let frets: [Int]
        let isAscending: Bool
    }

    // 10-phase diagonal cycle: 6(1)->5(3)->4(5)->3(7)->2(9)->1(9) then back 2(7)->3(5)->4(3)->5(1)
    private static let phases: [(string: Int, baseFret: Int, asc: Bool)] = [
        (6, 1, true),
        (5, 3, true),
        (4, 5, true),
        (3, 7, true),
        (2, 9, true),
        (1, 9, true),
        (2, 7, false),
        (3, 5, false),
        (4, 3, false),
        (5, 1, false)
    ]

    static func state(atBeat beatNumber: Int) -> StepState {
        let zeroBased = max(0, beatNumber - 1)
        let phaseIdx = (zeroBased / 4) % phases.count
        let stepInPhase = zeroBased % 4
        let phase = phases[phaseIdx]
        let frets = [phase.baseFret, phase.baseFret + 1, phase.baseFret + 2, phase.baseFret + 3]
        let fingerIdx = phase.asc ? stepInPhase : (3 - stepInPhase)

        return StepState(
            baseFret: phase.baseFret,
            string: phase.string,
            activeFingerIdx: fingerIdx,
            activeFret: frets[fingerIdx],
            frets: frets,
            isAscending: phase.asc
        )
    }
}

// MARK: - Guitar Standard Tuning Pitch Helper

enum GuitarPitchHelper {
    private static let openStringMIDI: [Int: Int] = [
        1: 64, 2: 59, 3: 55, 4: 50, 5: 45, 6: 40
    ]

    private static let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    static func midiNote(string: Int, fret: Int) -> Int {
        (openStringMIDI[string] ?? 40) + fret
    }

    static func frequency(forMIDI midi: Int) -> Double {
        440.0 * pow(2.0, Double(midi - 69) / 12.0)
    }

    static func midiNote(forFrequency hz: Double) -> Int {
        guard hz > 20 else { return 0 }
        return Int(round(69.0 + 12.0 * log2(hz / 440.0)))
    }

    static func noteName(forMIDI midi: Int) -> String {
        guard midi >= 12 && midi <= 120 else { return "--" }
        let name = noteNames[midi % 12]
        let octave = (midi / 12) - 1
        return "\(name)\(octave)"
    }
}

// MARK: - Stage Proficiency Test Models

struct TestSpeedTier: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let bpm: Int
    let speedWeight: Double
}

struct LevelTestSpec {
    let level: TrainingLevel
    let title: String
    let durationSeconds: Int
    let usesAudioAnalysis: Bool
    let testExerciseId: String
    let tiers: [TestSpeedTier]
    let requirement: String

    var exercise: ExerciseItem {
        ExerciseItem.find(id: testExerciseId) ?? level.exercises.first!
    }
}

enum ProficiencyRank: String, Codable {
    case s = "S"
    case a = "A"
    case b = "B"
    case c = "C"
    case unranked = "--"

    static func from(score: Int) -> ProficiencyRank {
        if score >= 90 { return .s }
        if score >= 80 { return .a }
        if score >= 65 { return .b }
        return .c
    }

    var advice: String {
        switch self {
        case .s: return "神经控制极其稳固！已达到本阶段大师水准，可直接提速 +5 BPM 并推进下一阶段。"
        case .a: return "本阶段已稳固达标！日常继续保持放松，随时可以挑战下一阶段。"
        case .b: return "基本成型，但仍有轻微失误或联动，建议在当前速度巩固 2–3 天后再复测。"
        case .c: return "检测到较明显失误或紧绷，建议立刻下调 10 BPM 重建清晰神经通路。"
        case .unranked: return "尚未完成本阶段考核。"
        }
    }
}

struct LevelMastery: Codable {
    var bestScore: Int
    var bestRank: ProficiencyRank
    var lastScore: Int
    var lastRank: ProficiencyRank
    var lastTestedDate: Date?

    static let empty = LevelMastery(
        bestScore: 0,
        bestRank: .unranked,
        lastScore: 0,
        lastRank: .unranked,
        lastTestedDate: nil
    )

    init(
        bestScore: Int,
        bestRank: ProficiencyRank,
        lastScore: Int,
        lastRank: ProficiencyRank,
        lastTestedDate: Date?
    ) {
        self.bestScore = bestScore
        self.bestRank = bestRank
        self.lastScore = lastScore
        self.lastRank = lastRank
        self.lastTestedDate = lastTestedDate
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let best = try c.decodeIfPresent(Int.self, forKey: .bestScore) ?? 0
        let bRank = try c.decodeIfPresent(ProficiencyRank.self, forKey: .bestRank) ?? .unranked
        self.bestScore = best
        self.bestRank = bRank
        self.lastScore = try c.decodeIfPresent(Int.self, forKey: .lastScore) ?? best
        self.lastRank = try c.decodeIfPresent(ProficiencyRank.self, forKey: .lastRank) ?? bRank
        self.lastTestedDate = try c.decodeIfPresent(Date.self, forKey: .lastTestedDate)
    }
}

// MARK: - Metronome Timbres & Preferences

enum MetronomeSound: String, CaseIterable, Identifiable, Codable {
    case warmWoodblock
    case classicMechanical
    case guitarBodyTap
    case softMarimba

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .warmWoodblock: return "温润原木"
        case .classicMechanical: return "经典机械"
        case .guitarBodyTap: return "吉他敲板"
        case .softMarimba: return "柔和马林巴"
        }
    }

    var iconName: String {
        switch self {
        case .warmWoodblock: return "waveform.circle.fill"
        case .classicMechanical: return "metronome.fill"
        case .guitarBodyTap: return "guitars.fill"
        case .softMarimba: return "music.note"
        }
    }
}

enum FChordStyle: String, CaseIterable, Identifiable, Codable {
    case barre = "大横按 F"
    case miniBarre = "小横按 F"

    var id: String { rawValue }
}

struct PracticeRecord: Identifiable, Codable {
    let id: UUID
    let date: Date
    let title: String
    let durationSeconds: Int
    let badgeText: String
    let isTest: Bool
    let qualifiesForSpeedUp: Bool

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        title: String,
        durationSeconds: Int,
        badgeText: String,
        isTest: Bool = false,
        qualifiesForSpeedUp: Bool = false
    ) {
        self.id = id
        self.date = date
        self.title = title
        self.durationSeconds = durationSeconds
        self.badgeText = badgeText
        self.isTest = isTest
        self.qualifiesForSpeedUp = qualifiesForSpeedUp
    }
}

struct PracticePrinciple: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let detail: String
    let icon: String
    let color: Color

    static let all: [PracticePrinciple] = [
        PracticePrinciple(
            title: "一毫米原则",
            subtitle: "贴着弦走，抑制肌腱联动",
            detail: "抬起手指准备换弦时，指尖离开琴弦的距离控制在 1–2 毫米以内。手指抬得越高，越容易触发中指与无名指的肌腱联动。",
            icon: "ruler.fill",
            color: Color(red: 0.96, green: 0.65, blue: 0.22)
        ),
        PracticePrinciple(
            title: "紧绷即降速 (-10 BPM)",
            subtitle: "宁慢勿僵，优先神经控制",
            detail: "练习时全程开启节拍器，一旦发现手指紧绷、发僵或失控联动，立刻点击「-10 BPM」降速，让神经重新建立清晰控制。",
            icon: "gauge.with.dots.needle.33percent",
            color: Color(red: 0.95, green: 0.36, blue: 0.45)
        ),
        PracticePrinciple(
            title: "每周提速标准 (+5 BPM)",
            subtitle: "稳定零失误且完全放松再进阶",
            detail: "只有当你在当前速度下连续弹奏 2 分钟零失误、且手背与前臂完全没有酸胀感（或阶段考核达到 S 级）时，再将速度调快 5 BPM。",
            icon: "chart.line.uptrend.xyaxis",
            color: Color(red: 0.14, green: 0.76, blue: 0.52)
        ),
        PracticePrinciple(
            title: "换把先动拇指（全指板要领）",
            subtitle: "征服 1–12 品的省力核心",
            detail: "在 Lv.5 征服指板跨把位平移时，手臂带动手腕与拇指整体滑行，切忌手指硬伸而拇指留在原把位。",
            icon: "crown.fill",
            color: Color(red: 0.93, green: 0.46, blue: 0.18)
        )
    ]
}
