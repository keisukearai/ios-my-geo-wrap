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
        case .giraffe:  return 0.92
        case .elephant: return 1.24
        case .eagle:    return 1.18
        case .whale:    return 1.24
        }
    }

    private var yAspect: Double {
        switch self {
        case .giraffe:  return 0.78
        case .elephant: return 0.58
        case .eagle:    return 0.62
        case .whale:    return 0.56
        default:        return 1.00
        }
    }

    private var offset: CGPoint {
        switch self {
        case .whale: return CGPoint(x: 0.08, y: -0.04)
        default:     return .zero
        }
    }

    // Rx = width*0.38, Ry = height*0.38 → portrait-optimized scaling
    func buildTargets(count: Int, seed: UInt64, in size: CGSize) -> [CGPoint] {
        let Rx = Double(size.width)  * 0.38 * scale
        let Ry = Double(size.height) * 0.38 * scale * yAspect
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
                pts.append(CGPoint(x: cx + (np.x + offset.x) * Rx,
                                   y: cy + (np.y + offset.y) * Ry))
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
        // ── 胴体: 首に負けない横長の塊として読ませる ─────────────────
        .ellipse      (cx: -0.22, cy: -0.20, rx: 0.58, ry: 0.21, weight: 94),
        .ellipseBorder(cx: -0.22, cy: -0.20, rx: 0.58, ry: 0.21, weight: 54),
        .line(x1: -0.68, y1: -0.12, x2: 0.20, y2: -0.12, halfW: 0.032, weight: 26),
        .line(x1: -0.60, y1: -0.34, x2: 0.18, y2: -0.36, halfW: 0.032, weight: 26),

        // ── 首: 短め・太めにして、縦の棒だけに見えないようにする ─────
        .line(x1: 0.20, y1: -0.01, x2: 0.48, y2: 0.44, halfW: 0.055, weight: 36),
        .line(x1: 0.13, y1: -0.02, x2: 0.39, y2: 0.40, halfW: 0.032, weight: 14),

        // ── 頭: 横向きの小さな頭と鼻先、短い角を明確にする ───────────
        .ellipse      (cx: 0.66, cy: 0.50, rx: 0.17, ry: 0.075, weight: 24),
        .ellipseBorder(cx: 0.66, cy: 0.50, rx: 0.17, ry: 0.075, weight: 14),
        .ellipse(cx: 0.82, cy: 0.48, rx: 0.060, ry: 0.034, weight: 8),
        .line(x1: 0.59, y1: 0.56, x2: 0.57, y2: 0.67, halfW: 0.013, weight: 4),
        .line(x1: 0.70, y1: 0.56, x2: 0.71, y2: 0.67, halfW: 0.013, weight: 4),
        .circle(cx: 0.72, cy: 0.52, r: 0.014, weight: 2),

        // ── 脚: 4本を体の下に分散し、長すぎる印象を抑える ────────────
        .line(x1: 0.15, y1: -0.35, x2: 0.17, y2: -0.76, halfW: 0.046, weight: 24),
        .line(x1: 0.00, y1: -0.36, x2: 0.03, y2: -0.76, halfW: 0.041, weight: 22),
        .line(x1:-0.35, y1: -0.35, x2:-0.33, y2: -0.76, halfW: 0.046, weight: 24),
        .line(x1:-0.52, y1: -0.34, x2:-0.50, y2: -0.74, halfW: 0.041, weight: 22),

        // ── 尻尾と蹄 ───────────────────────────────────────────────────
        .line(x1:-0.76, y1: -0.14, x2:-0.91, y2: -0.28, halfW: 0.017, weight: 7),
        .ellipse(cx: 0.17, cy: -0.79, rx: 0.056, ry: 0.020, weight: 4),
        .ellipse(cx: 0.03, cy: -0.79, rx: 0.056, ry: 0.020, weight: 4),
        .ellipse(cx:-0.33, cy: -0.79, rx: 0.056, ry: 0.020, weight: 4),
        .ellipse(cx:-0.50, cy: -0.77, rx: 0.056, ry: 0.020, weight: 4),
    ]

    // MARK: Elephant (side view, facing right)
    private static let elephantSegs: [AnimalSegment] = [
        // ── 胴体: まず横長の塊として読ませる ────────────────────────────
        .ellipse      (cx: -0.12, cy:  0.02, rx: 0.70, ry: 0.24, weight: 92),
        .ellipseBorder(cx: -0.12, cy:  0.02, rx: 0.70, ry: 0.24, weight: 78),

        // ── 頭: 胴体前面に接続した大きめの頭 ────────────────────────────
        .circle      (cx:  0.57, cy:  0.13, r:  0.22, weight: 36),
        .circleBorder(cx:  0.57, cy:  0.13, r:  0.22, weight: 34),
        .ellipse(cx:  0.39, cy:  0.08, rx: 0.18, ry: 0.12, weight: 15),

        // ── 耳: 頭の後ろに大きく、上へ伸びすぎない ──────────────────────
        .ellipse      (cx:  0.35, cy:  0.12, rx: 0.23, ry: 0.24, weight: 52),
        .ellipseBorder(cx:  0.35, cy:  0.12, rx: 0.23, ry: 0.24, weight: 68),

        // ── 鼻: 前へ出てから下へ垂れ、先端だけ内側に巻く ────────────────
        .line(x1: 0.75, y1:  0.03, x2: 0.92, y2: -0.08, halfW: 0.092, weight: 33),
        .line(x1: 0.92, y1: -0.08, x2: 0.94, y2: -0.24, halfW: 0.072, weight: 31),
        .line(x1: 0.94, y1: -0.24, x2: 0.86, y2: -0.39, halfW: 0.052, weight: 28),
        .line(x1: 0.86, y1: -0.39, x2: 0.70, y2: -0.46, halfW: 0.035, weight: 20),
        .line(x1: 0.70, y1: -0.46, x2: 0.58, y2: -0.43, halfW: 0.024, weight: 10),

        // ── 牙: 鼻より上から前方へ伸ばして識別点にする ────────────────
        .line(x1: 0.70, y1:  0.01, x2: 1.05, y2: -0.08, halfW: 0.017, weight: 16),

        // ── 脚: 高さを抑えた太い柱。縦長化を避ける ────────────────────
        .line(x1: 0.34, y1: -0.16, x2: 0.35, y2: -0.43, halfW: 0.070, weight: 32),
        .line(x1: 0.12, y1: -0.17, x2: 0.13, y2: -0.44, halfW: 0.070, weight: 32),
        .line(x1:-0.24, y1: -0.16, x2:-0.24, y2: -0.43, halfW: 0.070, weight: 32),
        .line(x1:-0.49, y1: -0.14, x2:-0.50, y2: -0.41, halfW: 0.070, weight: 32),

        // ── 尻尾 ──────────────────────────────────────────────────────────
        .line(x1:-0.79, y1:  0.07, x2:-0.90, y2: -0.09, halfW: 0.016, weight:  6),

        // ── 足裏: 横長にして接地感を出す ────────────────────────────────
        .ellipse(cx:  0.35, cy: -0.46, rx: 0.090, ry: 0.026, weight: 4),
        .ellipse(cx:  0.13, cy: -0.47, rx: 0.090, ry: 0.026, weight: 4),
        .ellipse(cx: -0.24, cy: -0.46, rx: 0.090, ry: 0.026, weight: 4),
        .ellipse(cx: -0.50, cy: -0.44, rx: 0.090, ry: 0.026, weight: 4),

        // ── 目 ────────────────────────────────────────────────────────────
        .circle(cx: 0.65, cy: 0.20, r: 0.017, weight: 2),
    ]

    // MARK: Eagle (front view, wings fully spread, soaring)
    private static let eagleSegs: [AnimalSegment] = [
        // ── 頭とくちばし: 上端の縦線を短くし、中央の顔として読ませる ──
        .circle      (cx: 0.00, cy: 0.40, r: 0.085, weight: 18),
        .circleBorder(cx: 0.00, cy: 0.40, r: 0.085, weight: 14),
        .line(x1: -0.020, y1: 0.34, x2: 0.000, y2: 0.25, halfW: 0.020, weight: 5),
        .line(x1:  0.020, y1: 0.34, x2: 0.000, y2: 0.25, halfW: 0.020, weight: 5),

        // ── 胴体: 中央に短いしずく型の芯を作る ───────────────────────
        .ellipse      (cx: 0.00, cy: 0.08, rx: 0.16, ry: 0.21, weight: 42),
        .ellipseBorder(cx: 0.00, cy: 0.08, rx: 0.16, ry: 0.21, weight: 28),
        .line(x1: -0.08, y1: 0.25, x2: -0.04, y2: -0.08, halfW: 0.030, weight: 12),
        .line(x1:  0.08, y1: 0.25, x2:  0.04, y2: -0.08, halfW: 0.030, weight: 12),

        // ── 翼: 肩から翼端までの上辺と下辺を明確にして翼幅を広げる ───
        .line(x1: -0.12, y1: 0.20, x2: -0.48, y2: 0.24, halfW: 0.064, weight: 44),
        .line(x1: -0.48, y1: 0.24, x2: -1.02, y2: 0.05, halfW: 0.050, weight: 58),
        .line(x1: -0.14, y1: 0.02, x2: -0.48, y2: -0.06, halfW: 0.060, weight: 38),
        .line(x1: -0.48, y1: -0.06, x2: -0.98, y2: -0.28, halfW: 0.050, weight: 54),
        .line(x1:  0.12, y1: 0.20, x2:  0.48, y2: 0.24, halfW: 0.064, weight: 44),
        .line(x1:  0.48, y1: 0.24, x2:  1.02, y2: 0.05, halfW: 0.050, weight: 58),
        .line(x1:  0.14, y1: 0.02, x2:  0.48, y2: -0.06, halfW: 0.060, weight: 38),
        .line(x1:  0.48, y1: -0.06, x2:  0.98, y2: -0.28, halfW: 0.050, weight: 54),

        // ── 風切羽: 翼端に指状の切れ込みを置き、鳥らしさを出す ─────
        .line(x1: -0.78, y1: 0.00, x2: -0.88, y2: -0.24, halfW: 0.018, weight: 12),
        .line(x1: -0.88, y1: 0.02, x2: -1.04, y2: -0.18, halfW: 0.018, weight: 12),
        .line(x1: -0.94, y1: 0.08, x2: -1.08, y2: -0.04, halfW: 0.018, weight: 10),
        .line(x1:  0.78, y1: 0.00, x2:  0.88, y2: -0.24, halfW: 0.018, weight: 12),
        .line(x1:  0.88, y1: 0.02, x2:  1.04, y2: -0.18, halfW: 0.018, weight: 12),
        .line(x1:  0.94, y1: 0.08, x2:  1.08, y2: -0.04, halfW: 0.018, weight: 10),

        // ── 尾羽: 長く垂らさず、胴体直下の短い扇形にする ─────────────
        .line(x1: -0.08, y1: -0.08, x2: -0.18, y2: -0.30, halfW: 0.046, weight: 14),
        .line(x1:  0.00, y1: -0.10, x2:  0.00, y2: -0.34, halfW: 0.046, weight: 14),
        .line(x1:  0.08, y1: -0.08, x2:  0.18, y2: -0.30, halfW: 0.046, weight: 14),
        .ellipse(cx: -0.08, cy: -0.35, rx: 0.040, ry: 0.018, weight: 2),
        .ellipse(cx:  0.08, cy: -0.35, rx: 0.040, ry: 0.018, weight: 2),
    ]

    // MARK: Whale (side view, facing right)
    private static let whaleSegs: [AnimalSegment] = [
        // ── 胴体: 輪郭を保ちつつ中央にも点を置き、空洞感を減らす ─────
        .ellipse      (cx: -0.04, cy: -0.04, rx: 0.60, ry: 0.21, weight: 88),
        .ellipseBorder(cx: -0.04, cy: -0.04, rx: 0.70, ry: 0.27, weight: 118),
        .ellipse      (cx:  0.20, cy: -0.05, rx: 0.32, ry: 0.13, weight: 28),
        .line(x1: -0.62, y1:  0.00, x2: -0.34, y2:  0.18, halfW: 0.026, weight: 26),
        .line(x1: -0.34, y1:  0.18, x2:  0.34, y2:  0.20, halfW: 0.028, weight: 36),
        .line(x1:  0.34, y1:  0.20, x2:  0.68, y2:  0.10, halfW: 0.024, weight: 28),
        .line(x1: -0.58, y1: -0.20, x2:  0.54, y2: -0.20, halfW: 0.030, weight: 38),

        // ── 頭部: 右端を丸くし、目と口で向きを固定する ────────────────
        .ellipse      (cx:  0.58, cy: -0.03, rx: 0.27, ry: 0.22, weight: 50),
        .ellipseBorder(cx:  0.58, cy: -0.03, rx: 0.27, ry: 0.22, weight: 52),
        .line(x1: 0.40, y1: -0.13, x2: 0.80, y2: -0.15, halfW: 0.015, weight: 14),
        .circle(cx: 0.69, cy: 0.07, r: 0.022, weight: 6),

        // ── 尾びれ: 左端を大きな二葉のフルークとして読ませる ───────────
        .line(x1: -0.64, y1: -0.05, x2: -0.82, y2: -0.04, halfW: 0.044, weight: 20),
        .line(x1: -0.82, y1: -0.04, x2: -1.04, y2:  0.23, halfW: 0.058, weight: 36),
        .line(x1: -0.82, y1: -0.04, x2: -1.04, y2: -0.29, halfW: 0.058, weight: 36),
        .line(x1: -1.04, y1:  0.23, x2: -0.82, y2:  0.11, halfW: 0.034, weight: 18),
        .line(x1: -1.04, y1: -0.29, x2: -0.82, y2: -0.17, halfW: 0.034, weight: 18),
        .circle(cx: -0.82, cy: -0.04, r: 0.030, weight: 4),

        // ── 背びれ・胸びれ・潮吹き: 目印として残しつつ点数は控えめ ─────
        .line(x1: -0.08, y1:  0.19, x2: -0.22, y2:  0.41, halfW: 0.046, weight: 22),
        .line(x1:  0.18, y1: -0.18, x2:  0.42, y2: -0.45, halfW: 0.062, weight: 26),
        .circle(cx: 0.30, cy: 0.20, r: 0.016, weight: 2),
        .line(x1: 0.30, y1: 0.21, x2: 0.29, y2: 0.39, halfW: 0.013, weight: 5),
        .line(x1: 0.29, y1: 0.39, x2: 0.20, y2: 0.51, halfW: 0.010, weight: 3),
        .line(x1: 0.29, y1: 0.39, x2: 0.39, y2: 0.51, halfW: 0.010, weight: 3),
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

    @State private var isIdle:        Bool = false
    @State private var lastTouchDate: Date = .now

    private let accent              = Color(red: 1.00, green: 0.72, blue: 0.28)
    private let animalCycleSecs:    Double = 10.0
    private let idleCheckTimer      = Timer.publish(every: 5.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            mainContent
                .opacity(recorder.isActive ? 0 : 1)
                .allowsHitTesting(!recorder.isActive)
            if recorder.isActive { recordingOverlay }
        }
        .onChange(of: speed)    { store.scene?.animSpeed = $0 }
        .onChange(of: colorHue) { store.scene?.colorHue = $0 }
        .onChange(of: showUI)   { _ in store.scene?.view?.preferredFramesPerSecond = isIdle ? 15 : (showUI ? 30 : 20) }
        .onChange(of: isIdle)   { _ in store.scene?.view?.preferredFramesPerSecond = isIdle ? 15 : (showUI ? 30 : 20) }
        .onReceive(idleCheckTimer) { _ in
            if Date().timeIntervalSince(lastTouchDate) >= 60 { isIdle = true }
        }
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
                        lastTouchDate = .now
                        isIdle = false
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
