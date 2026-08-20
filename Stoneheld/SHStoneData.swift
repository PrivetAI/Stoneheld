import CoreGraphics
import Foundation

// MARK: - The four shores

struct SHShore {
    let index: Int
    let name: String
    let blurb: String
    let range: ClosedRange<Int>
}

enum SHShores {
    static let all: [SHShore] = [
        SHShore(index: 0, name: "Pebble Cove",
                blurb: "Small, round and forgiving. Wide bellies, gentle seats — the stones you learn on.",
                range: 0...8),
        SHShore(index: 1, name: "Slate Quarry",
                blurb: "Flat and broad. Poor towers, superb platforms: a slate resets a wobbling cairn.",
                range: 9...17),
        SHShore(index: 2, name: "River Bend",
                blurb: "Water-smoothed ovals. Heavy for their size and they meet the stack on almost nothing.",
                range: 18...26),
        SHShore(index: 3, name: "Basalt Point",
                blurb: "Angular columns off the headland. Tall, dense and tippy — the last thing you place.",
                range: 27...35)
    ]

    static func shore(of kindID: Int) -> SHShore {
        for s in all where s.range.contains(kindID) { return s }
        return all[0]
    }
}

// MARK: - Catalogue
//
// Every outline below is authored by hand: irregular vertex counts, asymmetric
// silhouettes, flat quarry bottoms, rolled river bellies, tapered basalt spines.
// Nothing here is a generated regular polygon.

enum SHCatalog {

    private static func pts(_ v: [Double]) -> [CGPoint] {
        var out: [CGPoint] = []
        out.reserveCapacity(v.count / 2)
        var i = 0
        while i + 1 < v.count {
            out.append(CGPoint(x: v[i], y: v[i + 1]))
            i += 2
        }
        return out
    }

    static let stones: [SHStoneKind] = {
        var list: [SHStoneKind] = []

        func add(_ name: String, _ shore: Int, _ v: [Double], _ density: Double,
                 _ tint: Int, _ tex: SHTexture, _ unlock: SHUnlock, _ note: String) {
            list.append(SHStoneKind(id: list.count, name: name, shore: shore,
                                    poly: SHPolygon(pts(v)), density: density,
                                    tint: tint, texture: tex, unlock: unlock, note: note))
        }

        // ---------------------------------------------------------------- 0..8
        // Pebble Cove — small, round, forgiving
        add("Tide Bead", 0,
            [20, -2, 17, 9, 8, 17, -3, 19, -14, 13, -20, 3, -18, -8, -9, -16, 2, -18, 13, -13],
            1.00, 1, .speckle, .start,
            "The first stone most people ever balance. Broad belly, no bad side.")
        add("Gull Egg", 0,
            [23, 1, 18, 12, 7, 19, -6, 20, -17, 13, -22, 2, -19, -9, -8, -16, 5, -18, 17, -11],
            1.02, 7, .speckle, .start,
            "Pale and slightly long. Lay it across a slate and it will not argue.")
        add("Pale Shingle", 0,
            [26, -3, 21, 7, 9, 13, -5, 15, -18, 10, -25, 1, -21, -8, -9, -13, 6, -14, 19, -10],
            0.96, 4, .banding, .start,
            "Flattened by a thousand tides. The widest seat in the cove.")
        add("Foam Nub", 0,
            [16, 0, 13, 8, 5, 14, -5, 14, -14, 8, -17, 0, -13, -8, -4, -13, 6, -12, 13, -7],
            0.98, 1, .speckle, .start,
            "Small enough to shim a crooked joint without adding real weight.")
        add("Cove Button", 0,
            [19, -4, 17, 5, 10, 12, -1, 15, -12, 11, -18, 3, -17, -6, -8, -13, 4, -14, 14, -11],
            1.05, 0, .grain, .start,
            "Squat and a touch heavy. Good on top of a wobble to press it flat.")
        add("Salt Pearl", 0,
            [21, 2, 16, 11, 6, 16, -6, 17, -16, 11, -21, 1, -17, -9, -6, -15, 6, -15, 16, -9],
            0.94, 7, .rings, .start,
            "Nearly round. Whatever way it lands it lands on a curve.")
        add("Wrack Pebble", 0,
            [24, -1, 20, 9, 10, 16, -3, 18, -15, 13, -23, 3, -20, -7, -10, -14, 3, -16, 16, -11],
            1.01, 3, .speckle, .start,
            "Green-grey from the weed line. Slightly lopsided — turn it and see.")
        add("Barnacle Bit", 0,
            [18, -6, 18, 4, 11, 12, 0, 16, -11, 12, -18, 4, -18, -6, -10, -13, 2, -15, 12, -12],
            1.08, 5, .speckle, .start,
            "Rough on one shoulder. Seats hard, holds well, ugly and useful.")
        add("Low Water Nib", 0,
            [15, -1, 12, 7, 4, 12, -5, 12, -13, 7, -15, -1, -12, -8, -4, -12, 5, -11, 12, -7],
            0.92, 1, .grain, .start,
            "The lightest thing on the shore. It barely changes a centre of mass.")

        // -------------------------------------------------------------- 9..17
        // Slate Quarry — flat, wide, stable platforms
        add("Splitfoot Slab", 1,
            [48, -4, 44, 6, 22, 11, -6, 12, -30, 9, -47, 2, -49, -6, -32, -11, -4, -12, 26, -10],
            1.14, 2, .banding, .start,
            "A metre of seat in a hand-sized stone. Everything after this is easier.")
        add("Grey Ledger", 1,
            [40, -5, 36, 5, 16, 9, -10, 10, -33, 7, -41, -1, -38, -8, -14, -11, 12, -11, 32, -9],
            1.12, 0, .banding, .start,
            "Reads like a shelf. Level it once and it stays level.")
        add("Quarry Plate", 1,
            [55, -3, 50, 6, 26, 11, -4, 12, -32, 9, -53, 3, -55, -5, -34, -10, -2, -11, 30, -9],
            1.18, 2, .banding, .placed(20),
            "The broadest plate in the quarry. It will carry a whole second cairn.")
        add("Cleft Shelf", 1,
            [35, -6, 33, 4, 14, 10, -12, 11, -31, 6, -36, -3, -30, -10, -6, -13, 18, -12, 31, -10],
            1.10, 5, .veins, .placed(35),
            "Split along an old fault. One end sits proud — use it or lose the seat.")
        add("Broadfoot", 1,
            [52, -6, 46, 4, 20, 10, -10, 11, -36, 8, -51, 1, -50, -8, -28, -13, 4, -13, 34, -11],
            1.16, 4, .grain, .stars(6),
            "Heavy and wide. Down low it anchors; up high it is a liability.")
        add("Fault Table", 1,
            [44, -8, 41, 3, 18, 9, -8, 10, -32, 6, -44, -2, -40, -10, -16, -14, 12, -14, 34, -12],
            1.13, 2, .veins, .placed(55),
            "Thicker than it looks. Gives a taller platform for the same footprint.")
        add("Cutbank Slat", 1,
            [38, -4, 34, 5, 12, 9, -14, 9, -34, 5, -38, -3, -32, -9, -8, -11, 16, -10, 32, -8],
            1.06, 7, .banding, .stars(12),
            "Thin, pale, surprisingly light. The bridging stone of the quarry.")
        add("Stack Plinth", 1,
            [46, -9, 42, 3, 20, 10, -8, 12, -34, 8, -46, 0, -44, -10, -20, -15, 10, -15, 34, -13],
            1.20, 0, .grain, .placed(80),
            "Cut for the base of something. Densest slab on the shore.")
        add("Hewn Riser", 1,
            [30, -9, 28, 3, 12, 10, -10, 11, -27, 6, -31, -3, -26, -11, -6, -14, 14, -14, 27, -12],
            1.15, 5, .veins, .stars(20),
            "Short and chunky. Adds height without adding a wide silhouette.")

        // ------------------------------------------------------------- 18..26
        // River Bend — smooth ovals, narrow contacts
        add("Otter Stone", 2,
            [34, 0, 31, 8, 23, 15, 11, 19, -3, 20, -17, 17, -28, 11, -34, 2, -32, -7, -22, -14,
             -8, -18, 7, -18, 21, -13, 31, -7],
            0.98, 9, .rings, .placed(30),
            "Rolled by the river until nothing on it is flat. Meets a stack on a line.")
        add("Slack Water", 2,
            [28, 1, 25, 9, 17, 15, 5, 18, -8, 18, -20, 13, -27, 5, -27, -4, -19, -12, -6, -16,
             8, -15, 20, -10, 27, -4],
            0.96, 6, .rings, .placed(50),
            "From the still side of the bend. Even curvature, no help anywhere.")
        add("Eddy Loaf", 2,
            [38, -1, 34, 9, 24, 16, 10, 20, -6, 21, -21, 16, -32, 9, -37, 0, -33, -9, -20, -15,
             -3, -17, 14, -15, 29, -9],
            1.00, 4, .grain, .stars(15),
            "Big, bland and round. Placed flat it is a fine landing for basalt.")
        add("Millrace Egg", 2,
            [30, 2, 27, 11, 18, 17, 5, 20, -9, 19, -22, 13, -29, 4, -28, -6, -18, -13, -4, -17,
             11, -15, 23, -9, 29, -3],
            1.04, 9, .rings, .placed(75),
            "Slightly pointed at one end. That end is where the cairn goes wrong.")
        add("Silt Round", 2,
            [24, 0, 21, 8, 13, 14, 2, 16, -10, 15, -20, 9, -24, 1, -21, -7, -12, -13, -1, -15,
             11, -12, 20, -6],
            0.90, 7, .speckle, .placed(100),
            "Light for its size. Buys you height cheaply if the seat is honest.")
        add("Bankside Roll", 2,
            [42, -2, 38, 7, 27, 14, 12, 18, -4, 19, -20, 15, -33, 8, -41, -1, -36, -9, -22, -15,
             -4, -17, 14, -14, 30, -9],
            1.02, 6, .veins, .stars(28),
            "Longest oval on the bend. Lay it across the grain of the stack below.")
        add("Willow Bar", 2,
            [36, 1, 32, 10, 21, 16, 7, 19, -8, 19, -22, 14, -32, 6, -35, -3, -28, -11, -13, -16,
             4, -16, 20, -12, 31, -6],
            0.99, 3, .grain, .placed(130),
            "Cut long by the current. Rotate it upright for a nasty, narrow riser.")
        add("Oxbow Bead", 2,
            [26, -1, 23, 8, 14, 14, 2, 17, -11, 16, -22, 10, -26, 1, -22, -8, -11, -14, 2, -16,
             15, -12, 23, -7],
            1.06, 9, .rings, .stars(38),
            "Dense little river stone. Small footprint, real weight — mind the level below.")
        add("Riffle Cobble", 2,
            [32, 0, 29, 9, 19, 15, 6, 18, -8, 18, -21, 12, -30, 4, -30, -5, -20, -13, -6, -16,
             9, -14, 23, -8],
            1.01, 6, .speckle, .placed(165),
            "Pulled from fast water. Whichever way it settles, it settles quickly.")

        // ------------------------------------------------------------- 27..35
        // Basalt Point — angular columns, tall and tippy
        add("Column Nine", 3,
            [14, 44, 6, 48, -8, 45, -15, 36, -13, -30, -6, -44, 7, -46, 15, -34],
            1.32, 8, .banding, .placed(60),
            "A ninety-point column. Upright it is the tallest single gain in the game.")
        add("Black Prism", 3,
            [12, 30, 2, 34, -10, 29, -14, 18, -12, -24, -3, -32, 9, -29, 14, -16],
            1.36, 8, .veins, .stars(24),
            "Six faces, none of them square. Every rotation gives a different seat.")
        add("Cinder Spire", 3,
            [9, 40, 0, 46, -10, 38, -13, 22, -10, -26, -1, -36, 10, -31, 13, -14],
            1.28, 2, .grain, .placed(95),
            "Narrow and tapered. The margin it leaves you is measured in single points.")
        add("Fissure Pin", 3,
            [8, 26, 0, 31, -9, 25, -11, 10, -9, -22, -1, -29, 8, -24, 11, -8],
            1.30, 8, .veins, .placed(125),
            "Short column, thin as a wrist. Best used lying down as a shim.")
        add("Anvil Fang", 3,
            [17, 20, 5, 26, -10, 21, -18, 8, -15, -20, -4, -27, 12, -24, 18, -6],
            1.40, 0, .grain, .stars(45),
            "Heaviest stone on the point. Low down it settles a cairn like a hammer.")
        add("Dyke Splinter", 3,
            [10, 48, 1, 53, -9, 46, -12, 30, -9, -34, 0, -42, 9, -37, 12, -16],
            1.26, 2, .banding, .placed(160),
            "Split from a basalt dyke. A hundred points tall on a twenty point base.")
        add("Hexfoot", 3,
            [20, 16, 8, 22, -8, 20, -19, 10, -19, -10, -8, -20, 8, -21, 19, -11],
            1.34, 8, .rings, .stars(60),
            "The only forgiving thing on the headland — a genuine hexagonal foot.")
        add("Storm Tooth", 3,
            [13, 36, 3, 42, -9, 35, -14, 20, -11, -28, -2, -36, 10, -31, 15, -12],
            1.31, 5, .veins, .placed(210),
            "Bent slightly along its length. It will never stand truly straight.")
        add("Basalt Nail", 3,
            [7, 34, 0, 39, -8, 33, -10, 18, -8, -28, -1, -34, 7, -29, 10, -12],
            1.38, 8, .banding, .stars(80),
            "Seventy points of stone on a fourteen point contact. The crowning piece.")

        return list
    }()

    static func kind(_ id: Int) -> SHStoneKind {
        if id >= 0 && id < stones.count { return stones[id] }
        return stones[0]
    }

    static var count: Int { stones.count }

    // The plinth the whole cairn stands on. Slightly domed so the first stone
    // has an honest, non-flat seat.
    static let base: SHPolygon = SHPolygon(pts(
        [96, -4, 88, 3, 50, 7, 18, 8, -18, 8, -52, 6, -90, 2, -96, -6, -84, -46, 84, -46]
    ))
    static let baseTopY: Double = 8
}
