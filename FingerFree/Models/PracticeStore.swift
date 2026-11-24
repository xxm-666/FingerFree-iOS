import Foundation
import SwiftUI

@MainActor
final class PracticeStore: ObservableObject {
    @Published var stageBPMs: [TrainingStageKind: Int] {
        didSet { saveBPMs() }
    }
    @Published var records: [PracticeRecord] {
        didSet { saveRecords() }
    }
    @Published var fChordStyle: FChordStyle {
        didSet { UserDefaults.standard.set(fChordStyle.rawValue, forKey: Self.fChordKey) }
    }
    @Published var hapticsEnabled: Bool {
        didSet { UserDefaults.standard.set(hapticsEnabled, forKey: Self.hapticsKey) }
    }
    @Published var metronomeSound: MetronomeSound {
        didSet { UserDefaults.standard.set(metronomeSound.rawValue, forKey: Self.soundKey) }
    }
    @Published var countInEnabled: Bool {
        didSet { UserDefaults.standard.set(countInEnabled, forKey: Self.countInKey) }
    }
    @Published var spiderPattern: SpiderPattern {
        didSet { UserDefaults.standard.set(spiderPattern.rawValue, forKey: Self.spiderPatternKey) }
    }

    private static let bpmsKey = "fingerfree_stage_bpms_v1"
    private static let recordsKey = "fingerfree_records_v1"
    private static let fChordKey = "fingerfree_f_chord_style_v1"
    private static let hapticsKey = "fingerfree_haptics_enabled_v1"
    private static let soundKey = "fingerfree_metronome_sound_v1"
    private static let countInKey = "fingerfree_count_in_enabled_v1"
    private static let spiderPatternKey = "fingerfree_spider_pattern_v1"

    init() {
        var loadedBPMs: [TrainingStageKind: Int] = [:]
        if let rawDict = UserDefaults.standard.dictionary(forKey: Self.bpmsKey) as? [String: Int] {
            for stage in TrainingStageKind.allCases {
                loadedBPMs[stage] = rawDict[stage.rawValue] ?? stage.defaultBPM
            }
        } else {
            for stage in TrainingStageKind.allCases {
                loadedBPMs[stage] = stage.defaultBPM
            }
        }
        self.stageBPMs = loadedBPMs

        if let data = UserDefaults.standard.data(forKey: Self.recordsKey),
           let decoded = try? JSONDecoder().decode([PracticeRecord].self, from: data) {
            self.records = decoded
        } else {
            self.records = []
        }

        if let rawStyle = UserDefaults.standard.string(forKey: Self.fChordKey),
           let style = FChordStyle(rawValue: rawStyle) {
            self.fChordStyle = style
        } else {
            self.fChordStyle = .barre
        }

        if UserDefaults.standard.object(forKey: Self.hapticsKey) == nil {
            self.hapticsEnabled = true
        } else {
            self.hapticsEnabled = UserDefaults.standard.bool(forKey: Self.hapticsKey)
        }

        if let rawSound = UserDefaults.standard.string(forKey: Self.soundKey),
           let sound = MetronomeSound(rawValue: rawSound) {
            self.metronomeSound = sound
        } else {
            self.metronomeSound = .warmWoodblock
        }

        if UserDefaults.standard.object(forKey: Self.countInKey) == nil {
            self.countInEnabled = true
        } else {
            self.countInEnabled = UserDefaults.standard.bool(forKey: Self.countInKey)
        }

        if let rawPattern = UserDefaults.standard.string(forKey: Self.spiderPatternKey),
           let pattern = SpiderPattern(rawValue: rawPattern) {
            self.spiderPattern = pattern
        } else {
            self.spiderPattern = .p1234
        }
    }

    func bpm(for stage: TrainingStageKind) -> Int {
        stageBPMs[stage] ?? stage.defaultBPM
    }

    func setBPM(_ value: Int, for stage: TrainingStageKind) {
        stageBPMs[stage] = min(max(value, 30), 160)
    }

    func applyWeeklySpeedUp() {
        for stage in TrainingStageKind.allCases {
            let current = bpm(for: stage)
            setBPM(current + 5, for: stage)
        }
    }

    func addRecord(_ record: PracticeRecord) {
        records.insert(record, at: 0)
    }

    var totalPracticeMinutes: Int {
        records.reduce(0) { $0 + max(1, $1.durationSeconds / 60) }
    }

    var practicedToday: Bool {
        let calendar = Calendar.current
        return records.contains { calendar.isDateInToday($0.date) }
    }

    var currentStreakDays: Int {
        let calendar = Calendar.current
        let uniqueDays = Set(records.map { calendar.startOfDay(for: $0.date) })
        guard !uniqueDays.isEmpty else { return 0 }

        var streak = 0
        var checkDay = calendar.startOfDay(for: Date())
        if !uniqueDays.contains(checkDay) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDay),
                  uniqueDays.contains(yesterday) else {
                return 0
            }
            checkDay = yesterday
        }

        while uniqueDays.contains(checkDay) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: checkDay) else {
                break
            }
            checkDay = previous
        }
        return streak
    }

    private func saveBPMs() {
        var rawDict: [String: Int] = [:]
        for (stage, value) in stageBPMs {
            rawDict[stage.rawValue] = value
        }
        UserDefaults.standard.set(rawDict, forKey: Self.bpmsKey)
    }

    private func saveRecords() {
        if let encoded = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(encoded, forKey: Self.recordsKey)
        }
    }
}
