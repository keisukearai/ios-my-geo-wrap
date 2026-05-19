import SwiftUI
import Combine

// MARK: - Shapes (21 types)

enum ShapeKind: CaseIterable {
    case p3, p4, p5, p6, p7, p8, p9, p10, p12, p15, p17, p20
    case circle, ring
    case s3, s4, s5, s6, s7, s8
    case cross
}

// MARK: - Color

struct ColorPair { let primary, glow: Color }

// MARK: - Particle

struct WarpParticle {
    let id: Int
    let x3D, y3D: Double
    let initialPhase: Double
    let baseSize: Double
    let rotRate: Double
    let chaosOffset: Double
    let shapeKind: ShapeKind
    let shapeThreshold: Double
}

struct PState {
    let px, py, sz, op, rot: Double
    let shapeKind: ShapeKind
    let colorTint: Double
}

// MARK: - Particle Pools

struct ParticlePools {
    let tunnel: [WarpParticle]
    let vortex: [WarpParticle]
    let wave:   [WarpParticle]
    let helix:  [WarpParticle]
    let burst:  [WarpParticle]
    let blend:  [WarpParticle]

    static func make() -> ParticlePools {
        ParticlePools(
            tunnel: makeParticles(count: 80),
            vortex: makeParticles(count: 80),
            wave:   makeParticles(count: 80),
            helix:  makeParticles(count: 80),
            burst:  makeParticles(count: 80),
            blend:  makeParticles(count: 200)
        )
    }

    private static func makeParticles(count: Int) -> [WarpParticle] {
        var rng     = SystemRandomNumberGenerator()
        let rings   = max(3, count / 12)
        let perRing = max(1, count / rings)
        let shapes  = ShapeKind.allCases
        return (0..<count).map { i in
            let ring   = Double(i % rings)
            let sector = Double(i / rings)
            let angle  = sector / Double(perRing) * 2 * Double.pi
                       + ring * (Double.pi / Double(perRing * 2))
            let radius = (ring + 1) * 0.65
            let rotDir: Double = (Int(ring) % 2 == 0) ? 1 : -1
            return WarpParticle(
                id: i,
                x3D: Darwin.cos(angle) * radius,
                y3D: Darwin.sin(angle) * radius,
                initialPhase: Double(i) / Double(count),
                baseSize: 0.35 + ring * 0.085,
                rotRate: rotDir * (0.18 + Double(i % 6) * 0.085),
                chaosOffset: Double.random(in: -1...1, using: &rng),
                shapeKind: shapes[Int.random(in: 0..<shapes.count, using: &rng)],
                shapeThreshold: Double.random(in: 0.18...0.65, using: &rng)
            )
        }
    }
}

// MARK: - GeoWarpCanvas

struct GeoWarpCanvas: View {
    let t: Double
    let warp: Double
    let chaos: Double
    let tempo: Double
    let colorStyle: Double
    let pools: ParticlePools

    static let trailSteps = 8
    static let trailDt    = 0.048

    private static let metalStops: [(primary: SIMD3<Double>, glow: SIMD3<Double>)] = [
        (SIMD3(0.70, 0.80, 0.92), SIMD3(0.92, 0.96, 1.00)),
        (SIMD3(0.82, 0.52, 0.22), SIMD3(1.00, 0.75, 0.42)),
        (SIMD3(0.38, 0.54, 0.72), SIMD3(0.58, 0.76, 0.94)),
        (SIMD3(0.86, 0.90, 0.94), SIMD3(1.00, 1.00, 1.00)),
    ]

    private static let classicStops: [(primary: SIMD3<Double>, glow: SIMD3<Double>)] = [
        (SIMD3(1.00, 0.82, 0.05), SIMD3(1.00, 0.95, 0.50)),
        (SIMD3(0.80, 0.05, 0.18), SIMD3(1.00, 0.28, 0.36)),
        (SIMD3(0.12, 0.28, 0.80), SIMD3(0.32, 0.54, 1.00)),
        (SIMD3(0.96, 0.88, 0.72), SIMD3(1.00, 0.97, 0.88)),
    ]

    private var tempoRate: Double { 0.03 + pow(tempo, 1.5) * 0.45 }

    private func layerOp(mode: Double) -> Double {
        0.05 + max(0.0, 1.0 - abs(warp - mode) * 4.5) * 0.28
    }

    // MARK: - Body

    var body: some View {
        Canvas { [self] gfx, size in
            let colors = interpolatedColors(at: t)
            let attrs  = getAttractors(size: size, t: t)

            drawPlasma(gfx, size, t, colors)
            drawBackground(gfx, size, t, colors, attrs: attrs)

            for step in stride(from: Self.trailSteps, through: 1, by: -1) {
                let al = (1.0 - Double(step) / Double(Self.trailSteps + 1)) * 0.18
                let ts = computeStates(pools.blend, size: size,
                                       t: t - Double(step) * Self.trailDt, attrs: attrs)
                drawGhost(gfx, size: size, states: ts, opacity: al, colors: colors)
            }

            let stT = computeStates(pools.tunnel, size: size, t: t, warpOvr: 0.00, rate: 0.80, attrs: attrs)
            let stV = computeStates(pools.vortex, size: size, t: t, warpOvr: 0.25, rate: 1.00, attrs: attrs)
            let stW = computeStates(pools.wave,   size: size, t: t, warpOvr: 0.50, rate: 1.10, attrs: attrs)
            let stH = computeStates(pools.helix,  size: size, t: t, warpOvr: 0.75, rate: 0.90, attrs: attrs)
            let stB = computeStates(pools.burst,  size: size, t: t, warpOvr: 1.00, rate: 1.20, attrs: attrs)

            drawGhost(gfx, size: size, states: stT, opacity: layerOp(mode: 0.00), colors: colors)
            drawGhost(gfx, size: size, states: stV, opacity: layerOp(mode: 0.25), colors: colors)
            drawGhost(gfx, size: size, states: stW, opacity: layerOp(mode: 0.50), colors: colors)
            drawGhost(gfx, size: size, states: stH, opacity: layerOp(mode: 0.75), colors: colors)
            drawGhost(gfx, size: size, states: stB, opacity: layerOp(mode: 1.00), colors: colors)

            let pool = (stT + stV + stW + stH + stB).filter { $0.op > 0.4 && $0.sz > 6 }
            drawLightning(gfx, size, t, pool: pool, colors: colors)

            let states = computeStates(pools.blend, size: size, t: t, attrs: attrs)
            drawConstellations(gfx, size, states: states, colors: colors)
            drawParticles(gfx, size, states: states, colors: colors)

            drawScanlines(gfx, size)
            drawVignette(gfx, size)
        }
        .background(Color.black)
    }

    // MARK: - Color

    func interpolatedColors(at t: Double) -> ColorPair {
        let metal   = Self.metalStops
        let classic = Self.classicStops
        let m       = metal.count
        let period  = 5.0

        let phase = (t / period).truncatingRemainder(dividingBy: Double(m))
        let from  = Int(phase) % m
        let to    = (from + 1) % m
        let raw   = phase - Double(from)
        let e     = raw < 0.5 ? 2*raw*raw : 1 - pow(-2*raw+2, 2)/2

        func lv(_ a: SIMD3<Double>, _ b: SIMD3<Double>, _ f: Double) -> SIMD3<Double> { a + (b-a)*f }

        let mPrim = lv(metal[from].primary,   metal[to].primary,   e)
        let mGlow = lv(metal[from].glow,      metal[to].glow,      e)
        let cPrim = lv(classic[from].primary, classic[to].primary, e)
        let cGlow = lv(classic[from].glow,    classic[to].glow,    e)

        let f    = smoothstep(colorStyle)
        let prim = lv(mPrim, cPrim, f)
        let gl   = lv(mGlow, cGlow, f)
        return ColorPair(primary: Color(red: prim.x, green: prim.y, blue: prim.z),
                         glow:    Color(red: gl.x,   green: gl.y,   blue: gl.z))
    }

    // MARK: - Attractors

    private func getAttractors(size: CGSize, t: Double) -> [CGPoint] {
        let cx = size.width / 2, cy = size.height / 2
        let n    = 1 + Int(chaos * 9.99)
        let dist = chaos * min(cx, cy) * 0.28
        return (0..<n).map { i in
            let ang = Double(i) / Double(n) * 2 * Double.pi + t * tempoRate * 0.22
            return CGPoint(x: cx + Darwin.cos(ang) * dist,
                           y: cy + Darwin.sin(ang) * dist)
        }
    }

    // MARK: - Compute States

    func computeStates(
        _ particles: [WarpParticle],
        size: CGSize,
        t: Double,
        warpOvr: Double? = nil,
        rate: Double = 1.0,
        sizeScale: Double = 1.0,
        attrs: [CGPoint]
    ) -> [PState] {
        let cx = size.width / 2, cy = size.height / 2
        let fl = size.width * 0.09
        let zMax = 8.0, zMin = 0.28
        let r    = tempoRate * rate
        let w    = warpOvr ?? warp

        return particles.map { p in
            var rawPh = (p.initialPhase + t * r + chaos * p.chaosOffset * 0.25)
                .truncatingRemainder(dividingBy: 1.0)
            if rawPh < 0 { rawPh += 1.0 }

            let attr = attrs[p.id % attrs.count]

            let zT  = zMax - rawPh * (zMax - zMin)
            let tPx = attr.x + (p.x3D / zT) * fl
            let tPy = attr.y + (p.y3D / zT) * fl
            let tSz = max(2, p.baseSize * fl / zT * (1 + chaos * p.chaosOffset * 0.4)) * sizeScale
            let tD  = 1 - (zT - zMin) / (zMax - zMin)
            let tOp = min(1, pow(max(0, tD), 1.3))

            let vAng = p.initialPhase * 2 * Double.pi + rawPh * Double.pi * 5 * (p.rotRate > 0 ? 1 : -1)
            let vR   = pow(rawPh, 0.55) * min(cx, cy) * 0.88 * (1 + chaos * p.chaosOffset * 0.25)
            let vPx  = cx + Darwin.cos(vAng) * vR
            let vPy  = cy + Darwin.sin(vAng) * vR
            let vSz  = max(2, p.baseSize * fl * (0.08 + rawPh * 0.30)) * sizeScale
            let vOp  = min(1, rawPh * 2) * (1 - rawPh * 0.6)

            let wPx = (1 - rawPh) * (size.width + 60) - 30
            let wPy = cy + p.y3D * 42
                    + Darwin.sin(rawPh * Double.pi * 3 + p.initialPhase * 2 * Double.pi)
                    * (18 + chaos * abs(p.chaosOffset) * 28)
            let wSz = max(2, p.baseSize * fl * 0.15 * (1 + chaos * abs(p.chaosOffset) * 0.5)) * sizeScale
            let wOp = min(1, rawPh * 2.5) * min(1, (1 - rawPh) * 2.5)

            let hAng = p.initialPhase * 2 * Double.pi
                     + rawPh * Double.pi * 7 * (p.rotRate > 0 ? 1 : -1)
            let hR   = pow(rawPh, 0.65) * min(cx, cy) * 0.88 * (1 + chaos * p.chaosOffset * 0.2)
            let hPx  = cx + Darwin.cos(hAng) * hR
            let hPy  = cy + Darwin.sin(hAng) * hR
                     + Darwin.sin(hAng * 1.5 + t * r * 0.8) * hR * 0.28
            let hSz  = max(2, p.baseSize * fl * (0.10 + rawPh * 0.22)) * sizeScale
            let hOp  = min(1, rawPh * 2.5) * (1 - pow(rawPh, 1.8))

            let bn   = 5 + Int(chaos * 3)
            let cAng = Double(p.id % bn) / Double(bn) * 2 * Double.pi + t * r * 0.12
            let cDst = min(cx, cy) * (0.10 + chaos * 0.12)
            let cX   = cx + Darwin.cos(cAng) * cDst
            let cY   = cy + Darwin.sin(cAng) * cDst
            let bAng = p.initialPhase * 2 * Double.pi + chaos * p.chaosOffset * Double.pi * 0.5
            let bR   = pow(rawPh, 0.72) * min(cx, cy) * 0.90 * (1 + chaos * abs(p.chaosOffset) * 0.25)
            let bPx  = cX + Darwin.cos(bAng) * bR
            let bPy  = cY + Darwin.sin(bAng) * bR
            let bSz  = max(2, p.baseSize * fl * 0.13 * (1 + rawPh)) * sizeScale
            let bOp  = min(1, rawPh * 3) * (1 - pow(rawPh, 1.4))

            typealias M = (px: Double, py: Double, sz: Double, op: Double)
            let ms: [M] = [
                (tPx, tPy, tSz, tOp),
                (vPx, vPy, vSz, vOp),
                (wPx, wPy, wSz, wOp),
                (hPx, hPy, hSz, hOp),
                (bPx, bPy, bSz, bOp),
            ]
            let seg  = max(0, min(3.999, w * 4))
            let segI = Int(seg)
            let segF = smoothstep(seg - Double(segI))
            let mA = ms[segI], mB = ms[segI + 1]

            let px = mA.px + (mB.px - mA.px) * segF
            let py = mA.py + (mB.py - mA.py) * segF
            let szBase = mA.sz + (mB.sz - mA.sz) * segF
            let tunnelRetain = max(0.0, 1.0 - w * 3.5)
            let sz = szBase + (tSz - szBase) * tunnelRetain * 0.5
            let op = mA.op + (mB.op - mA.op) * segF

            let rot  = t * p.rotRate * (1 + w * 2.0)
            let kind = chaos >= p.shapeThreshold ? p.shapeKind : .p4
            let tint = max(0, p.chaosOffset) * chaos
            return PState(px: px, py: py, sz: sz, op: op, rot: rot, shapeKind: kind, colorTint: tint)
        }
    }

    // MARK: - Plasma Blobs

    private func drawPlasma(_ gfx: GraphicsContext, _ size: CGSize, _ t: Double, _ colors: ColorPair) {
        let cx = size.width / 2, cy = size.height / 2
        for i in 0..<9 {
            let fi  = Double(i)
            let ang = fi / 9 * 2 * Double.pi + t * (0.030 + fi * 0.005)
            let d   = min(cx, cy) * (0.30 + Darwin.sin(t * 0.09 + fi * 1.4) * 0.20)
            let bx  = cx + Darwin.cos(ang) * d
            let by  = cy + Darwin.sin(ang) * d
            let rv  = min(cx, cy) * (0.36 + Darwin.sin(t * 0.11 + fi * 1.9) * 0.12)
            var blob = Path()
            blob.addEllipse(in: CGRect(x: bx - rv, y: by - rv, width: rv * 2, height: rv * 2))
            let col = i % 2 == 0 ? colors.primary : colors.glow
            gfx.fill(blob, with: .radialGradient(
                Gradient(colors: [col.opacity(0.07), .clear]),
                center: CGPoint(x: bx, y: by), startRadius: 0, endRadius: rv
            ))
        }
    }

    // MARK: - Background

    private func drawBackground(_ gfx: GraphicsContext, _ size: CGSize, _ t: Double,
                                 _ colors: ColorPair, attrs: [CGPoint]) {
        let cx = size.width / 2, cy = size.height / 2
        let maxR = max(size.width, size.height) * 0.72

        for attr in attrs {
            let aR = 5.0 + Darwin.sin(t * 3.7) * 2
            var ap = Path()
            ap.addEllipse(in: CGRect(x: attr.x - aR, y: attr.y - aR, width: aR*2, height: aR*2))
            var ag = gfx; ag.addFilter(.blur(radius: 10))
            ag.fill(ap, with: .color(colors.glow.opacity(0.7)))
            gfx.fill(ap, with: .color(colors.primary))
        }
        if attrs.count > 1 {
            for i in 0..<attrs.count {
                var p = Path()
                p.move(to: attrs[i]); p.addLine(to: attrs[(i+1) % attrs.count])
                gfx.stroke(p, with: .color(colors.primary.opacity(0.20)), lineWidth: 0.6)
            }
        }

        for off in [0.0, 0.5] {
            let ph = (t * tempoRate * 1.8 + off).truncatingRemainder(dividingBy: 1)
            let rv = pow(ph, 1.4) * maxR
            var p  = Path()
            p.addEllipse(in: CGRect(x: cx-rv, y: cy-rv, width: rv*2, height: rv*2))
            gfx.stroke(p, with: .color(colors.glow.opacity((1-ph) * (off==0 ? 0.40 : 0.22))),
                       lineWidth: off==0 ? 1.4 : 0.8)
        }

        let tunnelA = max(0.0, 1 - warp * 8)
        if tunnelA > 0.01 {
            for sys in 0..<3 {
                let sp = 0.35 + Double(sys) * 0.28
                let al = (0.15 - Double(sys) * 0.04) * tunnelA
                for ring in 0..<14 {
                    var ph = (Double(ring)/14 + t*tempoRate*sp).truncatingRemainder(dividingBy: 1)
                    if ph < 0 { ph += 1 }
                    let rv = pow(ph, 1.8) * maxR
                    var p = Path()
                    p.addEllipse(in: CGRect(x: cx-rv, y: cy-rv, width: rv*2, height: rv*2))
                    gfx.stroke(p, with: .color(colors.primary.opacity(ph * al)), lineWidth: 0.5)
                }
            }
            for spoke in 0..<24 {
                let ang = Double(spoke)/24 * 2 * Double.pi
                let pls = 0.5 + 0.5 * Darwin.sin(t * 1.4 + Double(spoke) * 0.28)
                var p = Path()
                p.move(to: CGPoint(x: cx, y: cy))
                p.addLine(to: CGPoint(x: cx + Darwin.cos(ang)*maxR, y: cy + Darwin.sin(ang)*maxR))
                gfx.stroke(p, with: .color(colors.primary.opacity(0.035 * pls * tunnelA)), lineWidth: 0.4)
            }
        }

        let vortexA = max(0.0, 1 - abs(warp - 0.25) * 8)
        if vortexA > 0.01 {
            for i in 0..<10 {
                let rv = Double(i+1)/10 * min(cx,cy) * 0.92
                var p = Path()
                p.addEllipse(in: CGRect(x: cx-rv, y: cy-rv, width: rv*2, height: rv*2))
                gfx.stroke(p, with: .color(colors.primary.opacity(0.07 * vortexA)), lineWidth: 0.5)
            }
            for arm in 0..<4 {
                let off = Double(arm) * Double.pi/2 + t * tempoRate * 0.28
                var p = Path(); var first = true
                for step in 0..<70 {
                    let frac = Double(step)/70
                    let ang  = off + frac * Double.pi * 4
                    let rv   = frac * min(cx,cy) * 0.9
                    let pt   = CGPoint(x: cx + Darwin.cos(ang)*rv, y: cy + Darwin.sin(ang)*rv)
                    if first { p.move(to: pt); first = false } else { p.addLine(to: pt) }
                }
                gfx.stroke(p, with: .color(colors.glow.opacity(0.07 * vortexA)), lineWidth: 0.55)
            }
            for src in 0..<3 {
                let sAng = Double(src)/3 * 2 * Double.pi + t * tempoRate * 0.35
                let sX   = cx + Darwin.cos(sAng) * min(cx,cy) * 0.16
                let sY   = cy + Darwin.sin(sAng) * min(cx,cy) * 0.16
                for ring in 0..<7 {
                    var ph = (Double(ring)/7 + t*tempoRate*0.7).truncatingRemainder(dividingBy: 1)
                    if ph < 0 { ph += 1 }
                    let rv = pow(ph, 1.6) * maxR * 0.62
                    var p = Path()
                    p.addEllipse(in: CGRect(x: sX-rv, y: sY-rv, width: rv*2, height: rv*2))
                    gfx.stroke(p, with: .color(colors.glow.opacity(ph * 0.09 * vortexA)), lineWidth: 0.35)
                }
            }
        }

        let waveA = max(0.0, 1 - abs(warp - 0.5) * 8)
        if waveA > 0.01 {
            for i in 0..<16 {
                let baseY = size.height * Double(i) / 16
                var p = Path(); var first = true; var x = 0.0
                while x <= size.width {
                    let y  = baseY + Darwin.sin(x/size.width * Double.pi*8 + t*tempoRate*2)*8
                    let pt = CGPoint(x: x, y: y)
                    if first { p.move(to: pt); first = false } else { p.addLine(to: pt) }
                    x += 4
                }
                gfx.stroke(p, with: .color(colors.primary.opacity(0.055 * waveA)), lineWidth: 0.4)
            }
        }

        let helixA = max(0.0, 1 - abs(warp - 0.75) * 8)
        if helixA > 0.01 {
            for arm in 0..<6 {
                let off = Double(arm)/6 * 2 * Double.pi + t * tempoRate * 0.18
                var p = Path(); var first = true
                for step in 0..<90 {
                    let frac = Double(step)/90
                    let ang  = off + frac * Double.pi * 9
                    let rv   = frac * min(cx,cy) * 0.90
                    let wy   = Darwin.sin(frac * Double.pi * 7 + t * tempoRate * 2.2) * rv * 0.18
                    let pt   = CGPoint(x: cx + Darwin.cos(ang)*rv, y: cy + Darwin.sin(ang)*rv + wy)
                    if first { p.move(to: pt); first = false } else { p.addLine(to: pt) }
                }
                gfx.stroke(p, with: .color(colors.primary.opacity(0.07 * helixA)), lineWidth: 0.5)
            }
        }

        let burstA = max(0.0, 1 - abs(warp - 1.0) * 8)
        if burstA > 0.01 {
            for center in 0..<5 {
                let cAng = Double(center)/5 * 2 * Double.pi
                let cX   = cx + Darwin.cos(cAng) * min(cx,cy) * 0.12
                let cY   = cy + Darwin.sin(cAng) * min(cx,cy) * 0.12
                for ray in 0..<16 {
                    let rAng = Double(ray)/16 * 2 * Double.pi
                    var p = Path()
                    p.move(to: CGPoint(x: cX, y: cY))
                    p.addLine(to: CGPoint(x: cX + Darwin.cos(rAng)*maxR*0.55,
                                          y: cY + Darwin.sin(rAng)*maxR*0.55))
                    gfx.stroke(p, with: .color(colors.primary.opacity(0.035 * burstA)), lineWidth: 0.35)
                }
            }
        }
    }

    // MARK: - Lightning

    private func drawLightning(_ gfx: GraphicsContext, _ size: CGSize, _ t: Double,
                                pool: [PState], colors: ColorPair) {
        guard chaos > 0.06, pool.count >= 2 else { return }
        let arcN = 2 + Int(chaos * 12)
        for i in 0..<arcN {
            let fi   = Double(i)
            let seed = Double(Int(t * 3.5)) * 997 + fi * 113
            let af   = Darwin.sin(seed * 3.7347) * 0.5 + 0.5
            let bf   = Darwin.sin(seed * 5.3891 + 1.1) * 0.5 + 0.5
            let idxA = min(Int(af * Double(pool.count)), pool.count - 1)
            let idxB = min(Int(bf * Double(pool.count)), pool.count - 1)
            guard idxA != idxB else { continue }

            let a = pool[idxA], b = pool[idxB]
            let arcPh = (t * 3.5).truncatingRemainder(dividingBy: 1.0)
            let arcOp = arcPh < 0.25 ? arcPh/0.25 : max(0, 1-(arcPh-0.25)/0.75)
            let base  = chaos * min(a.op, b.op) * arcOp * 0.75
            guard base > 0.02 else { continue }

            let mx   = (a.px + b.px) / 2, my = (a.py + b.py) / 2
            let ctrl = CGPoint(
                x: mx - (b.py - a.py)*0.28 + Darwin.sin(seed*2.13)*22,
                y: my + (b.px - a.px)*0.28 + Darwin.cos(seed*3.47)*22
            )
            var arc = Path()
            arc.move(to: CGPoint(x: a.px, y: a.py))
            arc.addQuadCurve(to: CGPoint(x: b.px, y: b.py), control: ctrl)

            var ag = gfx; ag.addFilter(.blur(radius: 3.5))
            ag.stroke(arc, with: .color(colors.glow.opacity(base * 0.85)), lineWidth: 2.2)
            gfx.stroke(arc, with: .color(Color.white.opacity(base * 0.55)), lineWidth: 0.5)

            let brEnd = CGPoint(
                x: ctrl.x + Darwin.cos(seed * 7.3) * 35,
                y: ctrl.y + Darwin.sin(seed * 4.8) * 35
            )
            var branch = Path()
            branch.move(to: ctrl); branch.addLine(to: brEnd)
            gfx.stroke(branch, with: .color(colors.glow.opacity(base * 0.35)), lineWidth: 0.35)
        }
    }

    // MARK: - Constellation

    private func drawConstellations(_ gfx: GraphicsContext, _ size: CGSize,
                                    states: [PState], colors: ColorPair) {
        guard chaos > 0.05 else { return }
        let thr    = min(size.width, size.height) * 0.32
        let subset = stride(from: 0, to: states.count, by: 2).map { states[$0] }
        for i in 0..<subset.count {
            let a = subset[i]; guard a.op > 0.1 else { continue }
            for j in (i+1)..<subset.count {
                let b = subset[j]; guard b.op > 0.1 else { continue }
                let dx = a.px - b.px, dy = a.py - b.py
                let d  = (dx*dx + dy*dy).squareRoot()
                guard d < thr else { continue }
                let alpha = chaos * (1-d/thr) * min(a.op, b.op) * 0.55
                guard alpha > 0.02 else { continue }
                var p = Path()
                p.move(to: CGPoint(x: a.px, y: a.py))
                p.addLine(to: CGPoint(x: b.px, y: b.py))
                gfx.stroke(p, with: .color(colors.primary.opacity(alpha)), lineWidth: 0.4)
            }
        }
    }

    // MARK: - Ghost Particles

    private func drawGhost(_ gfx: GraphicsContext, size: CGSize, states: [PState],
                           opacity: Double, colors: ColorPair) {
        for s in states {
            guard s.op * opacity > 0.015, s.sz > 0.5 else { continue }
            let m = s.sz * 2
            guard s.px > -m, s.px < size.width+m, s.py > -m, s.py < size.height+m else { continue }
            let rect = CGRect(x: s.px-s.sz/2, y: s.py-s.sz/2, width: s.sz, height: s.sz)
            let path = makePath(s.shapeKind, rect: rect).applying(
                CGAffineTransform(translationX: s.px, y: s.py)
                    .rotated(by: s.rot).translatedBy(x: -s.px, y: -s.py)
            )
            gfx.stroke(path, with: .color(colors.primary.opacity(s.op * opacity)),
                       lineWidth: max(0.5, s.sz * 0.07))
        }
    }

    // MARK: - Main Particles

    private func drawParticles(_ gfx: GraphicsContext, _ size: CGSize,
                                states: [PState], colors: ColorPair) {
        for s in states.sorted(by: { $0.sz < $1.sz }) {
            guard s.op > 0.01, s.sz > 0.5 else { continue }
            let m = s.sz * 3
            guard s.px > -m, s.px < size.width+m, s.py > -m, s.py < size.height+m else { continue }

            let rect  = CGRect(x: s.px-s.sz/2, y: s.py-s.sz/2, width: s.sz, height: s.sz)
            let xform = CGAffineTransform(translationX: s.px, y: s.py)
                            .rotated(by: s.rot).translatedBy(x: -s.px, y: -s.py)
            let path  = makePath(s.shapeKind, rect: rect).applying(xform)
            let lineW = max(0.9, s.sz * 0.085)
            let baseC = s.colorTint > 0.55 ? colors.glow : colors.primary

            if s.sz > 15 {
                let sh    = s.sz * 0.055
                let rPath = makePath(s.shapeKind, rect: rect.offsetBy(dx: -sh, dy: 0)).applying(xform)
                let bPath = makePath(s.shapeKind, rect: rect.offsetBy(dx:  sh, dy: 0)).applying(xform)
                gfx.stroke(rPath, with: .color(Color.red.opacity(s.op * 0.18)),  lineWidth: lineW * 0.55)
                gfx.stroke(bPath, with: .color(Color.cyan.opacity(s.op * 0.18)), lineWidth: lineW * 0.55)
            }

            if s.sz > 9 {
                var og = gfx; og.addFilter(.blur(radius: s.sz * 0.50))
                og.stroke(path, with: .color(baseC.opacity(s.op * 0.55)), lineWidth: lineW * 2.5)
                var ig = gfx; ig.addFilter(.blur(radius: s.sz * 0.14))
                ig.stroke(path, with: .color(colors.glow.opacity(s.op * 0.40)), lineWidth: lineW)
            } else {
                var g = gfx; g.addFilter(.blur(radius: s.sz * 0.4))
                g.stroke(path, with: .color(baseC.opacity(s.op * 0.4)), lineWidth: lineW * 1.8)
            }

            gfx.stroke(path, with: .color(baseC.opacity(s.op)), lineWidth: lineW)

            if s.op > 0.7 {
                gfx.stroke(path, with: .color(Color.white.opacity((s.op-0.7)/0.3*0.6)),
                           lineWidth: lineW * 0.35)
            }

            if s.sz > 12 {
                let r1 = s.sz * 0.62
                let p1 = makePath(s.shapeKind, rect: CGRect(x: s.px-r1/2, y: s.py-r1/2, width: r1, height: r1))
                    .applying(CGAffineTransform(translationX: s.px, y: s.py)
                        .rotated(by: s.rot + Double.pi/6).translatedBy(x: -s.px, y: -s.py))
                gfx.stroke(p1, with: .color(colors.glow.opacity(s.op * 0.32)), lineWidth: lineW * 0.65)
            }

            if s.sz > 20 {
                let r2 = s.sz * 0.38
                let p2 = makePath(s.shapeKind, rect: CGRect(x: s.px-r2/2, y: s.py-r2/2, width: r2, height: r2))
                    .applying(CGAffineTransform(translationX: s.px, y: s.py)
                        .rotated(by: s.rot + Double.pi/3).translatedBy(x: -s.px, y: -s.py))
                gfx.stroke(p2, with: .color(Color.white.opacity(s.op * 0.22)), lineWidth: lineW * 0.45)
            }

            if s.sz > 32 {
                let r3 = s.sz * 0.22
                let p3 = makePath(s.shapeKind, rect: CGRect(x: s.px-r3/2, y: s.py-r3/2, width: r3, height: r3))
                    .applying(CGAffineTransform(translationX: s.px, y: s.py)
                        .rotated(by: s.rot + Double.pi/2).translatedBy(x: -s.px, y: -s.py))
                gfx.stroke(p3, with: .color(baseC.opacity(s.op * 0.18)), lineWidth: lineW * 0.30)
            }

            if s.op > 0.82 && s.sz > 16 {
                gfx.fill(path, with: .color(colors.glow.opacity((s.op-0.82)/0.18*0.09)))
            }
        }
    }

    // MARK: - Scanlines & Vignette

    private func drawScanlines(_ gfx: GraphicsContext, _ size: CGSize) {
        var y = 0.0
        while y < size.height {
            var p = Path()
            p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: size.width, y: y))
            gfx.stroke(p, with: .color(Color.black.opacity(0.055)), lineWidth: 1.0)
            y += 4
        }
    }

    private func drawVignette(_ gfx: GraphicsContext, _ size: CGSize) {
        var path = Path()
        path.addRect(CGRect(origin: .zero, size: size))
        gfx.fill(path, with: .radialGradient(
            Gradient(colors: [.clear, Color.black.opacity(0.85)]),
            center: CGPoint(x: size.width/2, y: size.height/2),
            startRadius: min(size.width, size.height) * 0.35,
            endRadius:   max(size.width, size.height) * 0.75
        ))
    }

    func smoothstep(_ x: Double) -> Double {
        let t = max(0, min(1, x)); return t * t * (3 - 2 * t)
    }

    // MARK: - Shape Paths (21 types)

    func makePath(_ kind: ShapeKind, rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY), r = rect.width / 2
        switch kind {
        case .p3:  return polygon(c, r, n: 3,  start: -.pi/2)
        case .p4:  return polygon(c, r, n: 4,  start: -.pi/4)
        case .p5:  return polygon(c, r, n: 5,  start: -.pi/2)
        case .p6:  return polygon(c, r, n: 6,  start: 0)
        case .p7:  return polygon(c, r, n: 7,  start: -.pi/2)
        case .p8:  return polygon(c, r, n: 8,  start: -.pi/8)
        case .p9:  return polygon(c, r, n: 9,  start: -.pi/2)
        case .p10: return polygon(c, r, n: 10, start: -.pi/2)
        case .p12: return polygon(c, r, n: 12, start: -.pi/12)
        case .p15: return polygon(c, r, n: 15, start: -.pi/2)
        case .p17: return polygon(c, r, n: 17, start: -.pi/2)
        case .p20: return polygon(c, r, n: 20, start: -.pi/2)
        case .circle: return Path(ellipseIn: rect)
        case .ring:
            var p = Path()
            p.addEllipse(in: rect)
            p.addEllipse(in: rect.insetBy(dx: r * 0.38, dy: r * 0.38))
            return p
        case .s3: return star(c, outer: r, inner: r * 0.32, n: 3)
        case .s4: return star(c, outer: r, inner: r * 0.38, n: 4)
        case .s5: return star(c, outer: r, inner: r * 0.42, n: 5)
        case .s6: return star(c, outer: r, inner: r * 0.45, n: 6)
        case .s7: return star(c, outer: r, inner: r * 0.47, n: 7)
        case .s8: return star(c, outer: r, inner: r * 0.50, n: 8)
        case .cross: return crossPath(c, r: r)
        }
    }

    private func polygon(_ c: CGPoint, _ r: Double, n: Int, start: Double) -> Path {
        var path = Path()
        for i in 0..<n {
            let ang = start + Double(i) * 2 * Double.pi / Double(n)
            let pt  = CGPoint(x: c.x + r * Darwin.cos(ang), y: c.y + r * Darwin.sin(ang))
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath(); return path
    }

    private func star(_ c: CGPoint, outer: Double, inner: Double, n: Int) -> Path {
        var path = Path()
        for i in 0..<(n * 2) {
            let ang = -.pi/2 + Double(i) * Double.pi / Double(n)
            let r   = i % 2 == 0 ? outer : inner
            let pt  = CGPoint(x: c.x + r * Darwin.cos(ang), y: c.y + r * Darwin.sin(ang))
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath(); return path
    }

    private func crossPath(_ c: CGPoint, r: Double) -> Path {
        let arm = r * 0.32
        let pts: [(Double, Double)] = [
            (-arm,-r),(arm,-r),(arm,-arm),(r,-arm),
            (r,arm),(arm,arm),(arm,r),(-arm,r),
            (-arm,arm),(-r,arm),(-r,-arm),(-arm,-arm)
        ]
        var path = Path()
        for (i, (dx, dy)) in pts.enumerated() {
            let pt = CGPoint(x: c.x + dx, y: c.y + dy)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath(); return path
    }
}

// MARK: - ContentView

struct ContentView: View {

    @State private var warp:       Double = 0.0
    @State private var chaos:      Double = 0.0
    @State private var tempo:      Double = 0.35
    @State private var colorStyle: Double = 0.0

    @State private var showUI:          Bool   = true
    @State private var isAutoMode:      Bool   = false
    @State private var autoTargetWarp:  Double = 0.0
    @State private var autoTargetChaos: Double = 0.0
    @State private var autoNextWarp:    Date   = .distantPast
    @State private var autoNextChaos:   Date   = .distantPast

    @StateObject private var recorder = WallpaperRecorder()

    private let pools = ParticlePools.make()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if recorder.isActive {
                recordingOverlay()
            } else {
                TimelineView(.animation) { tl in
                    let t      = tl.date.timeIntervalSinceReferenceDate
                    let canvas = GeoWarpCanvas(t: t, warp: warp, chaos: chaos,
                                              tempo: tempo, colorStyle: colorStyle, pools: pools)
                    let colors = canvas.interpolatedColors(at: t)
                    ZStack {
                        canvas
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showUI.toggle()
                                }
                            }
                        VStack(spacing: 0) {
                            headerView(colors: colors)
                            Spacer()
                            controlsView(colors: colors)
                                .padding(.bottom, 40)
                        }
                        .opacity(showUI ? 1 : 0)
                        .allowsHitTesting(showUI)
                        .animation(.easeInOut(duration: 0.3), value: showUI)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            warp       = .random(in: 0...1)
            chaos      = .random(in: 0...1)
            colorStyle = .random(in: 0...1)
        }
        .onReceive(Timer.publish(every: 1.0/60.0, on: .main, in: .common).autoconnect()) { now in
            guard isAutoMode else { return }
            let steps: [Double] = [0.0, 0.25, 0.5, 0.75, 1.0]
            if now >= autoNextWarp {
                let cur = steps.min(by: { abs($0 - autoTargetWarp) < abs($1 - autoTargetWarp) }) ?? 0.0
                let idx = steps.firstIndex(of: cur) ?? 0
                autoTargetWarp = steps[(idx + 1) % steps.count]
                autoNextWarp   = now.addingTimeInterval(30)
            }
            if now >= autoNextChaos {
                let cur = steps.min(by: { abs($0 - autoTargetChaos) < abs($1 - autoTargetChaos) }) ?? 0.0
                let idx = steps.firstIndex(of: cur) ?? 0
                autoTargetChaos = steps[(idx + 1) % steps.count]
                autoNextChaos   = now.addingTimeInterval(30)
            }
            warp  += (autoTargetWarp  - warp)  * 0.0016
            chaos += (autoTargetChaos - chaos) * 0.0016
        }
    }

    // MARK: - Recording Overlay

    @ViewBuilder
    private func recordingOverlay() -> some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                Spacer()
                Text(recorder.statusText)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                if case .rendering(let p) = recorder.state {
                    VStack(spacing: 8) {
                        ProgressView(value: p)
                            .tint(.white)
                            .padding(.horizontal, 40)
                        Text("\(Int(p * 100))%")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                    }
                } else if case .saving = recorder.state {
                    ProgressView()
                        .tint(.white)
                }
                Spacer()
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private func headerView(colors: ColorPair) -> some View {
        VStack(spacing: 4) {
            Text("GeoWarp")
                .font(.system(size: 38, weight: .black, design: .monospaced))
                .tracking(6)
                .foregroundStyle(LinearGradient(colors: [colors.primary, colors.glow],
                                                startPoint: .leading, endPoint: .trailing))
                .shadow(color: colors.primary.opacity(0.9), radius: 14)
            Rectangle()
                .fill(colors.primary.opacity(0.3))
                .frame(height: 1).padding(.horizontal, 32)
        }
        .padding(.top, 56).padding(.bottom, 16)
    }

    // MARK: - Controls

    @ViewBuilder
    private func controlsView(colors: ColorPair) -> some View {
        VStack(spacing: 18) {
            themeSliderRow(colors: colors)
            sliderRow("WARP",  warpLabel,  value: $warp,       colors: colors)
            sliderRow("CHAOS", chaosLabel, value: $chaos,      colors: colors)
            sliderRow("TEMPO", tempoLabel, value: $tempo,      colors: colors)
            wallpaperButton(colors: colors)
        }
        .padding(.horizontal, 24).padding(.top, 20)
    }

    @ViewBuilder
    private func wallpaperButton(colors: ColorPair) -> some View {
        HStack(spacing: 10) {
            Button {
                isAutoMode.toggle()
                if isAutoMode {
                    let steps: [Double] = [0.0, 0.25, 0.5, 0.75, 1.0]
                    warp  = steps.randomElement()!
                    chaos = steps.randomElement()!
                    autoTargetWarp  = warp
                    autoTargetChaos = chaos
                    autoNextWarp    = .distantPast
                    autoNextChaos   = Date().addingTimeInterval(15)
                }
            } label: {
                Text("AUTO")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(isAutoMode ? .black : colors.primary)
                    .frame(width: 44)
                    .padding(.vertical, 14)
                    .background(
                        isAutoMode
                            ? LinearGradient(colors: [Color.white.opacity(0.90), Color.white.opacity(0.82)],
                                             startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [colors.primary.opacity(0.12),
                                                      colors.primary.opacity(0.12)],
                                             startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(colors.primary.opacity(isAutoMode ? 0 : 0.35), lineWidth: 1)
                    )
            }
            .shadow(color: isAutoMode ? Color.white.opacity(0.35) : .clear, radius: 8)

            Button {
                Task {
                    await recorder.start(
                        warp: warp, chaos: chaos, tempo: tempo,
                        colorStyle: colorStyle, pools: pools
                    )
                }
            } label: {
                Text("Save as Live Photo")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: [colors.primary, colors.glow],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private func themeSliderRow(colors: ColorPair) -> some View {
        HStack(spacing: 12) {
            Text("METAL")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(colors.primary.opacity(colorStyle > 0.5 ? 0.38 : 0.90))
                .frame(width: 46, alignment: .leading)
            Slider(value: $colorStyle, in: 0...1).tint(colors.primary)
            Text("CLASSIC")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(colors.primary.opacity(colorStyle < 0.5 ? 0.38 : 0.90))
                .frame(width: 50, alignment: .trailing)
        }
    }

    private var warpLabel: String {
        switch warp {
        case ..<0.12:     "TUNNEL"
        case 0.12..<0.37: "VORTEX"
        case 0.37..<0.62: "WAVE"
        case 0.62..<0.87: "HELIX"
        default:          "BURST"
        }
    }

    private var chaosLabel: String {
        switch chaos {
        case ..<0.2:    "ORDER"
        case 0.2..<0.5: "DRIFT"
        case 0.5..<0.8: "FLUX"
        default:        "CHAOS"
        }
    }

    private var tempoLabel: String {
        switch tempo {
        case ..<0.25:    "SLOW"
        case 0.25..<0.5: "MED"
        case 0.5..<0.75: "FAST"
        default:         "HYPER"
        }
    }

    @ViewBuilder
    private func sliderRow(_ label: String, _ val: String,
                           value: Binding<Double>, colors: ColorPair) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(colors.primary.opacity(0.5))
                .frame(width: 46, alignment: .leading)
            Slider(value: value, in: 0...1).tint(colors.primary)
            Text(val)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(colors.primary)
                .frame(width: 46, alignment: .trailing)
        }
    }
}

#Preview { ContentView() }
