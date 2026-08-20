import Foundation

// MARK: - Trials
//
// 40 handcrafted challenges. Each hands the player a fixed set of stones in a
// fixed order and a single measurable goal; the three star thresholds are read
// against that goal's metric.

enum SHGoalKind: Int {
    case height     // metric = finished cairn height in points above the plinth
    case place      // metric = number of stones seated
    case margin     // metric = 100 x the weakest margin, and the whole set must be seated
}

struct SHTrial: Identifiable {
    let id: Int             // 1-based
    let band: Int           // 0...3
    let name: String
    let brief: String
    let stones: [Int]
    let kind: SHGoalKind
    let stars: [Double]     // three ascending thresholds; stars[0] is the pass bar
    let wind: Double

    var passBar: Double { stars.first ?? 0 }

    func starsEarned(metric: Double, placedAll: Bool) -> Int {
        if kind == .margin && !placedAll { return 0 }
        guard metric.isFinite else { return 0 }
        var n = 0
        for t in stars where metric >= t - 0.0001 { n += 1 }
        return min(3, n)
    }

    var goalText: String {
        switch kind {
        case .height:
            return "Reach \(Int(passBar)) pt of height"
        case .place:
            return "Seat \(Int(passBar)) of \(stones.count) stones"
        case .margin:
            return "Seat all \(stones.count) and hold \(Int(passBar))% margin"
        }
    }

    var metricLabel: String {
        switch kind {
        case .height: return "Height"
        case .place:  return "Stones"
        case .margin: return "Margin"
        }
    }

    func metricText(_ v: Double) -> String {
        guard v.isFinite else { return "—" }
        switch kind {
        case .height: return "\(Int(v)) pt"
        case .place:  return "\(Int(v))"
        case .margin: return "\(Int(v))%"
        }
    }
}

enum SHBands {
    static let names = ["Cove Trials", "Quarry Trials", "River Trials", "Point Trials"]
    static let blurbs = [
        "Round stones and gentle seats. Learn what the plumb line is telling you.",
        "Slate changes everything: broad platforms, poor towers, honest levels.",
        "Everything is rolled smooth. Contacts shrink to a line and stay there.",
        "Dense angular columns and a headland wind. Nothing here forgives."
    ]
}

enum SHTrialData {

    static let all: [SHTrial] = [
        // ------------------------------------------------ Band 0 — Pebble Cove
        SHTrial(id: 1, band: 0, name: "First Light",
                brief: "Four round stones and a plinth. Drag, release, watch it seat.",
                stones: [0, 3, 8, 5, 1], kind: .place, stars: [3, 4, 5], wind: 0),
        SHTrial(id: 2, band: 0, name: "Low Tide",
                brief: "The shingle is out. Take your time and read every seat.",
                stones: [2, 0, 4, 7, 3, 8], kind: .place, stars: [4, 5, 6], wind: 0),
        SHTrial(id: 3, band: 0, name: "Four Bells",
                brief: "A slate to start on, then whatever the cove gives you.",
                stones: [9, 0, 5, 3, 7], kind: .height, stars: [70, 100, 128], wind: 0),
        SHTrial(id: 4, band: 0, name: "Cove Practice",
                brief: "Seven stones, no wind, no clock. Get all of them down.",
                stones: [1, 6, 4, 8, 0, 3, 5], kind: .place, stars: [5, 6, 7], wind: 0),
        SHTrial(id: 5, band: 0, name: "Steady Hand",
                brief: "Small set, tight requirement: finish with real margin to spare.",
                stones: [10, 2, 0, 6, 4], kind: .margin, stars: [26, 45, 62], wind: 0),
        SHTrial(id: 6, band: 0, name: "Foam Line",
                brief: "Six pebbles and nothing broad to stand on. Height is the whole task.",
                stones: [3, 8, 0, 5, 1, 7], kind: .height, stars: [90, 130, 166], wind: 0),
        SHTrial(id: 7, band: 0, name: "Shingle Bank",
                brief: "One slab, mid-run. Save it for the wobble.",
                stones: [2, 9, 6, 1, 4, 0, 8], kind: .place, stars: [5, 6, 7], wind: 0),
        SHTrial(id: 8, band: 0, name: "Gull Watch",
                brief: "Eight stones, all of them round. Take the height while it is offered.",
                stones: [1, 5, 0, 6, 3, 8, 4, 7], kind: .height, stars: [120, 175, 228], wind: 0),
        SHTrial(id: 9, band: 0, name: "Small Weather",
                brief: "A breath of wind off the water. Watch the gauge before you release.",
                stones: [0, 4, 3, 5, 8], kind: .margin, stars: [25, 44, 61], wind: 0.030),
        SHTrial(id: 10, band: 0, name: "Cove Master",
                brief: "Every stone in Pebble Cove, in order. Seat the lot.",
                stones: [2, 1, 6, 0, 5, 3, 7, 4, 8], kind: .place, stars: [7, 8, 9], wind: 0),

        // ----------------------------------------------- Band 1 — Slate Quarry
        SHTrial(id: 11, band: 1, name: "Quarry Floor",
                brief: "Slate under everything. Notice how much wider the seats become.",
                stones: [9, 10, 15, 0, 3], kind: .place, stars: [3, 4, 5], wind: 0),
        SHTrial(id: 12, band: 1, name: "The Ledger",
                brief: "Two ledges and four cobbles. Flat stones buy stability, not height.",
                stones: [10, 9, 2, 6, 4, 1], kind: .height, stars: [82, 120, 154], wind: 0),
        SHTrial(id: 13, band: 1, name: "Split Foot",
                brief: "The cleft shelf sits proud on one end. Rotate it or pay for it.",
                stones: [9, 12, 10, 15, 0, 5], kind: .margin, stars: [24, 42, 58], wind: 0),
        SHTrial(id: 14, band: 1, name: "Bench Work",
                brief: "A plate, a riser and a handful of round stones on top.",
                stones: [11, 9, 10, 17, 3, 8, 4], kind: .place, stars: [5, 6, 7], wind: 0),
        SHTrial(id: 15, band: 1, name: "Two Tables",
                brief: "Build a floor, then build a second floor on it.",
                stones: [15, 10, 9, 14, 2, 1, 6], kind: .height, stars: [80, 116, 148], wind: 0),
        SHTrial(id: 16, band: 1, name: "Plate and Pebble",
                brief: "Alternating wide and round. The rhythm matters more than the order.",
                stones: [11, 0, 10, 5, 15, 3, 9, 8], kind: .place, stars: [6, 7, 8], wind: 0),
        SHTrial(id: 17, band: 1, name: "Cutbank",
                brief: "Thin slats bridge badly. Keep the combined centre honest.",
                stones: [15, 17, 10, 9, 4, 7, 1], kind: .margin, stars: [22, 38, 52], wind: 0),
        SHTrial(id: 18, band: 1, name: "Riser Row",
                brief: "Eight quarry stones. Each one adds a little; none of them adds much.",
                stones: [17, 14, 12, 10, 9, 2, 6, 0], kind: .height, stars: [108, 158, 204], wind: 0),
        SHTrial(id: 19, band: 1, name: "Quarry Wind",
                brief: "Open ground, steady breeze. Broad seats are your only defence.",
                stones: [9, 10, 15, 3, 0, 5], kind: .margin, stars: [24, 42, 58], wind: 0.045),
        SHTrial(id: 20, band: 1, name: "Broadfoot",
                brief: "Nine slabs and cobbles. The heaviest stones come first for a reason.",
                stones: [13, 16, 11, 10, 9, 15, 17, 2, 1], kind: .place, stars: [7, 8, 9], wind: 0),

        // ------------------------------------------------ Band 2 — River Bend
        SHTrial(id: 21, band: 2, name: "Slack Water",
                brief: "River stones meet a stack on a line. Tip them until they find a second point.",
                stones: [9, 19, 22, 25, 4], kind: .place, stars: [3, 4, 5], wind: 0),
        SHTrial(id: 22, band: 2, name: "The Bend",
                brief: "Round on round. There is a seat in there somewhere.",
                stones: [10, 18, 22, 26, 0, 3], kind: .height, stars: [98, 142, 184], wind: 0),
        SHTrial(id: 23, band: 2, name: "Rolled Smooth",
                brief: "Nothing flat in the whole set except the plate you start on.",
                stones: [11, 20, 19, 25, 22, 5], kind: .margin, stars: [26, 46, 64], wind: 0),
        SHTrial(id: 24, band: 2, name: "Riffle",
                brief: "Seven stones out of fast water. They settle quickly — read them quickly.",
                stones: [9, 26, 22, 19, 25, 18, 4], kind: .place, stars: [5, 6, 7], wind: 0),
        SHTrial(id: 25, band: 2, name: "Otter Line",
                brief: "Long ovals laid across the grain give more height than they look worth.",
                stones: [15, 18, 24, 20, 23, 1], kind: .height, stars: [122, 178, 230], wind: 0),
        SHTrial(id: 26, band: 2, name: "Oxbow",
                brief: "The dense little bead is the problem. Place it low.",
                stones: [10, 25, 22, 19, 26, 0, 8, 3], kind: .place, stars: [6, 7, 8], wind: 0),
        SHTrial(id: 27, band: 2, name: "Mill Race",
                brief: "Seven river stones, one plate. Height, and nothing else counts.",
                stones: [11, 21, 18, 24, 20, 25, 5], kind: .height, stars: [145, 210, 272], wind: 0),
        SHTrial(id: 28, band: 2, name: "Willow Bar",
                brief: "Finish the set and finish it comfortable. Narrow seats will not do.",
                stones: [16, 24, 23, 26, 19, 22, 4, 1], kind: .margin, stars: [22, 38, 54], wind: 0),
        SHTrial(id: 29, band: 2, name: "River Wind",
                brief: "Wind down the valley, round stones underfoot. Keep the pile low and honest.",
                stones: [9, 22, 19, 25, 26, 3], kind: .margin, stars: [17, 30, 43], wind: 0.055),
        SHTrial(id: 30, band: 2, name: "Long Bend",
                brief: "Nine stones from the bend. Seat as many as the seats allow.",
                stones: [11, 23, 20, 24, 18, 26, 22, 19, 25], kind: .place, stars: [7, 8, 9], wind: 0),

        // ---------------------------------------------- Band 3 — Basalt Point
        SHTrial(id: 31, band: 3, name: "The Point",
                brief: "Your first columns. Lying down they are shims; upright they are risk.",
                stones: [9, 33, 4, 30, 0], kind: .place, stars: [3, 4, 5], wind: 0),
        SHTrial(id: 32, band: 3, name: "Black Prism",
                brief: "Six faces, no square one. Twist through the rotations before you release.",
                stones: [10, 28, 33, 3, 5], kind: .height, stars: [82, 120, 155], wind: 0),
        SHTrial(id: 33, band: 3, name: "Nine Columns",
                brief: "Column Nine is ninety points of stone. Stand it and the trial is done.",
                stones: [11, 33, 27, 0, 4], kind: .height, stars: [70, 105, 136], wind: 0),
        SHTrial(id: 34, band: 3, name: "Cinder",
                brief: "The spire leaves a margin measured in single points. Earn some back.",
                stones: [15, 29, 33, 22, 5, 1], kind: .margin, stars: [23, 40, 56], wind: 0),
        SHTrial(id: 35, band: 3, name: "Anvil",
                brief: "The heaviest stone on the shore, and it is not the first one you get.",
                stones: [16, 31, 33, 30, 19, 3], kind: .place, stars: [4, 5, 6], wind: 0),
        SHTrial(id: 36, band: 3, name: "Fissure",
                brief: "Thin pins between round stones. Every level is a decision.",
                stones: [11, 20, 30, 28, 33, 4, 0], kind: .place, stars: [5, 6, 7], wind: 0),
        SHTrial(id: 37, band: 3, name: "Storm Tooth",
                brief: "Two big columns and a hexagonal foot. Take everything they offer.",
                stones: [13, 18, 34, 33, 29, 5], kind: .height, stars: [135, 198, 255], wind: 0),
        SHTrial(id: 38, band: 3, name: "Dyke",
                brief: "A hundred points of splinter on a twenty point base. Good luck.",
                stones: [11, 22, 32, 33, 28, 3, 1], kind: .height, stars: [142, 206, 266], wind: 0),
        SHTrial(id: 39, band: 3, name: "Windward Point",
                brief: "The headland gale, at full strength, against basalt. Stay low, stay wide.",
                stones: [16, 20, 33, 28, 30, 4], kind: .margin, stars: [20, 35, 50], wind: 0.075),
        SHTrial(id: 40, band: 3, name: "The Cairn",
                brief: "Nine stones from four shores and a working wind. The last one on the list.",
                stones: [11, 13, 19, 33, 28, 31, 29, 34, 35], kind: .place, stars: [7, 8, 9], wind: 0.040)
    ]

    static func trial(_ id: Int) -> SHTrial? {
        all.first(where: { $0.id == id })
    }

    static func band(_ b: Int) -> [SHTrial] {
        all.filter { $0.band == b }
    }

    static var maxStars: Int { all.count * 3 }
}
