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

    var overallMasteryPercent: Int {
        let sum = TrainingLevel.allCases.reduce(0) { $0 + mastery(for: $1).bestScore }
        return sum / TrainingLevel.allCases.count
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
