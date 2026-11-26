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
    @Published var chordDrillBestScores: [String: Int] {
        didSet { saveChordDrillScores() }
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
    private static let chordDrillScoresKey = "fingerfree_v2_chord_drill_scores"
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

        if let savedChordScores = UserDefaults.standard.dictionary(forKey: Self.chordDrillScoresKey) as? [String: Int] {
            self.chordDrillBestScores = savedChordScores
        } else {
            self.chordDrillBestScores = [:]
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

    static let unlockScoreThreshold = 65 // B 级解锁门槛

    /// Returns whether the user has unlocked `level` (Lv.1 & Lv.2 always unlocked; Lv.3–5 unlock sequentially at B rank >= 65% or via jump-test; Chords unlocks at Lv.2 B rank or via jump-test).
    func isUnlocked(_ level: TrainingLevel) -> Bool {
        let threshold = Self.unlockScoreThreshold
        if level == .lv1 || level == .lv2 { return true }
        if mastery(for: level).bestScore >= threshold { return true }

        let mainTrack = TrainingLevel.mainTrackLevels
        if let idx = mainTrack.firstIndex(of: level) {
            // Passing any higher main-track stage via jump-test automatically unlocks earlier main-track stages
            if mainTrack.dropFirst(idx + 1).contains(where: { mastery(for: $0).bestScore >= threshold }) {
                return true
            }
            // Standard sequential unlock: previous main-track stage >= B rank
            let prev = mainTrack[idx - 1]
            return mastery(for: prev).bestScore >= threshold
        } else {
            // Chord Lab unlocks once Lv.2 (or any higher main-track stage) reaches B rank
            return [TrainingLevel.lv2, .lv3, .lv4, .lv5].contains { mastery(for: $0).bestScore >= threshold }
        }
    }

    func lockReason(for level: TrainingLevel) -> String? {
        guard !isUnlocked(level) else { return nil }
        let mainTrack = TrainingLevel.mainTrackLevels
        if let idx = mainTrack.firstIndex(of: level), idx > 0 {
            let prev = mainTrack[idx - 1]
            return "需先完成前置阶段 \(prev.code) \(prev.title) 考核达 B 级（65%），或直接参加本阶段跳级考核"
        }
        return "需先完成主线 Lv.2 基础定型考核达 B 级（65%），或直接参加和弦跳级考核"
    }

    func chordDrillBestScore(for exercise: ExerciseItem) -> Int {
        if let saved = chordDrillBestScores[exercise.id] {
            return saved
        }
        // Backward compatibility: if user already passed the legacy chord test before v2.5, credit drill #1
        if exercise.id == "lv5_camfg" && mastery(for: .chords).bestScore >= Self.unlockScoreThreshold {
            return mastery(for: .chords).bestScore
        }
        return 0
    }

    /// Per-exercise unlock check: main-track exercises follow their stage lock; Chord Lab drills unlock sequentially one by one (B rank >= 65% or jump-test).
    func isExerciseUnlocked(_ exercise: ExerciseItem) -> Bool {
        guard exercise.level == .chords else {
            return isUnlocked(exercise.level)
        }
        let threshold = Self.unlockScoreThreshold
        let drills = TrainingLevel.chords.exercises
        guard let idx = drills.firstIndex(of: exercise) else { return false }

        if chordDrillBestScore(for: exercise) >= threshold {
            return true
        }
        // Jump-testing any later chord drill unlocks earlier chord drills too
        if drills.dropFirst(idx + 1).contains(where: { chordDrillBestScore(for: $0) >= threshold }) {
            return true
        }
        if idx == 0 {
            return isUnlocked(.chords)
        }
        let prev = drills[idx - 1]
        return chordDrillBestScore(for: prev) >= threshold
    }

    func exerciseLockReason(for exercise: ExerciseItem) -> String? {
        guard !isExerciseUnlocked(exercise) else { return nil }
        guard exercise.level == .chords else {
            return lockReason(for: exercise.level)
        }
        let drills = TrainingLevel.chords.exercises
        guard let idx = drills.firstIndex(of: exercise) else { return nil }
        if idx == 0 {
            return lockReason(for: .chords)
        }
        let prev = drills[idx - 1]
        return "需先完成上一套和弦「\(prev.name)」考核达 B 级（65%），或直接参加本套和弦跳级考核"
    }

    func unlockedExercises(for level: TrainingLevel) -> [ExerciseItem] {
        level.exercises.filter { isExerciseUnlocked($0) }
    }

    /// Next chord drill to test (the first unlocked chord drill not yet at B rank, or the latest unlocked drill).
    var nextChordTestExercise: ExerciseItem {
        let drills = TrainingLevel.chords.exercises
        let unlocked = unlockedExercises(for: .chords)
        if let pending = unlocked.first(where: { chordDrillBestScore(for: $0) < Self.unlockScoreThreshold }) {
            return pending
        }
        return unlocked.last ?? drills[0]
    }

    @discardableResult
    func recordTestResult(
        for level: TrainingLevel,
        exercise: ExerciseItem? = nil,
        score: Int,
        tier: TestSpeedTier
    ) -> [String] {
        let unlockedLevelsBefore = Set(TrainingLevel.displayOrder.filter { isUnlocked($0) })
        let unlockedChordIdsBefore = Set(TrainingLevel.chords.exercises.filter { isExerciseUnlocked($0) }.map(\.id))

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

        let testedEx = exercise ?? level.testSpec.exercise
        if level == .chords {
            let prevBest = chordDrillBestScores[testedEx.id] ?? 0
            if score >= prevBest {
                chordDrillBestScores[testedEx.id] = score
            }
        }

        let recordTitle = (level == .chords)
            ? "和弦考核 · \(testedEx.name)"
            : "\(level.code) \(level.title)考核"

        let record = PracticeRecord(
            title: recordTitle,
            durationSeconds: level.testSpec.durationSeconds,
            badgeText: "\(score)% · \(rank.rawValue)级 (\(tier.bpm) BPM)",
            isTest: true,
            qualifiesForSpeedUp: score >= 90
        )
        addRecord(record)

        var newlyUnlockedNames: [String] = []
        for lv in TrainingLevel.displayOrder where !unlockedLevelsBefore.contains(lv) && isUnlocked(lv) {
            newlyUnlockedNames.append(lv.isMainTrack ? "\(lv.code) \(lv.title)" : lv.title)
        }
        for drill in TrainingLevel.chords.exercises where !unlockedChordIdsBefore.contains(drill.id) && isExerciseUnlocked(drill) {
            // Avoid duplicating drill #1 when the whole Chord Lab just unlocked via Lv.2
            if !(drill.id == "lv5_camfg" && !unlockedLevelsBefore.contains(.chords)) {
                newlyUnlockedNames.append(drill.name)
            }
        }
        return newlyUnlockedNames
    }

    func addRecord(_ record: PracticeRecord) {
        records.insert(record, at: 0)
    }

    /// Recommends today's focus level & concrete next action strictly among unlocked stages and unlocked exercises.
    var dailyRecommendation: DailyRecommendation {
        let unlockedLevels = TrainingLevel.displayOrder.filter { isUnlocked($0) }
        let focusLevel = unlockedLevels.first { mastery(for: $0).bestScore < Self.unlockScoreThreshold }
            ?? unlockedLevels.first { mastery(for: $0).bestScore < 80 }
            ?? unlockedLevels.last
            ?? .lv1

        let m = mastery(for: focusLevel)
        let exercises = unlockedExercises(for: focusLevel)
        let candidateExercises = exercises.isEmpty ? focusLevel.exercises : exercises
        let targetExercise = candidateExercises.min { a, b in
            (bpm(for: a) - a.defaultBPM) < (bpm(for: b) - b.defaultBPM)
        } ?? candidateExercises[0]

        let practicedFocusRecently = records.prefix(5).contains {
            !$0.isTest && ($0.title.contains(focusLevel.code) || $0.title.contains(focusLevel.title))
        }

        if practicedFocusRecently && m.lastScore < 80 {
            let unlockHint = m.bestScore < Self.unlockScoreThreshold ? "达 B 级 (65%) 解锁下一阶段" : "冲刺 A/S 级"
            return DailyRecommendation(
                level: focusLevel,
                exercise: targetExercise,
                shouldTakeTest: true,
                headline: "检验 \(focusLevel.code) \(focusLevel.title) 熟练度",
                subtitle: "近期已练本阶段，去考核\(unlockHint)"
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
        TrainingLevel.displayOrder.filter { mastery(for: $0).lastTestedDate != nil || mastery(for: $0).bestScore > 0 }.count
    }

    /// Average score across tested levels only (0 if no level has been tested yet).
    var overallMasteryPercent: Int {
        let tested = TrainingLevel.displayOrder.filter { mastery(for: $0).lastTestedDate != nil || mastery(for: $0).bestScore > 0 }
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

    private func saveChordDrillScores() {
        UserDefaults.standard.set(chordDrillBestScores, forKey: Self.chordDrillScoresKey)
    }

    private func saveRecords() {
        if let encoded = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(encoded, forKey: Self.recordsKey)
        }
    }
}
