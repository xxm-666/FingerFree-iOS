import Foundation
import SwiftUI

@MainActor
final class PracticeStore: ObservableObject {
    @Published var exerciseBPMs: [String: Int] {
        didSet { saveExerciseBPMs() }
    }
    @Published var levelMasteries: [Int: LevelMastery] {
        didSet { saveMasteries() }
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

    private static let bpmsKey = "fingerfree_v2_exercise_bpms"
    private static let masteriesKey = "fingerfree_v2_level_masteries"
    private static let recordsKey = "fingerfree_v2_records"
    private static let fChordKey = "fingerfree_f_chord_style_v1"
    private static let hapticsKey = "fingerfree_haptics_enabled_v1"
    private static let soundKey = "fingerfree_metronome_sound_v1"
    private static let countInKey = "fingerfree_count_in_enabled_v1"
    private static let v1MigratedKey = "fingerfree_v1_migrated"

    struct DailyRecommendation {
        let level: TrainingLevel
        let exercise: ExerciseItem
        let shouldTakeTest: Bool
        let headline: String
        let subtitle: String
    }

    private struct LegacyV1Record: Decodable {
        let id: UUID
        let date: Date
        let durationSeconds: Int
        let completedStages: [String]
        let stageBPMs: [String: Int]
        let zeroMistakesTwoMinutes: Bool
        let noForearmTension: Bool
    }

    init() {
        if let saved = UserDefaults.standard.dictionary(forKey: Self.bpmsKey) as? [String: Int] {
            self.exerciseBPMs = saved
        } else {
            self.exerciseBPMs = [:]
        }

        if let data = UserDefaults.standard.data(forKey: Self.masteriesKey),
           let decoded = try? JSONDecoder().decode([Int: LevelMastery].self, from: data) {
            self.levelMasteries = decoded
        } else {
            self.levelMasteries = [:]
        }

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

        self.hapticsEnabled = UserDefaults.standard.object(forKey: Self.hapticsKey) == nil
            ? true
            : UserDefaults.standard.bool(forKey: Self.hapticsKey)

        if let rawSound = UserDefaults.standard.string(forKey: Self.soundKey),
           let sound = MetronomeSound(rawValue: rawSound) {
            self.metronomeSound = sound
        } else {
            self.metronomeSound = .warmWoodblock
        }

        self.countInEnabled = UserDefaults.standard.object(forKey: Self.countInKey) == nil
            ? true
            : UserDefaults.standard.bool(forKey: Self.countInKey)

        migrateLegacyV1DataIfNeeded()
    }

    private func migrateLegacyV1DataIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Self.v1MigratedKey) else { return }
        defer { UserDefaults.standard.set(true, forKey: Self.v1MigratedKey) }

        // 1. Migrate legacy v1 stage BPMs to matching v2 exercises if not already customized
        if let legacyBPMs = UserDefaults.standard.dictionary(forKey: "fingerfree_stage_bpms_v1") as? [String: Int] {
            let mapping: [String: String] = [
                "wakeup": "lv1_desk",
                "spider": "lv2_1234",
                "isolation": "lv3_cross",
                "chords": "lv5_camfg"
            ]
            var updated = exerciseBPMs
            for (oldKey, newId) in mapping {
                if let val = legacyBPMs[oldKey], updated[newId] == nil {
                    updated[newId] = min(max(val, 30), 160)
                }
            }
            if updated != exerciseBPMs {
                exerciseBPMs = updated
            }
        }

        // 2. Migrate legacy v1 practice records
        if let data = UserDefaults.standard.data(forKey: "fingerfree_records_v1"),
           let legacy = try? JSONDecoder().decode([LegacyV1Record].self, from: data),
           !legacy.isEmpty {
            let existingIds = Set(records.map { $0.id })
            let converted: [PracticeRecord] = legacy.compactMap { item in
                guard !existingIds.contains(item.id) else { return nil }
                let avgBpm = item.stageBPMs.values.isEmpty
                    ? 60
                    : (item.stageBPMs.values.reduce(0, +) / item.stageBPMs.values.count)
                return PracticeRecord(
                    id: item.id,
                    date: item.date,
                    title: "早期训练打卡 (v1)",
                    durationSeconds: item.durationSeconds,
                    badgeText: "\(avgBpm) BPM",
                    isTest: false,
                    qualifiesForSpeedUp: item.zeroMistakesTwoMinutes && item.noForearmTension
                )
            }
            if !converted.isEmpty {
                records = (records + converted).sorted { $0.date > $1.date }
            }
        }
    }

    func bpm(for exercise: ExerciseItem) -> Int {
        exerciseBPMs[exercise.id] ?? exercise.defaultBPM
    }

    func setBPM(_ value: Int, for exercise: ExerciseItem) {
        exerciseBPMs[exercise.id] = min(max(value, 30), 160)
    }

    func speedUp(exercises: [ExerciseItem], by delta: Int = 5) {
        for ex in exercises {
            setBPM(bpm(for: ex) + delta, for: ex)
        }
    }

    func mastery(for level: TrainingLevel) -> LevelMastery {
        levelMasteries[level.rawValue] ?? .empty
    }

    func recordTestResult(for level: TrainingLevel, score: Int, tier: TestSpeedTier) {
        let rank = ProficiencyRank.from(score: score)
        var current = mastery(for: level)
        current.lastScore = score
        current.lastRank = rank
        if score >= current.bestScore {
            current.bestScore = score
            current.bestRank = rank
        }
        current.lastTestedDate = Date()
        levelMasteries[level.rawValue] = current

        let record = PracticeRecord(
            title: "\(level.code) \(level.title)考核",
            durationSeconds: level.testSpec.durationSeconds,
            badgeText: "\(score)% · \(rank.rawValue)级 (\(tier.bpm) BPM)",
            isTest: true,
            qualifiesForSpeedUp: score >= 90
        )
        addRecord(record)
    }

    func addRecord(_ record: PracticeRecord) {
        records.insert(record, at: 0)
    }

    /// Soft-gate prerequisite reminder (never blocks, only advises when earlier foundations are below B rank).
    func prerequisiteWarning(for level: TrainingLevel) -> String? {
        switch level {
        case .lv1:
            return nil
        case .lv2, .lv3, .lv4, .lv5:
            guard let prev = TrainingLevel(rawValue: level.rawValue - 1) else { return nil }
            let prevMastery = mastery(for: prev)
            if prevMastery.bestScore < 65 {
                return "建议提示：前置阶段 \(prev.code) \(prev.title) 尚未达到 B 级（65%），先打牢基础效果更佳（当前仍可直接练习）。"
            }
            return nil
        case .lv6:
            let unfinished = [TrainingLevel.lv2, .lv3, .lv4].filter { mastery(for: $0).bestScore < 65 }
            if !unfinished.isEmpty {
                let codes = unfinished.map(\.code).joined(separator: "、")
                return "终极挑战提示：建议先让 \(codes) 达到 B 级以上再挑战全指板（当前仍可直接体验）。"
            }
            return nil
        }
    }

    /// Recommends today's focus level & concrete next action (practice vs. stage test).
    var dailyRecommendation: DailyRecommendation {
        // Active focus level = first level not yet at A rank (80%), or Lv.6 if all mastered
        let focusLevel = TrainingLevel.allCases.first { mastery(for: $0).bestScore < 80 } ?? .lv6
        let m = mastery(for: focusLevel)
        let exercises = focusLevel.exercises
        // Pick the exercise with the lowest relative progress (current BPM - default BPM)
        let targetExercise = exercises.min { a, b in
            (bpm(for: a) - a.defaultBPM) < (bpm(for: b) - b.defaultBPM)
        } ?? exercises[0]

        let practicedFocusRecently = records.prefix(5).contains {
            !$0.isTest && ($0.title.contains(focusLevel.code) || $0.title.contains(focusLevel.title))
        }

        if practicedFocusRecently && m.lastScore < 80 {
            return DailyRecommendation(
                level: focusLevel,
                exercise: targetExercise,
                shouldTakeTest: true,
                headline: "检验 \(focusLevel.code) \(focusLevel.title) 熟练度",
                subtitle: m.bestScore > 0
                    ? "近期已练习本阶段，上次考核 \(m.lastScore)%（\(m.lastRank.rawValue) 级），复测冲刺 A/S 级"
                    : "近期已练习本阶段，测一次看看当前熟练度能否达标"
            )
        } else {
            let currentBPM = bpm(for: targetExercise)
            return DailyRecommendation(
                level: focusLevel,
                exercise: targetExercise,
                shouldTakeTest: false,
                headline: "\(focusLevel.code) · \(targetExercise.name)",
                subtitle: practicedToday
                    ? "今天已打卡，继续巩固 \(currentBPM) BPM 保持放松手感"
                    : "当前主攻阶段 · 推荐从 \(currentBPM) BPM 开始专注练习"
            )
        }
    }

    var testedLevelCount: Int {
        TrainingLevel.allCases.filter { mastery(for: $0).lastTestedDate != nil || mastery(for: $0).bestScore > 0 }.count
    }

    /// Average score across tested levels only (0 if no level has been tested yet).
    var overallMasteryPercent: Int {
        let tested = TrainingLevel.allCases.filter { mastery(for: $0).lastTestedDate != nil || mastery(for: $0).bestScore > 0 }
        guard !tested.isEmpty else { return 0 }
        let sum = tested.reduce(0) { $0 + mastery(for: $1).bestScore }
        return sum / tested.count
    }

    var totalPracticeMinutes: Int {
        records.reduce(0) { $0 + max(1, $1.durationSeconds / 60) }
    }

    var practicedToday: Bool {
        let cal = Calendar.current
        return records.contains { cal.isDateInToday($0.date) }
    }

    var currentStreakDays: Int {
        let cal = Calendar.current
        let uniqueDays = Set(records.map { cal.startOfDay(for: $0.date) })
        guard !uniqueDays.isEmpty else { return 0 }

        var streak = 0
        var checkDay = cal.startOfDay(for: Date())
        if !uniqueDays.contains(checkDay) {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: checkDay),
                  uniqueDays.contains(yesterday) else {
                return 0
            }
            checkDay = yesterday
        }

        while uniqueDays.contains(checkDay) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: checkDay) else { break }
            checkDay = prev
        }
        return streak
    }

    private func saveExerciseBPMs() {
        UserDefaults.standard.set(exerciseBPMs, forKey: Self.bpmsKey)
    }

    private func saveMasteries() {
        if let encoded = try? JSONEncoder().encode(levelMasteries) {
            UserDefaults.standard.set(encoded, forKey: Self.masteriesKey)
        }
    }

    private func saveRecords() {
        if let encoded = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(encoded, forKey: Self.recordsKey)
        }
    }
}
