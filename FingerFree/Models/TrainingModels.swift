import SwiftUI

enum TrainingStageKind: String, CaseIterable, Identifiable, Codable {
    case neuralWakeup
    case spiderWalk
    case middleRingIsolation
    case chordTransition

    var id: String { rawValue }

    var index: Int {
        switch self {
        case .neuralWakeup: return 1
        case .spiderWalk: return 2
        case .middleRingIsolation: return 3
        case .chordTransition: return 4
        }
    }

    var phaseTitle: String {
        switch self {
        case .neuralWakeup: return "神经唤醒"
        case .spiderWalk: return "基础定型"
        case .middleRingIsolation: return "专项剥离"
        case .chordTransition: return "实战应用"
        }
    }

    var exerciseName: String {
        switch self {
        case .neuralWakeup: return "无琴桌面独立敲击"
        case .spiderWalk: return "低把位保留指爬格子"
        case .middleRingIsolation: return "中指/无名指跨弦交替"
        case .chordTransition: return "C - Am - F - G 慢速转换"
        }
    }

    var durationMinutes: Int {
        switch self {
        case .neuralWakeup: return 2
        case .spiderWalk: return 3
        case .middleRingIsolation: return 3
        case .chordTransition: return 2
        }
    }

    var durationSeconds: Int {
        durationMinutes * 60
    }

    var defaultBPM: Int {
        switch self {
        case .neuralWakeup: return 60
        case .spiderWalk: return 65
        case .middleRingIsolation: return 55
        case .chordTransition: return 60
        }
    }

    var recommendedBPMText: String {
        switch self {
        case .neuralWakeup: return "60 BPM · 一拍一下"
        case .spiderWalk: return "60–70 BPM · 一拍一音"
        case .middleRingIsolation: return "50–60 BPM · 一拍一音"
        case .chordTransition: return "60 BPM · 四拍换一次"
        }
    }

    var coreRequirement: String {
        switch self {
        case .neuralWakeup:
            return "手掌虚握放桌面，固定食指与小指，交替单抬中指、无名指轻敲桌面。抬起高度 1–2 厘米即可，严禁另一根手指跟着翘起。"
        case .spiderWalk:
            return "从 6 弦 5 品开始做 1-2-3-4 爬格子。换弦时只移动当前按弦的手指，其余手指死死贴在上一根弦的品格上，直到轮到它才允许抬起。"
        case .middleRingIsolation:
            return "食指固定在 3 弦 5 品、小指固定在 3 弦 8 品（全程不松开）。只用中指（6品）和无名指（7品）在 2 弦与 4 弦之间交替按弦（4弦6品 → 2弦7品 → 2弦6品 → 4弦7品）。"
        case .chordTransition:
            return "重点关注 Am 转 F（大横按或小横按）以及 F 转 G 时，中指与无名指在 3、4、5 弦上的同步落指与独立分叉，保证每个音清晰无杂音。"
        }
    }

    var quickTip: String {
        switch self {
        case .neuralWakeup: return "抬起 1–2 cm 即可，紧盯另一根手指不翘起"
        case .spiderWalk: return "一毫米原则：未轮到的手指死死贴住上一根弦"
        case .middleRingIsolation: return "食指 3弦5品 + 小指 3弦8品 全程锁定不松开"
        case .chordTransition: return "关注 Am→F 与 F→G 时中指、无名指独立分叉"
        }
    }

    var symbolName: String {
        switch self {
        case .neuralWakeup: return "hand.raised.fingers.spread.fill"
        case .spiderWalk: return "guitars.fill"
        case .middleRingIsolation: return "scope"
        case .chordTransition: return "music.quarternote.3"
        }
    }

    var accentColor: Color {
        switch self {
        case .neuralWakeup: return Color(red: 0.28, green: 0.68, blue: 0.98)
        case .spiderWalk: return Color(red: 0.96, green: 0.65, blue: 0.22)
        case .middleRingIsolation: return Color(red: 0.95, green: 0.36, blue: 0.45)
        case .chordTransition: return Color(red: 0.30, green: 0.80, blue: 0.56)
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
    let durationSeconds: Int
    let completedStages: [TrainingStageKind]
    let stageBPMs: [String: Int]
    let zeroMistakesTwoMinutes: Bool
    let noForearmTension: Bool

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        durationSeconds: Int,
        completedStages: [TrainingStageKind],
        stageBPMs: [String: Int],
        zeroMistakesTwoMinutes: Bool,
        noForearmTension: Bool
    ) {
        self.id = id
        self.date = date
        self.durationSeconds = durationSeconds
        self.completedStages = completedStages
        self.stageBPMs = stageBPMs
        self.zeroMistakesTwoMinutes = zeroMistakesTwoMinutes
        self.noForearmTension = noForearmTension
    }

    var qualifiesForSpeedUp: Bool {
        zeroMistakesTwoMinutes && noForearmTension
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
            detail: "练习时请全程开启节拍器，一旦发现手指开始紧绷、发僵或出现失控联动，立刻点击「-10 BPM」降速，让神经重新建立清晰控制。",
            icon: "gauge.with.dots.needle.33percent",
            color: Color(red: 0.95, green: 0.36, blue: 0.45)
        ),
        PracticePrinciple(
            title: "每周提速标准 (+5 BPM)",
            subtitle: "稳定零失误且完全放松再进阶",
            detail: "只有当你在当前速度下连续弹奏 2 分钟零失误、且手背与前臂完全没有酸胀感时，下周才将节拍器调快 5 BPM。",
            icon: "chart.line.uptrend.xyaxis",
            color: Color(red: 0.30, green: 0.80, blue: 0.56)
        ),
        PracticePrinciple(
            title: "黄金练习时段",
            subtitle: "每天练琴前 10 分钟热身",
            detail: "建议将这 10 分钟放在每天练琴的最开始作为热身，此时手部肌肉最放松，大脑神经建立新控制通路的效率最高。",
            icon: "sunrise.fill",
            color: Color(red: 0.28, green: 0.68, blue: 0.98)
        )
    ]
}
