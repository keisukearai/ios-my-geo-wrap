#if canImport(UIKit)
import SwiftUI
import SpriteKit
import Combine

// MARK: - Deterministic RNG

struct AnimalLCG {
    var state: UInt64
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(1 << 53)
    }
}

// MARK: - Stone Seed (440 stones)

struct AnimalStoneSeed {
    let type: Int        // 0=hex 1=diamond 2=tri 3=circle 4=penta
    let size: CGFloat    // 0.875..2.625
    let initRot: Double
    let rotSpeed: Double
    let oscPhase: Double
    let oscFreq: Double
    let colorOffset: Double
    let glowEnabled: Bool
}

let animalStonesSeed: [AnimalStoneSeed] = (0..<440).map { i in
    let f = Double(i)
    return AnimalStoneSeed(
        type:        i % 5,
        size:        CGFloat(0.875 + (f.truncatingRemainder(dividingBy: 5)) * 0.4375),
        initRot:     f * 0.70,
        rotSpeed:    0.04 + (f.truncatingRemainder(dividingBy: 5)) * 0.02,
        oscPhase:    f * 1.6180,
        oscFreq:     0.3 + (f.truncatingRemainder(dividingBy: 7)) * 0.08,
        colorOffset: (f.truncatingRemainder(dividingBy: 20)) * 0.025,
        glowEnabled: i % 4 == 0
    )
}

// MARK: - Stone Paths (CGPath for SpriteKit)

func animalStoneCGPath(type: Int, size s: CGFloat) -> CGPath {
    let p = CGMutablePath()
    switch type {
    case 0: // hex
        for i in 0..<6 {
            let a = CGFloat(i) * .pi / 3
            let pt = CGPoint(x: cos(a)*s, y: sin(a)*s)
            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
    case 1: // diamond
        p.move(to:    CGPoint(x:  0,      y:  s))
        p.addLine(to: CGPoint(x:  s*0.55, y:  0))
        p.addLine(to: CGPoint(x:  0,      y: -s))
        p.addLine(to: CGPoint(x: -s*0.55, y:  0))
    case 2: // triangle
        p.move(to:    CGPoint(x:  0,      y:  s))
        p.addLine(to: CGPoint(x:  s*0.87, y: -s*0.5))
        p.addLine(to: CGPoint(x: -s*0.87, y: -s*0.5))
    case 3: // circle
        return CGPath(ellipseIn: CGRect(x: -s, y: -s, width: s*2, height: s*2), transform: nil)
    default: // pentagon
        for i in 0..<5 {
            let a = CGFloat(i) * .pi * 2 / 5 - .pi / 2
            let pt = CGPoint(x: cos(a)*s, y: sin(a)*s)
            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
    }
    p.closeSubpath()
    return p
}

// MARK: - Stone Paths (SwiftUI Path for ImageRenderer)

func animalStoneSwiftPath(type: Int, size s: Double) -> Path {
    switch type {
    case 0:
        return Path { p in
            for i in 0..<6 {
                let a = Double(i) * .pi / 3
                let pt = CGPoint(x: cos(a)*s, y: sin(a)*s)
                i == 0 ? p.move(to: pt) : p.addLine(to: pt)
            }
            p.closeSubpath()
        }
    case 1:
        return Path { p in
            p.move(to: CGPoint(x: 0, y: s))
            p.addLine(to: CGPoint(x: s*0.55, y: 0))
            p.addLine(to: CGPoint(x: 0, y: -s))
            p.addLine(to: CGPoint(x: -s*0.55, y: 0))
            p.closeSubpath()
        }
    case 2:
        return Path { p in
            p.move(to: CGPoint(x: 0, y: s))
            p.addLine(to: CGPoint(x: s*0.87, y: -s*0.5))
            p.addLine(to: CGPoint(x: -s*0.87, y: -s*0.5))
            p.closeSubpath()
        }
    case 3:
        return Path(ellipseIn: CGRect(x: -s, y: -s, width: s*2, height: s*2))
    default:
        return Path { p in
            for i in 0..<5 {
                let a = Double(i) * .pi * 2 / 5 - .pi / 2
                let pt = CGPoint(x: cos(a)*s, y: sin(a)*s)
                i == 0 ? p.move(to: pt) : p.addLine(to: pt)
            }
            p.closeSubpath()
        }
    }
}

// MARK: - Body Segment

private struct AnimalSegment {
    let weight: Double
    let sampler: (inout AnimalLCG) -> CGPoint

    static func circle(cx: Double, cy: Double, r: Double, weight: Double) -> Self {
        .init(weight: weight) { rng in
            let a = rng.next() * .pi * 2
            let d = r * sqrt(rng.next())
            return CGPoint(x: cx + cos(a)*d, y: cy + sin(a)*d)
        }
    }
    static func ellipse(cx: Double, cy: Double, rx: Double, ry: Double, weight: Double) -> Self {
        .init(weight: weight) { rng in
            let a = rng.next() * .pi * 2
            let d = sqrt(rng.next())
            return CGPoint(x: cx + cos(a)*rx*d, y: cy + sin(a)*ry*d)
        }
    }
    static func line(x1: Double, y1: Double, x2: Double, y2: Double,
                     halfW: Double, weight: Double) -> Self {
        let dx = x2-x1, dy = y2-y1
        let len = max(sqrt(dx*dx + dy*dy), 1e-6)
        let nx = -dy/len, ny = dx/len
        return .init(weight: weight) { rng in
            let t  = rng.next()
            let sc = (rng.next() * 2 - 1) * halfW
            return CGPoint(x: x1 + dx*t + nx*sc, y: y1 + dy*t + ny*sc)
        }
    }

    // 輪郭寄り楕円: 外側80〜100%の帯状領域に点を均等配置
    static func ellipseBorder(cx: Double, cy: Double, rx: Double, ry: Double, weight: Double) -> Self {
        .init(weight: weight) { rng in
            let a = rng.next() * .pi * 2
            let d = sqrt(0.6400 + rng.next() * 0.3600)  // r=0.80..1.0
            return CGPoint(x: cx + cos(a)*rx*d, y: cy + sin(a)*ry*d)
        }
    }

    // 輪郭寄り円
    static func circleBorder(cx: Double, cy: Double, r: Double, weight: Double) -> Self {
        .init(weight: weight) { rng in
            let a = rng.next() * .pi * 2
            let d = sqrt(0.6400 + rng.next() * 0.3600)
            return CGPoint(x: cx + cos(a)*r*d, y: cy + sin(a)*r*d)
        }
    }

}

// MARK: - AnimalKind

enum AnimalKind: String, CaseIterable {
    case human    = "HUMAN"
    case giraffe  = "GIRAFFE"
    case elephant = "ELEPHANT"
    case eagle    = "EAGLE"
    case whale    = "WHALE"

    // Per-animal uniform scale: giraffe/elephant shrunk to match HUMAN's height span
    private var scale: Double {
        switch self {
        case .human:    return 1.00
        case .giraffe:  return 0.77
        case .elephant: return 1.05
        case .eagle:    return 1.10
        case .whale:    return 0.82
        }
    }

    // Rx = width*0.38, Ry = height*0.38 → portrait-optimized scaling
    func buildTargets(count: Int, seed: UInt64, in size: CGSize) -> [CGPoint] {
        let Rx = Double(size.width)  * 0.38 * scale
        let Ry = Double(size.height) * 0.38 * scale
        let cx = Double(size.width)  / 2
        let cy = Double(size.height) / 2

        var rng  = AnimalLCG(state: seed)
        let segs = segments
        let totalW = segs.reduce(0.0) { $0 + $1.weight }
        guard totalW > 0 else { return Array(repeating: CGPoint(x: cx, y: cy), count: count) }

        var pts: [CGPoint] = []
        pts.reserveCapacity(count)
        var remaining = count

        for (idx, seg) in segs.enumerated() {
            let n = idx == segs.count - 1
                ? max(0, remaining)
                : max(0, Int((seg.weight / totalW * Double(count)).rounded()))
            for _ in 0..<n {
                let np = seg.sampler(&rng)
                pts.append(CGPoint(x: cx + np.x * Rx, y: cy + np.y * Ry))
            }
            remaining -= n
        }
        while pts.count < count { pts.append(CGPoint(x: cx, y: cy)) }
        return Array(pts.prefix(count))
    }

    private var segments: [AnimalSegment] {
        switch self {
        case .human:    return Self.humanSegs
        case .giraffe:  return Self.giraffeSegs
        case .elephant: return Self.elephantSegs
        case .eagle:    return Self.eagleSegs
        case .whale:    return Self.whaleSegs
        }
    }

    // MARK: Human – normalized [-1..1], SpriteKit y-up
    private static let humanSegs: [AnimalSegment] = [
        .circle (cx:  0,     cy:  0.60, r:  0.12,              weight: 22),
        .ellipse(cx:  0,     cy:  0.46, rx: 0.035, ry: 0.06,   weight:  8),
        .ellipse(cx:  0,     cy:  0.25, rx: 0.14,  ry: 0.18,   weight: 48),
        .line(x1:-0.10, y1: 0.38, x2:-0.26, y2: 0.14, halfW:0.04, weight:20),
        .line(x1: 0.10, y1: 0.38, x2: 0.26, y2: 0.14, halfW:0.04, weight:20),
        .line(x1:-0.26, y1: 0.14, x2:-0.30, y2:-0.02, halfW:0.03, weight:12),
        .line(x1: 0.26, y1: 0.14, x2: 0.30, y2:-0.02, halfW:0.03, weight:12),
        .line(x1:-0.05, y1: 0.07, x2:-0.13, y2:-0.23, halfW:0.05, weight:22),
        .line(x1: 0.05, y1: 0.07, x2: 0.13, y2:-0.23, halfW:0.05, weight:22),
        .line(x1:-0.13, y1:-0.23, x2:-0.16, y2:-0.60, halfW:0.04, weight:18),
        .line(x1: 0.13, y1:-0.23, x2: 0.16, y2:-0.60, halfW:0.04, weight:18),
        .ellipse(cx:-0.20, cy:-0.64, rx:0.07, ry:0.03, weight: 6),
        .ellipse(cx: 0.20, cy:-0.64, rx:0.07, ry:0.03, weight: 6),
        .ellipse(cx:  0,   cy:  0.07, rx:0.10, ry:0.05, weight: 6),
    ]

    // MARK: Giraffe (side view, facing right)
    private static let giraffeSegs: [AnimalSegment] = [
        // Head – horizontal ellipse, top-right
        .ellipse(cx: 0.67, cy: 0.69, rx: 0.12, ry: 0.065, weight: 16),
        // Ossicones pointing up
        .line(x1: 0.60, y1: 0.75, x2: 0.59, y2: 0.86, halfW: 0.012, weight: 3),
        .line(x1: 0.72, y1: 0.75, x2: 0.71, y2: 0.86, halfW: 0.012, weight: 3),
        // Neck – 80% of original length, starting from enlarged body front-top
        .line(x1: 0.35, y1: 0.02, x2: 0.61, y2: 0.63, halfW: 0.065, weight: 58),
        // Body – enlarged horizontal ellipse
        .ellipse(cx: -0.15, cy: -0.20, rx: 0.62, ry: 0.22, weight: 80),
        // Front legs (right side of body)
        .line(x1: 0.16, y1: -0.42, x2: 0.18, y2: -0.86, halfW: 0.040, weight: 24),
        .line(x1: 0.04, y1: -0.42, x2: 0.06, y2: -0.86, halfW: 0.040, weight: 24),
        // Back legs (left side of body)
        .line(x1:-0.30, y1: -0.42, x2:-0.29, y2: -0.86, halfW: 0.040, weight: 24),
        .line(x1:-0.44, y1: -0.42, x2:-0.43, y2: -0.86, halfW: 0.040, weight: 24),
        // Tail hanging from rear
        .line(x1:-0.68, y1: -0.17, x2:-0.77, y2: -0.38, halfW: 0.014, weight: 5),
        // Hooves
        .ellipse(cx: 0.18, cy: -0.90, rx: 0.045, ry: 0.020, weight: 3),
        .ellipse(cx: 0.06, cy: -0.90, rx: 0.045, ry: 0.020, weight: 3),
        .ellipse(cx:-0.29, cy: -0.90, rx: 0.045, ry: 0.020, weight: 3),
        .ellipse(cx:-0.43, cy: -0.90, rx: 0.045, ry: 0.020, weight: 3),
    ]

    // MARK: Elephant (side view, facing right)
    private static let elephantSegs: [AnimalSegment] = [
        // ── 胴体: コンパクト横楕円 ──────────────────────────────────────
        .ellipse      (cx:  0.06, cy:  0.08, rx: 0.46, ry: 0.26, weight: 80),
        .ellipseBorder(cx:  0.06, cy:  0.08, rx: 0.46, ry: 0.26, weight: 36),

        // ── 頭: 大きな円 ─────────────────────────────────────────────────
        .circle      (cx:  0.58, cy:  0.28, r:  0.20, weight: 32),
        .circleBorder(cx:  0.58, cy:  0.28, r:  0.20, weight: 15),

        // ── 耳: 大型扇形、頭後上部 ───────────────────────────────────────
        .ellipse      (cx:  0.44, cy:  0.42, rx: 0.15, ry: 0.24, weight: 50),
        .ellipseBorder(cx:  0.44, cy:  0.42, rx: 0.15, ry: 0.24, weight: 25),

        // ── 首 ────────────────────────────────────────────────────────────
        .ellipse(cx:  0.42, cy:  0.20, rx: 0.14, ry: 0.12, weight: 14),

        // ── 鼻(上段): 太く、頭前面から斜め前下へ ────────────────────────
        .line(x1: 0.76, y1:  0.14, x2: 0.88, y2: -0.10, halfW: 0.095, weight: 40),
        // ── 鼻(中段): さらに下へカーブ ──────────────────────────────────
        .line(x1: 0.88, y1: -0.10, x2: 0.82, y2: -0.38, halfW: 0.075, weight: 30),
        // ── 鼻(先端): 内向きにカール ─────────────────────────────────────
        .line(x1: 0.82, y1: -0.38, x2: 0.66, y2: -0.55, halfW: 0.055, weight: 20),

        // ── 牙 ────────────────────────────────────────────────────────────
        .line(x1: 0.74, y1:  0.13, x2: 0.91, y2:  0.04, halfW: 0.022, weight:  7),

        // ── 前足 ──────────────────────────────────────────────────────────
        .line(x1: 0.36, y1: -0.18, x2: 0.38, y2: -0.43, halfW: 0.078, weight: 30),
        .line(x1: 0.20, y1: -0.18, x2: 0.22, y2: -0.43, halfW: 0.078, weight: 30),
        // ── 後足 ──────────────────────────────────────────────────────────
        .line(x1:-0.14, y1: -0.18, x2:-0.12, y2: -0.43, halfW: 0.078, weight: 30),
        .line(x1:-0.30, y1: -0.18, x2:-0.28, y2: -0.43, halfW: 0.078, weight: 30),

        // ── 尻尾 ──────────────────────────────────────────────────────────
        .line(x1:-0.50, y1:  0.12, x2:-0.60, y2: -0.06, halfW: 0.018, weight:  5),

        // ── 蹄 ────────────────────────────────────────────────────────────
        .ellipse(cx:  0.38, cy: -0.47, rx: 0.088, ry: 0.030, weight: 4),
        .ellipse(cx:  0.22, cy: -0.47, rx: 0.088, ry: 0.030, weight: 4),
        .ellipse(cx: -0.12, cy: -0.47, rx: 0.088, ry: 0.030, weight: 4),
        .ellipse(cx: -0.28, cy: -0.47, rx: 0.088, ry: 0.030, weight: 4),

        // ── 目 ────────────────────────────────────────────────────────────
        .circle(cx: 0.66, cy: 0.33, r: 0.018, weight: 2),
    ]

    // MARK: Eagle (front view, wings fully spread, soaring)
    // Coordinate reference:
    //   center=(0,0), x: ±1 maps to screen half-width * scale
    //   y-up; head at top, tail at bottom, wings left/right
    private static let eagleSegs: [AnimalSegment] = [
        // Head – small circle, top center
        .circle(cx: 0.00, cy: 0.60, r: 0.09, weight: 18),
        // Beak – short hook angling down-forward (hooked raptor bill)
        .line(x1: 0.05, y1: 0.54, x2: 0.14, y2: 0.46, halfW: 0.022, weight: 5),
        // Neck – short connector between head and body
        .ellipse(cx: 0.00, cy: 0.46, rx: 0.07, ry: 0.08, weight: 10),
        // Body – compact oval at center
        .ellipse(cx: 0.00, cy: 0.20, rx: 0.18, ry: 0.22, weight: 52),
        // Left wing inner (shoulder → elbow) – broad
        .line(x1: -0.16, y1: 0.26, x2: -0.62, y2: 0.12, halfW: 0.095, weight: 60),
        // Left wing outer (elbow → tip) – tapered
        .line(x1: -0.62, y1: 0.12, x2: -0.90, y2: -0.06, halfW: 0.060, weight: 38),
        // Right wing inner
        .line(x1:  0.16, y1: 0.26, x2:  0.62, y2: 0.12, halfW: 0.095, weight: 60),
        // Right wing outer
        .line(x1:  0.62, y1: 0.12, x2:  0.90, y2: -0.06, halfW: 0.060, weight: 38),
        // Primary feathers (wing slots) – left tip, 3 finger-like lines
        .line(x1: -0.78, y1: 0.00, x2: -0.83, y2: -0.18, halfW: 0.020, weight: 8),
        .line(x1: -0.84, y1: -0.03, x2: -0.91, y2: -0.20, halfW: 0.020, weight: 8),
        .line(x1: -0.90, y1: -0.06, x2: -0.97, y2: -0.23, halfW: 0.020, weight: 8),
        // Primary feathers – right tip
        .line(x1:  0.78, y1: 0.00, x2:  0.83, y2: -0.18, halfW: 0.020, weight: 8),
        .line(x1:  0.84, y1: -0.03, x2:  0.91, y2: -0.20, halfW: 0.020, weight: 8),
        .line(x1:  0.90, y1: -0.06, x2:  0.97, y2: -0.23, halfW: 0.020, weight: 8),
        // Tail – broad wedge fan, 3 lines spreading downward
        .line(x1: -0.12, y1: -0.02, x2: -0.24, y2: -0.40, halfW: 0.060, weight: 16),
        .line(x1:  0.00, y1: -0.02, x2:  0.00, y2: -0.46, halfW: 0.060, weight: 16),
        .line(x1:  0.12, y1: -0.02, x2:  0.24, y2: -0.40, halfW: 0.060, weight: 16),
        // Talons – small ellipses below tail
        .ellipse(cx: -0.10, cy: -0.56, rx: 0.06, ry: 0.022, weight: 4),
        .ellipse(cx:  0.10, cy: -0.56, rx: 0.06, ry: 0.022, weight: 4),
    ]

    // MARK: Whale (side view, facing right, with V-shaped water spout)
    // 胴体を大型化 (rx=0.65, ry=0.30)、潮吹きは細い二股型
    private static let whaleSegs: [AnimalSegment] = [
        // ── 胴体メイン（大型横楕円）────────────────────────────────────────
        .ellipse      (cx:  0.00, cy: -0.08, rx: 0.65, ry: 0.30, weight: 100),
        .ellipseBorder(cx:  0.00, cy: -0.08, rx: 0.65, ry: 0.30, weight:  38),

        // ── 頭部（前方に重ねて丸い先端を形成）──────────────────────────────
        .ellipse      (cx:  0.58, cy: -0.04, rx: 0.25, ry: 0.23, weight: 52),
        .ellipseBorder(cx:  0.58, cy: -0.04, rx: 0.25, ry: 0.23, weight: 22),

        // ── 口のライン ────────────────────────────────────────────────────
        .line(x1: 0.46, y1: -0.16, x2: 0.80, y2: -0.21, halfW: 0.016, weight: 5),

        // ── 尾柄（テールストック）──────────────────────────────────────────
        .line(x1: -0.62, y1: -0.08, x2: -0.80, y2: -0.10, halfW: 0.072, weight: 16),

        // ── 尾びれ（上葉）──────────────────────────────────────────────────
        .line(x1: -0.80, y1: -0.10, x2: -0.96, y2:  0.18, halfW: 0.038, weight: 14),
        // ── 尾びれ（下葉）──────────────────────────────────────────────────
        .line(x1: -0.80, y1: -0.10, x2: -0.94, y2: -0.40, halfW: 0.038, weight: 14),

        // ── 背びれ ────────────────────────────────────────────────────────
        .line(x1:  0.12, y1:  0.22, x2:  0.06, y2:  0.42, halfW: 0.038, weight: 12),

        // ── 胸びれ ────────────────────────────────────────────────────────
        .line(x1:  0.28, y1: -0.22, x2:  0.50, y2: -0.52, halfW: 0.054, weight: 12),

        // ── 目 ────────────────────────────────────────────────────────────
        .circle(cx: 0.70, cy: 0.05, r: 0.018, weight: 2),

        // ── 潮吹き (Water Spout) – 細い二股型・1.5倍の高さ ────────────────
        // 噴気口（ブローホール）
        .circle(cx: 0.42, cy: 0.20, r: 0.022, weight: 4),
        // メイン水柱（細め）ブローホール→分岐点(0.56)
        .line(x1: 0.42, y1: 0.20, x2: 0.36, y2: 0.56, halfW: 0.025, weight: 28),
        // 二股・左
        .line(x1: 0.36, y1: 0.56, x2: 0.15, y2: 0.89, halfW: 0.018, weight: 20),
        // 二股・右
        .line(x1: 0.36, y1: 0.56, x2: 0.57, y2: 0.89, halfW: 0.018, weight: 20),
    ]
}

// MARK: - AnimalOrder
final class AnimalOrder {
    static let shared = AnimalOrder()

    private(set) var sequence: [AnimalKind] = AnimalKind.allCases.shuffled()

    private init() {}

    func reshuffle() {
        sequence = AnimalKind.allCases.shuffled()
    }

    func next(after kind: AnimalKind) -> AnimalKind {
        let idx = sequence.firstIndex(of: kind)!
        return sequence[(idx + 1) % sequence.count]
    }
}

// MARK: - AnimalFrame (for ImageRenderer / Live Photo video)

struct AnimalFrame: View {
    var t: Double
    let speed: Double
    let colorHue: Double
    let targets: [CGPoint]  // SpriteKit-space (y-up), pre-computed
    let size: CGSize

    var body: some View {
        Canvas { ctx, sz in
            ctx.fill(Path(CGRect(origin: .zero, size: sz)),
                     with: .color(Color(red: 0.03, green: 0.05, blue: 0.03)))

            for i in 0..<min(targets.count, animalStonesSeed.count) {
                let seed  = animalStonesSeed[i]
                let freq  = seed.oscFreq * (0.5 + speed * 2.0)
                let amp   = speed * 5.0
                let phase = seed.oscPhase

                // Oscillate around target; flip y for SwiftUI canvas (y-down)
                let bx = targets[i].x + sin(t * freq * .pi * 2 + phase) * amp
                let by = sz.height - targets[i].y + cos(t * freq * .pi * 2 * 0.7 + phase) * amp * 0.6

                let rot = seed.initRot + t * seed.rotSpeed
                let xf  = CGAffineTransform(translationX: bx, y: by).rotated(by: rot)
                let path = animalStoneSwiftPath(type: seed.type, size: Double(seed.size)).applying(xf)

                let hue = (colorHue + seed.colorOffset).truncatingRemainder(dividingBy: 1.0)
                ctx.fill(path,   with: .color(Color(hue: hue, saturation: 0.50, brightness: 0.88).opacity(0.75)))
                ctx.stroke(path, with: .color(.white.opacity(0.70)), lineWidth: 0.8)
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

// MARK: - AnimalScene

final class AnimalScene: SKScene {

    var animSpeed: Double = 0.5
    var colorHue: Double  = 0.5 { didSet { rebuildColors() } }

    private(set) var currentAnimal: AnimalKind = AnimalOrder.shared.sequence[0]

    private var stoneNodes:   [SKShapeNode] = []
    private var positions:    [CGPoint]     = []
    private var velocities:   [CGPoint]     = []
    private var prevTargets:  [CGPoint]     = []
    private var newTargets:   [CGPoint]     = []
    private var morphProgress: Double = 1.0
    private var morphDuration: Double { max(0.3, 3.0 - animSpeed * 2.5) }
    private let stoneCount = 440
    private var lastTime: TimeInterval = 0

    override func didMove(to view: SKView) {
        view.preferredFramesPerSecond = 30
        backgroundColor = UIColor(red: 0.03, green: 0.05, blue: 0.03, alpha: 1)
        spawnStones()
        morphTo(AnimalOrder.shared.sequence[0])
    }

    func morphTo(_ animal: AnimalKind) {
        currentAnimal = animal
        prevTargets   = positions
        newTargets    = animal.buildTargets(count: stoneCount, seed: 42, in: size)
        morphProgress = 0.0
    }

    // MARK: - Spawn

    private func spawnStones() {
        let cx = size.width  / 2
        let cy = size.height / 2
        for i in 0..<stoneCount {
            let seed  = animalStonesSeed[i]
            let path  = animalStoneCGPath(type: seed.type, size: seed.size)
            let node  = SKShapeNode(path: path)
            let angle = Double(i) * 2.3999
            let dist  = CGFloat(sqrt(Double(i + 1) / Double(stoneCount))) * min(size.width, size.height) * 0.30
            node.position  = CGPoint(x: cx + CGFloat(cos(angle))*dist,
                                     y: cy + CGFloat(sin(angle))*dist)
            node.zRotation = CGFloat(seed.initRot)
            node.lineWidth = 0.8
            node.glowWidth = seed.glowEnabled ? 1.0 : 0.0
            colorNode(node, idx: i)
            addChild(node)
            stoneNodes.append(node)
            positions.append(node.position)
            velocities.append(.zero)
        }
        prevTargets = positions
        newTargets  = positions
    }

    private func colorNode(_ node: SKShapeNode, idx i: Int) {
        let seed = animalStonesSeed[i]
        let hue  = CGFloat((colorHue + seed.colorOffset).truncatingRemainder(dividingBy: 1.0))
        let sat  = CGFloat(0.45 + Double(i % 3) * 0.10)
        let bri  = CGFloat(0.80 + Double(i % 2) * 0.12)
        node.fillColor   = UIColor(hue: hue, saturation: sat, brightness: bri, alpha: 0.75)
        node.strokeColor = UIColor(white: 1.0, alpha: 0.70)
    }

    private func rebuildColors() {
        for i in 0..<stoneNodes.count { colorNode(stoneNodes[i], idx: i) }
    }

    // MARK: - Update

    override func update(_ currentTime: TimeInterval) {
        let dt = min(currentTime - lastTime, 1.0 / 30.0)
        guard dt > 1e-6 else { lastTime = currentTime; return }
        lastTime = currentTime

        if morphProgress < 1.0 {
            morphProgress = min(1.0, morphProgress + dt / morphDuration)
        }
        let mp        = morphProgress
        let springK   = CGFloat(8.0 + animSpeed * 22.0)
        let dampCoef  = CGFloat(exp(-8.0 * dt))
        let oscAmp    = animSpeed * 5.0
        let oscSpeed  = 0.5 + animSpeed * 3.0

        for i in 0..<stoneCount {
            // Interpolated target
            let tx = prevTargets[i].x + (newTargets[i].x - prevTargets[i].x) * CGFloat(mp)
            let ty = prevTargets[i].y + (newTargets[i].y - prevTargets[i].y) * CGFloat(mp)

            // Moving target with oscillation
            let phase = animalStonesSeed[i].oscPhase
            let freq  = animalStonesSeed[i].oscFreq * oscSpeed
            let mx    = CGFloat(sin(currentTime * freq * .pi * 2 + phase) * oscAmp)
            let my    = CGFloat(cos(currentTime * freq * .pi * 2 * 0.7 + phase) * oscAmp * 0.6)

            // Spring force
            let dx = (tx + mx) - positions[i].x
            let dy = (ty + my) - positions[i].y
            velocities[i].x += dx * springK * CGFloat(dt)
            velocities[i].y += dy * springK * CGFloat(dt)

            // Damping
            velocities[i].x *= dampCoef
            velocities[i].y *= dampCoef

            // Integrate
            positions[i].x += velocities[i].x
            positions[i].y += velocities[i].y

            stoneNodes[i].position  = positions[i]
            stoneNodes[i].zRotation += CGFloat(animalStonesSeed[i].rotSpeed * dt)
        }
    }
}

// MARK: - Scene Store

private final class AnimalSceneStore: ObservableObject {
    private(set) var scene: AnimalScene?
    func scene(for size: CGSize) -> AnimalScene {
        if let s = scene { return s }
        let s = AnimalScene(size: size); s.scaleMode = .resizeFill
        scene = s; return s
    }
}

// MARK: - AnimalView

struct AnimalView: View {
    let onPickerTap: () -> Void

    @StateObject private var store    = AnimalSceneStore()
    @StateObject private var recorder = WallpaperRecorder()

    @State private var speed:    Double = 0.5
    @State private var colorHue: Double = 0.3
    @State private var showUI:   Bool   = true
    @State private var isAutoMode: Bool = false
    @State private var currentAnimal: AnimalKind = AnimalOrder.shared.sequence[0]

    // AUTO state
    @State private var nextAnimalAt:   Date   = .distantPast
    @State private var autoColorTarget: Double = 0.3
    @State private var lastAutoTick:   Date?  = nil

    private let accent = Color(red: 1.00, green: 0.72, blue: 0.28)
    private let animalCycleSecs: Double = 10.0

    var body: some View {
        ZStack {
            mainContent
                .opacity(recorder.isActive ? 0 : 1)
                .allowsHitTesting(!recorder.isActive)
            if recorder.isActive { recordingOverlay }
        }
        .onChange(of: speed)    { store.scene?.animSpeed = $0 }
        .onChange(of: colorHue) { store.scene?.colorHue = $0 }
        .onChange(of: showUI)   { store.scene?.view?.preferredFramesPerSecond = $0 ? 30 : 20 }
        .onAppear {
            speed    = Double.random(in: 0.3...0.7)
            colorHue = Double.random(in: 0.0...1.0)
            AnimalOrder.shared.reshuffle()
            let first = AnimalOrder.shared.sequence[0]
            currentAnimal = first
            store.scene?.morphTo(first)
            scheduleNextAnimal()
        }
        .onReceive(Timer.publish(every: 1.0/10.0, on: .main, in: .common).autoconnect()) { now in
            // Animal cycling always active regardless of AUTO mode
            if now >= nextAnimalAt, let scene = store.scene {
                let next = AnimalOrder.shared.next(after: scene.currentAnimal)
                scene.morphTo(next)
                currentAnimal = next
                scheduleNextAnimal()
            }

            // AUTO: drift COLOR only
            guard isAutoMode else { lastAutoTick = nil; return }
            let dt = min(lastAutoTick.map { now.timeIntervalSince($0) } ?? (1.0/10.0), 0.5)
            lastAutoTick = now
            colorHue += (autoColorTarget - colorHue) * 0.008 * dt * 60
            colorHue = colorHue.truncatingRemainder(dividingBy: 1.0)
            if colorHue < 0 { colorHue += 1.0 }
        }
    }

    private func scheduleNextAnimal() {
        nextAnimalAt    = Date().addingTimeInterval(Double.random(in: 8...13))
        autoColorTarget = Double.random(in: 0...1)
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        ZStack {
            GeometryReader { geo in
                SpriteView(scene: store.scene(for: geo.size))
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) { showUI.toggle() }
                    }
            }
            VStack(spacing: 0) {
                headerView
                Spacer()
                controlsView.padding(.bottom, 40)
            }
            .opacity(showUI ? 1 : 0)
            .allowsHitTesting(showUI)
            .animation(.easeInOut(duration: 0.3), value: showUI)
        }
    }

    // MARK: - Recording Overlay

    @ViewBuilder
    private var recordingOverlay: some View {
        ZStack {
            Color(red: 0.03, green: 0.05, blue: 0.03).ignoresSafeArea()
            VStack(spacing: 20) {
                Spacer()
                Text(recorder.statusText)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                if case .rendering(let p) = recorder.state {
                    VStack(spacing: 8) {
                        ProgressView(value: p).tint(accent).padding(.horizontal, 40)
                        Text("\(Int(p * 100))%")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                    }
                } else if case .saving = recorder.state {
                    ProgressView().tint(accent)
                }
                Spacer()
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerView: some View {
        ZStack {
            VStack(spacing: 4) {
                Text("ANIMAL")
                    .font(.system(size: 38, weight: .black, design: .monospaced))
                    .tracking(6)
                    .foregroundStyle(LinearGradient(
                        colors: [accent, accent.opacity(0.55)],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .shadow(color: accent.opacity(0.9), radius: 14)
                Text(currentAnimal.rawValue)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(3)
                    .foregroundColor(accent.opacity(0.60))
                    .animation(.easeInOut(duration: 0.4), value: currentAnimal)
                Rectangle()
                    .fill(accent.opacity(0.3))
                    .frame(height: 1).padding(.horizontal, 32)
            }
            HStack {
                Spacer()
                Button(action: onPickerTap) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(accent.opacity(0.75))
                        .frame(width: 44, height: 44)
                        .background(accent.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.trailing, 20)
            }
        }
        .padding(.top, 56).padding(.bottom, 16)
    }

    // MARK: - Controls

    @ViewBuilder
    private var controlsView: some View {
        VStack(spacing: 18) {
            sliderRow("SPEED", speedLabel, value: $speed)
            sliderRow("COLOR", colorLabel, value: $colorHue)
            actionButtons
        }
        .padding(.horizontal, 24).padding(.top, 20)
    }

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button {
                isAutoMode.toggle()
                if isAutoMode { scheduleNextAnimal(); lastAutoTick = nil }
            } label: {
                Text("AUTO")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(isAutoMode ? .black : accent)
                    .frame(width: 44)
                    .padding(.vertical, 14)
                    .background(
                        isAutoMode
                            ? LinearGradient(colors: [accent.opacity(0.95), accent.opacity(0.82)],
                                             startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [accent.opacity(0.12), accent.opacity(0.12)],
                                             startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(accent.opacity(isAutoMode ? 0 : 0.35), lineWidth: 1))
            }
            .shadow(color: isAutoMode ? accent.opacity(0.45) : .clear, radius: 8)

            Button {
                let snapshot = captureCurrentFrame()
                let animal   = store.scene?.currentAnimal ?? .human
                Task {
                    await recorder.startAnimal(
                        animalKind: animal, speed: speed,
                        colorHue: colorHue, stillSnapshot: snapshot
                    )
                }
            } label: {
                Text("Save as Live Photo")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(LinearGradient(colors: [accent, accent.opacity(0.75)],
                                               startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Snapshot

    private func captureCurrentFrame() -> CGImage? {
        guard let ws = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let win = ws.keyWindow,
              let skView = findSKView(in: win),
              skView.bounds.width > 0 else { return nil }
        return UIGraphicsImageRenderer(bounds: skView.bounds).image { _ in
            skView.drawHierarchy(in: skView.bounds, afterScreenUpdates: false)
        }.cgImage
    }

    private func findSKView(in view: UIView) -> SKView? {
        if let s = view as? SKView { return s }
        for sub in view.subviews { if let f = findSKView(in: sub) { return f } }
        return nil
    }

    // MARK: - Slider helpers

    @ViewBuilder
    private func sliderRow(_ label: String, _ val: String, value: Binding<Double>) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(accent.opacity(0.5))
                .frame(width: 52, alignment: .leading)
            Slider(value: value, in: 0...1).tint(accent)
            Text(val)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(accent)
                .frame(width: 46, alignment: .trailing)
        }
    }

    private var speedLabel: String {
        switch speed {
        case ..<0.25: "SLOW"; case 0.25..<0.5: "DRIFT"
        case 0.5..<0.75: "MOVE"; default: "RUSH"
        }
    }
    private var colorLabel: String {
        switch colorHue {
        case ..<0.125: "RED";    case 0.125..<0.25: "ORANGE"
        case 0.25..<0.375: "YELLOW"; case 0.375..<0.5: "GREEN"
        case 0.5..<0.625: "CYAN";  case 0.625..<0.75: "BLUE"
        case 0.75..<0.875: "VIOLET"; default: "PINK"
        }
    }
}

#Preview { AnimalView(onPickerTap: {}) }
#endif
