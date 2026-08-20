import Foundation
import SwiftUI

// MARK: - Modes

enum SHMode: Int, CaseIterable {
    case zen = 0, trials = 1, daily = 2, windward = 3

    var title: String {
        switch self {
        case .zen: return "Zen"
        case .trials: return "Trials"
        case .daily: return "Daily Cairn"
        case .windward: return "Windward"
        }
    }

    var blurb: String {
        switch self {
        case .zen: return "Endless stones, no clock, no penalty. Stack until it goes."
        case .trials: return "Forty set pieces. Fixed stones, fixed order, three stars each."
        case .daily: return "One seeded cairn a day, the same for every attempt you make."
        case .windward: return "A steady lateral force added to every centre of mass."
        }
    }
}

// MARK: - Saved cairn snapshot (compact vector record, re-drawn on Canvas)

struct SHCairnSnapshot: Codable, Identifiable {
    var id: String
    var name: String
    var savedAt: Double            // time interval since 1970
    var mode: Int
    var kindIDs: [Int]
    var xs: [Double]
    var ys: [Double]
    var rots: [Double]
    var height: Double
    var minMargin: Double
    var label: String              // trial name / day key / run descriptor

    var stoneCount: Int { min(kindIDs.count, min(xs.count, min(ys.count, rots.count))) }
    var date: Date { Date(timeIntervalSince1970: savedAt) }
    var modeEnum: SHMode { SHMode(rawValue: mode) ?? .zen }

    init(id: String = UUID().uuidString, name: String, savedAt: Double, mode: Int,
         kindIDs: [Int], xs: [Double], ys: [Double], rots: [Double],
         height: Double, minMargin: Double, label: String) {
        self.id = id; self.name = name; self.savedAt = savedAt; self.mode = mode
        self.kindIDs = kindIDs; self.xs = xs; self.ys = ys; self.rots = rots
        self.height = height; self.minMargin = minMargin; self.label = label
    }

    // Every field decoded defensively — adding a field must never wipe a gallery.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decodeIfPresent(String.self, forKey: .id)) ?? UUID().uuidString
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? "Cairn"
        savedAt = (try? c.decodeIfPresent(Double.self, forKey: .savedAt)) ?? 0
        mode = (try? c.decodeIfPresent(Int.self, forKey: .mode)) ?? 0
        kindIDs = (try? c.decodeIfPresent([Int].self, forKey: .kindIDs)) ?? []
        xs = (try? c.decodeIfPresent([Double].self, forKey: .xs)) ?? []
        ys = (try? c.decodeIfPresent([Double].self, forKey: .ys)) ?? []
        rots = (try? c.decodeIfPresent([Double].self, forKey: .rots)) ?? []
        height = (try? c.decodeIfPresent(Double.self, forKey: .height)) ?? 0
        minMargin = (try? c.decodeIfPresent(Double.self, forKey: .minMargin)) ?? 0
        label = (try? c.decodeIfPresent(String.self, forKey: .label)) ?? ""
    }
}

// MARK: - Save data
//
// Every property is decoded with decodeIfPresent + a default, so adding a field
// in a later version can never throw and reset the player's progress.

struct SHSaveData: Codable {
    var version: Int = 1

    // settings
    var onboardingDone: Bool = false
    var showPlumb: Bool = true
    var showSupport: Bool = true
    var showMeter: Bool = true
    var rotationStep: Int = 1              // degrees, 1 or 5
    var haptics: Bool = true
    var controlOnRight: Bool = true
    var zenWind: Bool = false

    // progress
    var totalStonesPlaced: Int = 0
    var totalRuns: Int = 0
    var tallestCairn: Double = 0
    var bestZenStones: Int = 0
    var bestZenHeight: Double = 0
    var bestWindwardStones: Int = 0
    var bestWindwardHeight: Double = 0
    var shorePlaced: [Int] = [0, 0, 0, 0]

    // trials
    var trialStars: [Int] = Array(repeating: 0, count: 40)
    var trialBest: [Double] = Array(repeating: 0, count: 40)

    // daily
    var dailyDone: [String] = []
    var dailyBestKeys: [String] = []
    var dailyBestValues: [Double] = []
    var dailyStreak: Int = 0
    var dailyLastDay: String = ""

    // gallery
    var gallery: [SHCairnSnapshot] = []

    init() {}

    enum CodingKeys: String, CodingKey {
        case version, onboardingDone, showPlumb, showSupport, showMeter, rotationStep,
             haptics, controlOnRight, zenWind, totalStonesPlaced, totalRuns, tallestCairn,
             bestZenStones, bestZenHeight, bestWindwardStones, bestWindwardHeight, shorePlaced,
             trialStars, trialBest, dailyDone, dailyBestKeys, dailyBestValues,
             dailyStreak, dailyLastDay, gallery
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func i(_ k: CodingKeys, _ d: Int) -> Int { (try? c.decodeIfPresent(Int.self, forKey: k)) ?? d }
        func b(_ k: CodingKeys, _ d: Bool) -> Bool { (try? c.decodeIfPresent(Bool.self, forKey: k)) ?? d }
        func f(_ k: CodingKeys, _ d: Double) -> Double { (try? c.decodeIfPresent(Double.self, forKey: k)) ?? d }
        func s(_ k: CodingKeys, _ d: String) -> String { (try? c.decodeIfPresent(String.self, forKey: k)) ?? d }

        version = i(.version, 1)
        onboardingDone = b(.onboardingDone, false)
        showPlumb = b(.showPlumb, true)
        showSupport = b(.showSupport, true)
        showMeter = b(.showMeter, true)
        rotationStep = i(.rotationStep, 1)
        haptics = b(.haptics, true)
        controlOnRight = b(.controlOnRight, true)
        zenWind = b(.zenWind, false)

        totalStonesPlaced = i(.totalStonesPlaced, 0)
        totalRuns = i(.totalRuns, 0)
        tallestCairn = f(.tallestCairn, 0)
        bestZenStones = i(.bestZenStones, 0)
        bestZenHeight = f(.bestZenHeight, 0)
        bestWindwardStones = i(.bestWindwardStones, 0)
        bestWindwardHeight = f(.bestWindwardHeight, 0)
        shorePlaced = (try? c.decodeIfPresent([Int].self, forKey: .shorePlaced)) ?? [0, 0, 0, 0]

        trialStars = (try? c.decodeIfPresent([Int].self, forKey: .trialStars)) ?? []
        trialBest = (try? c.decodeIfPresent([Double].self, forKey: .trialBest)) ?? []

        dailyDone = (try? c.decodeIfPresent([String].self, forKey: .dailyDone)) ?? []
        dailyBestKeys = (try? c.decodeIfPresent([String].self, forKey: .dailyBestKeys)) ?? []
        dailyBestValues = (try? c.decodeIfPresent([Double].self, forKey: .dailyBestValues)) ?? []
        dailyStreak = i(.dailyStreak, 0)
        dailyLastDay = s(.dailyLastDay, "")

        gallery = (try? c.decodeIfPresent([SHCairnSnapshot].self, forKey: .gallery)) ?? []

        normalize()
    }

    mutating func normalize() {
        if shorePlaced.count < 4 { shorePlaced += Array(repeating: 0, count: 4 - shorePlaced.count) }
        if shorePlaced.count > 4 { shorePlaced = Array(shorePlaced.prefix(4)) }
        let n = SHTrialData.all.count
        if trialStars.count < n { trialStars += Array(repeating: 0, count: n - trialStars.count) }
        if trialStars.count > n { trialStars = Array(trialStars.prefix(n)) }
        if trialBest.count < n { trialBest += Array(repeating: 0, count: n - trialBest.count) }
        if trialBest.count > n { trialBest = Array(trialBest.prefix(n)) }
        if dailyBestValues.count != dailyBestKeys.count {
            let m = Swift.min(dailyBestKeys.count, dailyBestValues.count)
            dailyBestKeys = Array(dailyBestKeys.prefix(m))
            dailyBestValues = Array(dailyBestValues.prefix(m))
        }
        if rotationStep != 1 && rotationStep != 5 { rotationStep = 1 }
        if gallery.count > SHStore.galleryLimit {
            gallery = Array(gallery.suffix(SHStore.galleryLimit))
        }
    }
}

// MARK: - Store

final class SHStore: ObservableObject {
    static let shared = SHStore()
    static let galleryLimit = 60
    private let key = "stoneheld.save.v1"

    @Published private(set) var data: SHSaveData

    private init() {
        if let raw = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(SHSaveData.self, from: raw) {
            data = decoded
        } else {
            var fresh = SHSaveData()
            fresh.normalize()
            data = fresh
        }
    }

    private func persist() {
        if let raw = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(raw, forKey: key)
        }
    }

    func mutate(_ block: (inout SHSaveData) -> Void) {
        var copy = data
        block(&copy)
        copy.normalize()
        data = copy
        persist()
    }

    // ---- derived ------------------------------------------------------------

    var totalStars: Int { data.trialStars.reduce(0, +) }

    var trialsPassed: Int { data.trialStars.filter { $0 > 0 }.count }

    func stars(forTrial id: Int) -> Int {
        let i = id - 1
        guard i >= 0, i < data.trialStars.count else { return 0 }
        return data.trialStars[i]
    }

    func best(forTrial id: Int) -> Double {
        let i = id - 1
        guard i >= 0, i < data.trialBest.count else { return 0 }
        return data.trialBest[i]
    }

    func isUnlocked(_ kindID: Int) -> Bool {
        switch SHCatalog.kind(kindID).unlock {
        case .start: return true
        case .placed(let n): return data.totalStonesPlaced >= n
        case .stars(let n): return totalStars >= n
        }
    }

    var unlockedIDs: [Int] {
        (0..<SHCatalog.count).filter { isUnlocked($0) }
    }

    var unlockedCount: Int { unlockedIDs.count }

    func unlockText(_ kindID: Int) -> String {
        switch SHCatalog.kind(kindID).unlock {
        case .start: return "Available from the start"
        case .placed(let n): return "Seat \(n) stones (\(min(data.totalStonesPlaced, n))/\(n))"
        case .stars(let n): return "Earn \(n) trial stars (\(min(totalStars, n))/\(n))"
        }
    }

    func shoreUnlocked(_ shore: Int) -> Int {
        SHShores.all[max(0, min(3, shore))].range.filter { isUnlocked($0) }.count
    }

    func dailyBest(_ dayKey: String) -> Double? {
        if let idx = data.dailyBestKeys.firstIndex(of: dayKey),
           idx < data.dailyBestValues.count {
            return data.dailyBestValues[idx]
        }
        return nil
    }

    func dailyIsDone(_ dayKey: String) -> Bool { data.dailyDone.contains(dayKey) }

    // ---- mutations ----------------------------------------------------------

    func recordPlacement(kindID: Int) {
        mutate { d in
            d.totalStonesPlaced += 1
            let s = SHShores.shore(of: kindID).index
            if s >= 0 && s < d.shorePlaced.count { d.shorePlaced[s] += 1 }
        }
    }

    func recordRunEnd(mode: SHMode, stones: Int, height: Double) {
        mutate { d in
            d.totalRuns += 1
            if height.isFinite && height > d.tallestCairn { d.tallestCairn = height }
            switch mode {
            case .zen:
                if stones > d.bestZenStones { d.bestZenStones = stones }
                if height.isFinite && height > d.bestZenHeight { d.bestZenHeight = height }
            case .windward:
                if stones > d.bestWindwardStones { d.bestWindwardStones = stones }
                if height.isFinite && height > d.bestWindwardHeight { d.bestWindwardHeight = height }
            default:
                break
            }
        }
    }

    func recordTrial(id: Int, stars: Int, metric: Double) {
        let i = id - 1
        mutate { d in
            guard i >= 0, i < d.trialStars.count else { return }
            if stars > d.trialStars[i] { d.trialStars[i] = stars }
            if metric.isFinite, metric > d.trialBest[i] { d.trialBest[i] = metric }
        }
    }

    func recordDaily(dayKey: String, height: Double, completed: Bool) {
        mutate { d in
            if let idx = d.dailyBestKeys.firstIndex(of: dayKey) {
                if idx < d.dailyBestValues.count, height > d.dailyBestValues[idx] {
                    d.dailyBestValues[idx] = height
                }
            } else {
                d.dailyBestKeys.append(dayKey)
                d.dailyBestValues.append(max(0, height))
            }
            if d.dailyBestKeys.count > 120 {
                d.dailyBestKeys.removeFirst(d.dailyBestKeys.count - 120)
                d.dailyBestValues.removeFirst(max(0, d.dailyBestValues.count - 120))
            }
            guard completed else { return }
            if !d.dailyDone.contains(dayKey) { d.dailyDone.append(dayKey) }
            if d.dailyDone.count > 400 { d.dailyDone.removeFirst(d.dailyDone.count - 400) }

            // streak: consecutive calendar days, computed against the previous key
            if d.dailyLastDay == dayKey { return }
            let cal = Calendar(identifier: .gregorian)
            if let prev = SHFormat.dayKeyFormatter.date(from: d.dailyLastDay),
               let today = SHFormat.dayKeyFormatter.date(from: dayKey),
               let diff = cal.dateComponents([.day], from: prev, to: today).day,
               diff == 1 {
                d.dailyStreak += 1
            } else {
                d.dailyStreak = 1
            }
            d.dailyLastDay = dayKey
        }
    }

    func addSnapshot(_ snap: SHCairnSnapshot) {
        mutate { d in
            d.gallery.append(snap)
            if d.gallery.count > SHStore.galleryLimit {
                d.gallery.removeFirst(d.gallery.count - SHStore.galleryLimit)
            }
        }
    }

    func renameSnapshot(id: String, to name: String) {
        mutate { d in
            if let i = d.gallery.firstIndex(where: { $0.id == id }) {
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                d.gallery[i].name = trimmed.isEmpty ? d.gallery[i].name : String(trimmed.prefix(28))
            }
        }
    }

    func deleteSnapshot(id: String) {
        mutate { d in d.gallery.removeAll(where: { $0.id == id }) }
    }

    func resetProgress() {
        mutate { d in
            let keepOnboarding = d.onboardingDone
            var fresh = SHSaveData()
            fresh.onboardingDone = keepOnboarding
            fresh.showPlumb = d.showPlumb
            fresh.showSupport = d.showSupport
            fresh.showMeter = d.showMeter
            fresh.rotationStep = d.rotationStep
            fresh.haptics = d.haptics
            fresh.controlOnRight = d.controlOnRight
            fresh.zenWind = d.zenWind
            fresh.normalize()
            d = fresh
        }
    }
}
