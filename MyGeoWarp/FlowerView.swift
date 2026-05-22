import SwiftUI
import Combine

// MARK: - FlowerKind

enum FlowerKind: String, CaseIterable {
    case sakura   = "SAKURA"
    case himawari = "HIMAWARI"
    case cosmos   = "COSMOS"
    case tsubaki  = "TSUBAKI"
    case asagao   = "ASAGAO"
    case tanpopo  = "TANPOPO"
}

// MARK: - FlowerOrder

final class FlowerOrder {
    static let shared = FlowerOrder()
    private(set) var sequence: [FlowerKind] = FlowerKind.allCases

    func reshuffle() { sequence = FlowerKind.allCases.shuffled() }

    func next(after kind: FlowerKind) -> FlowerKind {
        guard let i = sequence.firstIndex(of: kind) else { return sequence[0] }
        return sequence[(i + 1) % sequence.count]
    }
}

// MARK: - FlowerFrame (for WallpaperRecorder ImageRenderer)

struct FlowerFrame: View {
    var t: Double
    let kind: FlowerKind
    let speed: Double
    let colorHue: Double
    let size: CGSize

    var body: some View {
        FlowerCanvas(t: t, kind: kind, nextKind: kind, morphProgress: 1.0,
                     speed: speed, colorHue: colorHue)
            .frame(width: size.width, height: size.height)
    }
}

// MARK: - FlowerCanvas

struct FlowerCanvas: View {
    let t: Double
    let kind: FlowerKind
    let nextKind: FlowerKind
    let morphProgress: Double   // 0→1: kind fades out, nextKind fades in
    let speed: Double
    let colorHue: Double

    var body: some View {
        Canvas { [self] gfx, size in
            let cx = size.width  / 2
            let cy = size.height / 2
            let r  = min(size.width, size.height) * 0.38

            var bg = Path(); bg.addRect(CGRect(origin: .zero, size: size))
            gfx.fill(bg, with: .color(bgColor(nextKind)))

            drawFloatingPetals(gfx, cx: cx, cy: cy, size: size)

            // Soft glow behind flower
            var glowP = Path()
            glowP.addEllipse(in: CGRect(x: cx - r*1.15, y: cy - r*1.15, width: r*2.3, height: r*2.3))
            gfx.fill(glowP, with: .radialGradient(
                Gradient(colors: [petalBaseColor(nextKind).opacity(0.20), .clear]),
                center: CGPoint(x: cx, y: cy), startRadius: 0, endRadius: r * 1.15
            ))

            // Cross-fade between flowers
            if morphProgress < 1.0 {
                var oldCtx = gfx; oldCtx.opacity = 1.0 - morphProgress
                drawFlower(oldCtx, kind: kind, cx: cx, cy: cy, r: r)
            }
            var newCtx = gfx; newCtx.opacity = morphProgress < 1.0 ? morphProgress : 1.0
            drawFlower(newCtx, kind: nextKind, cx: cx, cy: cy, r: r)
        }
        .background(bgColor(nextKind))
    }

    // MARK: - Colors

    private func bgColor(_ kind: FlowerKind) -> Color {
        switch kind {
        case .sakura:   Color(red: 0.06, green: 0.03, blue: 0.05)
        case .himawari: Color(red: 0.04, green: 0.04, blue: 0.01)
        case .cosmos:   Color(red: 0.04, green: 0.02, blue: 0.06)
        case .tsubaki:  Color(red: 0.06, green: 0.02, blue: 0.02)
        case .asagao:   Color(red: 0.02, green: 0.03, blue: 0.08)
        case .tanpopo:  Color(red: 0.02, green: 0.04, blue: 0.02)
        }
    }

    private func petalBaseColor(_ kind: FlowerKind) -> Color {
        switch kind {
        case .sakura:   Color(hue: mod(0.94 + colorHue * 0.10, 1), saturation: 0.55, brightness: 0.95)
        case .himawari: Color(hue: mod(0.12 + colorHue * 0.08, 1), saturation: 0.92, brightness: 0.98)
        case .cosmos:   Color(hue: mod(0.88 + colorHue * 0.14, 1), saturation: 0.68, brightness: 0.93)
        case .tsubaki:  Color(hue: mod(0.97 + colorHue * 0.08, 1), saturation: 0.78, brightness: 0.88)
        case .asagao:   Color(hue: mod(0.68 + colorHue * 0.18, 1), saturation: 0.72, brightness: 0.88)
        case .tanpopo:  Color(hue: mod(0.14 + colorHue * 0.06, 1), saturation: 0.92, brightness: 0.98)
        }
    }

    private func petalLightColor(_ kind: FlowerKind) -> Color {
        switch kind {
        case .sakura:   Color(hue: mod(0.97 + colorHue * 0.06, 1), saturation: 0.28, brightness: 1.00)
        case .himawari: Color(hue: mod(0.13 + colorHue * 0.06, 1), saturation: 0.75, brightness: 1.00)
        case .cosmos:   Color(hue: mod(0.92 + colorHue * 0.10, 1), saturation: 0.28, brightness: 1.00)
        case .tsubaki:  Color(hue: mod(0.98 + colorHue * 0.05, 1), saturation: 0.22, brightness: 1.00)
        case .asagao:   Color(hue: mod(0.70 + colorHue * 0.12, 1), saturation: 0.30, brightness: 1.00)
        case .tanpopo:  Color(hue: mod(0.14 + colorHue * 0.04, 1), saturation: 0.55, brightness: 1.00)
        }
    }

    private func mod(_ v: Double, _ m: Double) -> Double {
        v.truncatingRemainder(dividingBy: m)
    }

    // MARK: - Dispatch

    private func drawFlower(_ gfx: GraphicsContext, kind: FlowerKind,
                            cx: Double, cy: Double, r: Double) {
        switch kind {
        case .sakura:   drawSakura(gfx, cx: cx, cy: cy, r: r)
        case .himawari: drawHimawari(gfx, cx: cx, cy: cy, r: r)
        case .cosmos:   drawCosmos(gfx, cx: cx, cy: cy, r: r)
        case .tsubaki:  drawTsubaki(gfx, cx: cx, cy: cy, r: r)
        case .asagao:   drawAsagao(gfx, cx: cx, cy: cy, r: r)
        case .tanpopo:  drawTanpopo(gfx, cx: cx, cy: cy, r: r)
        }
    }

    // MARK: - Sakura (5 petals)

    private func drawSakura(_ gfx: GraphicsContext, cx: Double, cy: Double, r: Double) {
        let base    = t * (0.025 + speed * 0.04)
        let breathe = 1.0 + sin(t * (0.38 + speed * 0.28)) * 0.032
        let pLen    = r * breathe
        let pWidth  = pLen * 0.38
        let pColor  = petalBaseColor(.sakura)
        let pLight  = petalLightColor(.sakura)

        for i in 0..<5 {
            let angle = base + Double(i) * 2 * .pi / 5
            let sway  = sin(t * (0.65 + Double(i) * 0.21) + Double(i) * 1.4)
                        * 0.040 * (0.4 + speed)
            let a = angle + sway
            let path = sakuraPetal(cx: cx, cy: cy, angle: a, length: pLen, width: pWidth)

            var gCtx = gfx; gCtx.addFilter(.blur(radius: pLen * 0.10))
            gCtx.fill(path, with: .color(pLight.opacity(0.30)))

            gfx.fill(path, with: .linearGradient(
                Gradient(colors: [pLight.opacity(0.82), pColor.opacity(0.88)]),
                startPoint: CGPoint(x: cx, y: cy),
                endPoint: CGPoint(x: cx + cos(a) * pLen, y: cy + sin(a) * pLen)
            ))
            gfx.stroke(path, with: .color(Color.white.opacity(0.22)), lineWidth: 0.8)
        }
        drawSakuraCenter(gfx, cx: cx, cy: cy, r: r * 0.13)
    }

    private func drawSakuraCenter(_ gfx: GraphicsContext, cx: Double, cy: Double, r: Double) {
        for i in 0..<14 {
            let a  = Double(i) * 2 * .pi / 14 + t * 0.18
            let dr = r * (0.38 + Double(i % 3) * 0.22)
            let sx = cx + cos(a) * dr, sy = cy + sin(a) * dr
            let sr = r * 0.17
            var dot = Path(); dot.addEllipse(in: CGRect(x: sx-sr, y: sy-sr, width: sr*2, height: sr*2))
            gfx.fill(dot, with: .color(Color(hue: 0.14, saturation: 0.85, brightness: 1.0).opacity(0.88)))
        }
        var c = Path(); c.addEllipse(in: CGRect(x: cx-r*0.32, y: cy-r*0.32, width: r*0.64, height: r*0.64))
        gfx.fill(c, with: .color(Color(hue: 0.08, saturation: 0.60, brightness: 0.92).opacity(0.88)))
    }

    // MARK: - Himawari (outer 13 + inner 8 petals)

    private func drawHimawari(_ gfx: GraphicsContext, cx: Double, cy: Double, r: Double) {
        let base    = t * (0.035 + speed * 0.055)
        let breathe = 1.0 + sin(t * (0.32 + speed * 0.22)) * 0.022
        let pColor  = petalBaseColor(.himawari)
        let pDark   = Color(hue: mod(0.10 + colorHue * 0.06, 1), saturation: 0.95, brightness: 0.72)

        // Outer 13
        for i in 0..<13 {
            let angle = base + Double(i) * 2 * .pi / 13
            let wave  = sin(t * (0.75 + Double(i) * 0.14) + Double(i)) * 0.028 * (0.4 + speed)
            let a     = angle + wave
            let pLen  = r * breathe * (1.0 + sin(t * 0.55 + Double(i) * 0.48) * 0.022)
            let path  = himawariPetal(cx: cx, cy: cy, angle: a, length: pLen, width: r * 0.13)

            var gCtx = gfx; gCtx.addFilter(.blur(radius: r * 0.055))
            gCtx.fill(path, with: .color(pColor.opacity(0.22)))

            gfx.fill(path, with: .linearGradient(
                Gradient(colors: [pColor.opacity(0.92), pDark.opacity(0.78)]),
                startPoint: CGPoint(x: cx, y: cy),
                endPoint: CGPoint(x: cx + cos(a) * r, y: cy + sin(a) * r)
            ))
            gfx.stroke(path, with: .color(Color.white.opacity(0.14)), lineWidth: 0.6)
        }
        // Inner 8 (shorter, offset)
        for i in 0..<8 {
            let a    = base + .pi / 13 + Double(i) * 2 * .pi / 8
            let path = himawariPetal(cx: cx, cy: cy, angle: a, length: r * 0.76 * breathe, width: r * 0.10)
            gfx.fill(path, with: .color(pDark.opacity(0.72)))
        }
        drawHimawariCenter(gfx, cx: cx, cy: cy, r: r * 0.30)
    }

    private func drawHimawariCenter(_ gfx: GraphicsContext, cx: Double, cy: Double, r: Double) {
        var disc = Path(); disc.addEllipse(in: CGRect(x: cx-r, y: cy-r, width: r*2, height: r*2))
        gfx.fill(disc, with: .radialGradient(
            Gradient(colors: [Color(red:0.30,green:0.17,blue:0.06), Color(red:0.10,green:0.06,blue:0.02)]),
            center: CGPoint(x: cx, y: cy), startRadius: 0, endRadius: r
        ))
        // Concentric rings
        for ring in 1...5 {
            let rr = r * Double(ring) / 6.0
            var rp = Path(); rp.addEllipse(in: CGRect(x: cx-rr, y: cy-rr, width: rr*2, height: rr*2))
            gfx.stroke(rp, with: .color(Color(red:0.38,green:0.22,blue:0.08).opacity(0.38)), lineWidth: 0.8)
        }
        // Radial spokes
        for spoke in 0..<8 {
            let a = Double(spoke) * .pi / 4 + t * 0.04
            var sp = Path()
            sp.move(to: CGPoint(x: cx, y: cy))
            sp.addLine(to: CGPoint(x: cx + cos(a)*r*0.88, y: cy + sin(a)*r*0.88))
            gfx.stroke(sp, with: .color(Color(red:0.38,green:0.22,blue:0.08).opacity(0.28)), lineWidth: 0.6)
        }
        var hi = Path(); hi.addEllipse(in: CGRect(x: cx-r*0.28, y: cy-r*0.28, width: r*0.56, height: r*0.56))
        gfx.fill(hi, with: .color(Color(red:0.42,green:0.24,blue:0.09).opacity(0.72)))
    }

    // MARK: - Cosmos (8 double-lobed petals)

    private func drawCosmos(_ gfx: GraphicsContext, cx: Double, cy: Double, r: Double) {
        let base    = t * (0.045 + speed * 0.065)
        let breathe = 1.0 + sin(t * (0.42 + speed * 0.32)) * 0.038
        let pLen    = r * breathe
        let pColor  = petalBaseColor(.cosmos)
        let pLight  = petalLightColor(.cosmos)

        for i in 0..<8 {
            let angle = base + Double(i) * 2 * .pi / 8
            let sway  = sin(t * (0.58 + Double(i) * 0.19) + Double(i) * 0.85)
                        * 0.048 * (0.4 + speed)
            let a = angle + sway
            let path = cosmosPetal(cx: cx, cy: cy, angle: a, length: pLen, width: pLen * 0.30)

            var gCtx = gfx; gCtx.addFilter(.blur(radius: pLen * 0.09))
            gCtx.fill(path, with: .color(pColor.opacity(0.26)))

            gfx.fill(path, with: .linearGradient(
                Gradient(colors: [pLight.opacity(0.78), pColor.opacity(0.88)]),
                startPoint: CGPoint(x: cx, y: cy),
                endPoint: CGPoint(x: cx + cos(a) * pLen, y: cy + sin(a) * pLen)
            ))
            gfx.stroke(path, with: .color(Color.white.opacity(0.20)), lineWidth: 0.7)
        }
        drawCosmosCenter(gfx, cx: cx, cy: cy, r: r * 0.13)
    }

    private func drawCosmosCenter(_ gfx: GraphicsContext, cx: Double, cy: Double, r: Double) {
        var outer = Path(); outer.addEllipse(in: CGRect(x: cx-r*1.35, y: cy-r*1.35, width: r*2.7, height: r*2.7))
        gfx.fill(outer, with: .color(Color(hue: 0.13, saturation: 0.80, brightness: 0.96).opacity(0.88)))
        var inner = Path(); inner.addEllipse(in: CGRect(x: cx-r, y: cy-r, width: r*2, height: r*2))
        gfx.fill(inner, with: .color(Color(hue: 0.09, saturation: 0.88, brightness: 0.88).opacity(0.90)))
        var hi = Path(); hi.addEllipse(in: CGRect(x: cx-r*0.4, y: cy-r*0.55, width: r*0.55, height: r*0.4))
        gfx.fill(hi, with: .color(Color.white.opacity(0.22)))
    }

    // MARK: - Tsubaki (椿: outer 6 + inner 6 rounded petals)

    private func drawTsubaki(_ gfx: GraphicsContext, cx: Double, cy: Double, r: Double) {
        let baseOuter = t * (0.022 + speed * 0.035)
        let baseInner = t * (0.032 + speed * 0.050)
        let breathe   = 1.0 + sin(t * (0.36 + speed * 0.26)) * 0.028
        let pColor    = petalBaseColor(.tsubaki)
        let pLight    = petalLightColor(.tsubaki)
        let pDark     = Color(hue: mod(0.97 + colorHue * 0.06, 1), saturation: 0.82, brightness: 0.68)

        // Outer 6 petals
        for i in 0..<6 {
            let angle = baseOuter + Double(i) * 2 * .pi / 6
            let sway  = sin(t * (0.50 + Double(i) * 0.18) + Double(i)) * 0.028 * (0.4 + speed)
            let a     = angle + sway
            let path  = tsubakiPetal(cx: cx, cy: cy, angle: a,
                                      length: r * breathe, width: r * 0.34)
            var gCtx = gfx; gCtx.addFilter(.blur(radius: r * 0.09))
            gCtx.fill(path, with: .color(pLight.opacity(0.28)))
            gfx.fill(path, with: .linearGradient(
                Gradient(colors: [pLight.opacity(0.80), pColor.opacity(0.88)]),
                startPoint: CGPoint(x: cx, y: cy),
                endPoint:   CGPoint(x: cx + cos(a)*r, y: cy + sin(a)*r)
            ))
            gfx.stroke(path, with: .color(Color.white.opacity(0.20)), lineWidth: 0.8)
        }
        // Inner 6 petals (shorter, offset 30°)
        for i in 0..<6 {
            let angle = baseInner + .pi / 6 + Double(i) * 2 * .pi / 6
            let sway  = sin(t * (0.55 + Double(i) * 0.20) + Double(i) * 1.1) * 0.024 * (0.4 + speed)
            let a     = angle + sway
            let path  = tsubakiPetal(cx: cx, cy: cy, angle: a,
                                      length: r * 0.72 * breathe, width: r * 0.28)
            gfx.fill(path, with: .linearGradient(
                Gradient(colors: [pColor.opacity(0.84), pDark.opacity(0.82)]),
                startPoint: CGPoint(x: cx, y: cy),
                endPoint:   CGPoint(x: cx + cos(a)*r*0.72, y: cy + sin(a)*r*0.72)
            ))
            gfx.stroke(path, with: .color(Color.white.opacity(0.18)), lineWidth: 0.7)
        }
        drawTsubakiCenter(gfx, cx: cx, cy: cy, r: r * 0.18)
    }

    private func drawTsubakiCenter(_ gfx: GraphicsContext, cx: Double, cy: Double, r: Double) {
        var base = Path()
        base.addEllipse(in: CGRect(x: cx-r*1.1, y: cy-r*1.1, width: r*2.2, height: r*2.2))
        gfx.fill(base, with: .color(Color(hue: 0.14, saturation: 0.72, brightness: 0.92).opacity(0.90)))
        for i in 0..<18 {
            let a  = Double(i) * 2 * .pi / 18 + t * 0.12
            let dr = r * (0.30 + Double(i % 3) * 0.24)
            let sx = cx + cos(a) * dr, sy = cy + sin(a) * dr
            let sr = r * 0.14
            var dot = Path()
            dot.addEllipse(in: CGRect(x: sx-sr, y: sy-sr, width: sr*2, height: sr*2))
            gfx.fill(dot, with: .color(Color(hue: 0.13, saturation: 0.85,
                                              brightness: i % 2 == 0 ? 1.0 : 0.84).opacity(0.92)))
        }
    }

    // MARK: - Asagao (朝顔: single fused bell corolla)

    private func drawAsagao(_ gfx: GraphicsContext, cx: Double, cy: Double, r: Double) {
        let base    = t * (0.018 + speed * 0.028)
        let breathe = 1.0 + sin(t * (0.40 + speed * 0.30)) * 0.030
        let r2      = r * breathe
        let pColor  = petalBaseColor(.asagao)
        let pLight  = petalLightColor(.asagao)

        let shape = asagaoShape(cx: cx, cy: cy, angle: base, r: r2)

        // Glow
        var gCtx = gfx; gCtx.addFilter(.blur(radius: r * 0.14))
        gCtx.fill(shape, with: .color(pColor.opacity(0.32)))

        // Radial fill: white center → colored edge
        gfx.fill(shape, with: .radialGradient(
            Gradient(stops: [
                .init(color: Color.white.opacity(0.95),  location: 0.00),
                .init(color: pLight.opacity(0.85),       location: 0.28),
                .init(color: pColor.opacity(0.90),       location: 0.68),
                .init(color: pColor.opacity(1.00),       location: 1.00),
            ]),
            center: CGPoint(x: cx, y: cy), startRadius: 0, endRadius: r2
        ))
        gfx.stroke(shape, with: .color(Color.white.opacity(0.18)), lineWidth: 1.0)

        // 5 radial stripes
        for i in 0..<5 {
            let sa  = base + Double(i) * 2 * .pi / 5
            let bri = 0.55 + 0.20 * sin(t * (0.8 + Double(i) * 0.15) + Double(i))
            var sp  = Path()
            sp.move(to: CGPoint(x: cx, y: cy))
            sp.addLine(to: CGPoint(x: cx + cos(sa) * r2, y: cy + sin(sa) * r2))
            gfx.stroke(sp, with: .color(Color.white.opacity(bri * 0.55)), lineWidth: 1.2)
        }

        // Inner throat
        let throatR = r2 * 0.22
        var throat  = Path()
        throat.addEllipse(in: CGRect(x: cx-throatR, y: cy-throatR,
                                      width: throatR*2, height: throatR*2))
        gfx.fill(throat, with: .radialGradient(
            Gradient(colors: [Color.white, pLight.opacity(0.80)]),
            center: CGPoint(x: cx, y: cy), startRadius: 0, endRadius: throatR
        ))
        // Stamens
        for i in 0..<5 {
            let a  = base + Double(i) * 2 * .pi / 5 + .pi / 5
            let sr = throatR * 0.58
            let sx = cx + cos(a) * sr, sy = cy + sin(a) * sr
            var dot = Path(); dot.addEllipse(in: CGRect(x: sx-2, y: sy-2, width: 4, height: 4))
            gfx.fill(dot, with: .color(Color(hue: 0.12, saturation: 0.80, brightness: 0.95).opacity(0.90)))
        }
    }

    // MARK: - Tanpopo (たんぽぽ: 32 narrow ray florets)

    private func drawTanpopo(_ gfx: GraphicsContext, cx: Double, cy: Double, r: Double) {
        let base   = t * (0.020 + speed * 0.032)
        let pColor = petalBaseColor(.tanpopo)
        let pLight = petalLightColor(.tanpopo)
        let count  = 32

        for i in 0..<count {
            let fi    = Double(i)
            let angle = base + fi * 2 * .pi / Double(count)
            // Wave sweeps around the flower like a breeze
            let wave  = sin(t * (0.50 + speed * 0.80) - fi * 0.36) * 0.038 * (0.4 + speed)
            let a     = angle + wave
            let lf    = 0.95 + sin(fi * 2.3 + t * 0.28) * 0.055
            let path  = tanpopoPetal(cx: cx, cy: cy, angle: a, length: r * lf)

            gfx.fill(path, with: .linearGradient(
                Gradient(colors: [pLight.opacity(0.90), pColor.opacity(0.88)]),
                startPoint: CGPoint(x: cx, y: cy),
                endPoint:   CGPoint(x: cx + cos(a)*r*lf, y: cy + sin(a)*r*lf)
            ))
            gfx.stroke(path, with: .color(Color.white.opacity(0.14)), lineWidth: 0.5)
        }
        drawTanpopoCenter(gfx, cx: cx, cy: cy, r: r * 0.19)
    }

    private func drawTanpopoCenter(_ gfx: GraphicsContext, cx: Double, cy: Double, r: Double) {
        var disc = Path()
        disc.addEllipse(in: CGRect(x: cx-r, y: cy-r, width: r*2, height: r*2))
        gfx.fill(disc, with: .radialGradient(
            Gradient(colors: [Color(red:0.98,green:0.76,blue:0.10), Color(red:0.88,green:0.54,blue:0.05)]),
            center: CGPoint(x: cx, y: cy), startRadius: 0, endRadius: r
        ))
        for i in 0..<12 {
            let a  = Double(i) * 2 * .pi / 12 + t * 0.08
            let dr = r * 0.55
            let sx = cx + cos(a) * dr, sy = cy + sin(a) * dr
            let sr = r * 0.18
            var dot = Path(); dot.addEllipse(in: CGRect(x: sx-sr, y: sy-sr, width: sr*2, height: sr*2))
            gfx.fill(dot, with: .color(Color(red:0.95,green:0.64,blue:0.08).opacity(0.80)))
        }
    }

    // MARK: - Floating background petals

    private func drawFloatingPetals(_ gfx: GraphicsContext, cx: Double, cy: Double, size: CGSize) {
        let spread = min(size.width, size.height) * 0.44
        for i in 0..<8 {
            let fi    = Double(i)
            let angle = fi * 2.3999 + t * (0.04 + fi * 0.008) * (0.3 + speed * 0.35)
            let dist  = sqrt((fi + 1) / 8.0) * spread
            let px    = cx + cos(angle) * dist
            let py    = cy + sin(angle) * dist
            let pr    = spread * (0.08 + sin(fi * 3.1) * 0.025)
            let alpha = 0.07 + sin(fi * 1.4 + t * 0.25) * 0.04
            let path  = sakuraPetal(cx: px, cy: py, angle: angle + .pi,
                                    length: pr, width: pr * 0.38)
            gfx.fill(path, with: .color(petalBaseColor(nextKind).opacity(alpha)))
        }
    }

    // MARK: - Petal paths

    private func sakuraPetal(cx: Double, cy: Double, angle: Double,
                              length: Double, width: Double) -> Path {
        let ca = cos(angle), sa = sin(angle)
        let cp = cos(angle + .pi/2), sp = sin(angle + .pi/2)
        let tipX = cx + ca * length, tipY = cy + sa * length
        let nd = length * 0.12
        let nX = tipX - ca * nd, nY = tipY - sa * nd
        let lo = width * 0.50
        let lTipX = tipX + cp * lo - ca * nd * 0.3
        let lTipY = tipY + sp * lo - sa * nd * 0.3
        let rTipX = tipX - cp * lo - ca * nd * 0.3
        let rTipY = tipY - sp * lo - sa * nd * 0.3
        let md = length * 0.55
        let lMx = cx + ca * md + cp * width, lMy = cy + sa * md + sp * width
        let rMx = cx + ca * md - cp * width, rMy = cy + sa * md - sp * width

        var p = Path()
        p.move(to: CGPoint(x: cx + cp*width*0.20, y: cy + sp*width*0.20))
        p.addCurve(to: CGPoint(x: lTipX, y: lTipY),
                   control1: CGPoint(x: lMx, y: lMy),
                   control2: CGPoint(x: lTipX - ca*length*0.14 + cp*width*0.10,
                                     y: lTipY - sa*length*0.14 + sp*width*0.10))
        p.addCurve(to: CGPoint(x: rTipX, y: rTipY),
                   control1: CGPoint(x: nX + cp*width*0.04, y: nY + sp*width*0.04),
                   control2: CGPoint(x: nX - cp*width*0.04, y: nY - sp*width*0.04))
        p.addCurve(to: CGPoint(x: cx - cp*width*0.20, y: cy - sp*width*0.20),
                   control1: CGPoint(x: rTipX - ca*length*0.14 - cp*width*0.10,
                                     y: rTipY - sa*length*0.14 - sp*width*0.10),
                   control2: CGPoint(x: rMx, y: rMy))
        p.addCurve(to: CGPoint(x: cx + cp*width*0.20, y: cy + sp*width*0.20),
                   control1: CGPoint(x: cx - ca*length*0.05, y: cy - sa*length*0.05),
                   control2: CGPoint(x: cx - ca*length*0.05, y: cy - sa*length*0.05))
        return p
    }

    private func himawariPetal(cx: Double, cy: Double, angle: Double,
                                length: Double, width: Double) -> Path {
        let ca = cos(angle), sa = sin(angle)
        let cp = cos(angle + .pi/2), sp = sin(angle + .pi/2)
        let startDist = length * 0.27
        let bx = cx + ca * startDist, by = cy + sa * startDist
        let tipX = cx + ca * length, tipY = cy + sa * length
        let md = length * 0.58
        let lMx = cx + ca*md + cp*width, lMy = cy + sa*md + sp*width
        let rMx = cx + ca*md - cp*width, rMy = cy + sa*md - sp*width

        var p = Path()
        p.move(to: CGPoint(x: bx + cp*width*0.45, y: by + sp*width*0.45))
        p.addCurve(to: CGPoint(x: tipX, y: tipY),
                   control1: CGPoint(x: lMx, y: lMy),
                   control2: CGPoint(x: tipX + cp*width*0.22, y: tipY + sp*width*0.22))
        p.addCurve(to: CGPoint(x: bx - cp*width*0.45, y: by - sp*width*0.45),
                   control1: CGPoint(x: tipX - cp*width*0.22, y: tipY - sp*width*0.22),
                   control2: CGPoint(x: rMx, y: rMy))
        p.addLine(to: CGPoint(x: bx + cp*width*0.45, y: by + sp*width*0.45))
        return p
    }

    // Tsubaki petal: smooth rounded oval, no notch
    private func tsubakiPetal(cx: Double, cy: Double, angle: Double,
                               length: Double, width: Double) -> Path {
        let ca = cos(angle), sa = sin(angle)
        let cp = cos(angle + .pi/2), sp = sin(angle + .pi/2)
        let tipX = cx + ca * length, tipY = cy + sa * length
        let md   = length * 0.45
        let lMx  = cx + ca*md + cp*width, lMy = cy + sa*md + sp*width
        let rMx  = cx + ca*md - cp*width, rMy = cy + sa*md - sp*width

        var p = Path()
        p.move(to: CGPoint(x: cx + cp*width*0.25, y: cy + sp*width*0.25))
        p.addCurve(
            to: CGPoint(x: tipX, y: tipY),
            control1: CGPoint(x: lMx, y: lMy),
            control2: CGPoint(x: tipX + cp*width*0.15, y: tipY + sp*width*0.15)
        )
        p.addCurve(
            to: CGPoint(x: cx - cp*width*0.25, y: cy - sp*width*0.25),
            control1: CGPoint(x: tipX - cp*width*0.15, y: tipY - sp*width*0.15),
            control2: CGPoint(x: rMx, y: rMy)
        )
        p.addCurve(
            to: CGPoint(x: cx + cp*width*0.25, y: cy + sp*width*0.25),
            control1: CGPoint(x: cx - ca*length*0.05, y: cy - sa*length*0.05),
            control2: CGPoint(x: cx - ca*length*0.05, y: cy - sa*length*0.05)
        )
        return p
    }

    // Asagao: single fused 5-lobe bell shape
    private func asagaoShape(cx: Double, cy: Double, angle: Double, r: Double) -> Path {
        let n      = 5
        let lobeR  = r
        let valR   = r * 0.83
        let step   = 2 * Double.pi / Double(n)

        var path = Path()
        let sv = angle - step / 2
        path.move(to: CGPoint(x: cx + cos(sv) * valR, y: cy + sin(sv) * valR))

        for i in 0..<n {
            let la  = angle + Double(i) * step
            let nva = la + step / 2
            let liA = la - step * 0.38
            let loA = la + step * 0.38

            path.addCurve(
                to: CGPoint(x: cx + cos(la) * lobeR, y: cy + sin(la) * lobeR),
                control1: CGPoint(x: cx + cos(liA) * lobeR * 0.99,
                                  y: cy + sin(liA) * lobeR * 0.99),
                control2: CGPoint(x: cx + cos(la - step*0.08) * lobeR * 1.02,
                                  y: cy + sin(la - step*0.08) * lobeR * 1.02)
            )
            path.addCurve(
                to: CGPoint(x: cx + cos(nva) * valR, y: cy + sin(nva) * valR),
                control1: CGPoint(x: cx + cos(la + step*0.08) * lobeR * 1.02,
                                  y: cy + sin(la + step*0.08) * lobeR * 1.02),
                control2: CGPoint(x: cx + cos(loA) * lobeR * 0.99,
                                  y: cy + sin(loA) * lobeR * 0.99)
            )
        }
        path.closeSubpath()
        return path
    }

    // Tanpopo ray floret: narrow spatula shape with rounded tip
    private func tanpopoPetal(cx: Double, cy: Double, angle: Double, length: Double) -> Path {
        let ca    = cos(angle), sa = sin(angle)
        let cp    = cos(angle + .pi/2), sp = sin(angle + .pi/2)
        let baseW = length * 0.055
        let tipW  = length * 0.082
        let sd    = length * 0.24
        let bx    = cx + ca * sd, by = cy + sa * sd
        let tipX  = cx + ca * length, tipY = cy + sa * length

        var p = Path()
        p.move(to: CGPoint(x: bx + cp*baseW, y: by + sp*baseW))
        p.addCurve(
            to: CGPoint(x: tipX + cp*tipW, y: tipY + sp*tipW),
            control1: CGPoint(x: cx + ca*length*0.55 + cp*tipW*0.60,
                              y: cy + sa*length*0.55 + sp*tipW*0.60),
            control2: CGPoint(x: tipX - ca*length*0.04 + cp*tipW,
                              y: tipY - sa*length*0.04 + sp*tipW)
        )
        p.addArc(
            center: CGPoint(x: tipX, y: tipY),
            radius: CGFloat(tipW),
            startAngle: .radians(angle + .pi/2),
            endAngle:   .radians(angle - .pi/2),
            clockwise:  false
        )
        p.addCurve(
            to: CGPoint(x: bx - cp*baseW, y: by - sp*baseW),
            control1: CGPoint(x: tipX - ca*length*0.04 - cp*tipW,
                              y: tipY - sa*length*0.04 - sp*tipW),
            control2: CGPoint(x: cx + ca*length*0.55 - cp*tipW*0.60,
                              y: cy + sa*length*0.55 - sp*tipW*0.60)
        )
        p.addLine(to: CGPoint(x: bx + cp*baseW, y: by + sp*baseW))
        return p
    }

    private func cosmosPetal(cx: Double, cy: Double, angle: Double,
                              length: Double, width: Double) -> Path {
        let ca = cos(angle), sa = sin(angle)
        let cp = cos(angle + .pi/2), sp = sin(angle + .pi/2)
        let tipX = cx + ca * length, tipY = cy + sa * length
        let nd = length * 0.20
        let nX = tipX - ca * nd, nY = tipY - sa * nd
        let lo = width * 0.48
        let lTipX = tipX + cp*lo - ca*nd*0.2, lTipY = tipY + sp*lo - sa*nd*0.2
        let rTipX = tipX - cp*lo - ca*nd*0.2, rTipY = tipY - sp*lo - sa*nd*0.2
        let md = length * 0.52
        let lMx = cx + ca*md + cp*width, lMy = cy + sa*md + sp*width
        let rMx = cx + ca*md - cp*width, rMy = cy + sa*md - sp*width

        var p = Path()
        p.move(to: CGPoint(x: cx + cp*width*0.15, y: cy + sp*width*0.15))
        p.addCurve(to: CGPoint(x: lTipX, y: lTipY),
                   control1: CGPoint(x: lMx, y: lMy),
                   control2: CGPoint(x: lTipX - ca*length*0.12 + cp*width*0.14,
                                     y: lTipY - sa*length*0.12 + sp*width*0.14))
        p.addCurve(to: CGPoint(x: rTipX, y: rTipY),
                   control1: CGPoint(x: nX + cp*2, y: nY + sp*2),
                   control2: CGPoint(x: nX - cp*2, y: nY - sp*2))
        p.addCurve(to: CGPoint(x: cx - cp*width*0.15, y: cy - sp*width*0.15),
                   control1: CGPoint(x: rTipX - ca*length*0.12 - cp*width*0.14,
                                     y: rTipY - sa*length*0.12 - sp*width*0.14),
                   control2: CGPoint(x: rMx, y: rMy))
        p.addCurve(to: CGPoint(x: cx + cp*width*0.15, y: cy + sp*width*0.15),
                   control1: CGPoint(x: cx, y: cy),
                   control2: CGPoint(x: cx, y: cy))
        return p
    }
}

// MARK: - FlowerView

struct FlowerView: View {
    let onPickerTap: () -> Void

    @StateObject private var recorder = WallpaperRecorder()

    @State private var speed:    Double = 0.5
    @State private var colorHue: Double = 0.0
    @State private var showUI:   Bool   = true
    @State private var isAutoMode: Bool = false

    @State private var currentFlower: FlowerKind = FlowerOrder.shared.sequence[0]
    @State private var nextFlower:    FlowerKind = FlowerOrder.shared.sequence[0]
    @State private var morphProgress: Double = 1.0

    @State private var nextFlowerAt:    Date   = .distantPast
    @State private var autoColorTarget: Double = 0.0
    @State private var lastAutoTick:    Date?  = nil

    @State private var isIdle:        Bool = false
    @State private var lastTouchDate: Date = .now

    private let accent          = Color(red: 1.00, green: 0.60, blue: 0.75)
    private let idleCheckTimer  = Timer.publish(every: 5.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if recorder.isActive {
                recordingOverlay
            } else {
                TimelineView(.animation(minimumInterval: isIdle ? 1.0/15.0 : (showUI ? 1.0/30.0 : 1.0/20.0))) { tl in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    ZStack {
                        FlowerCanvas(t: t, kind: currentFlower, nextKind: nextFlower,
                                     morphProgress: morphProgress,
                                     speed: speed, colorHue: colorHue)
                            .ignoresSafeArea()
                            .onTapGesture {
                                lastTouchDate = .now
                                isIdle = false
                                withAnimation(.easeInOut(duration: 0.3)) { showUI.toggle() }
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
            }
        }
        .onAppear {
            speed    = Double.random(in: 0.3...0.7)
            colorHue = Double.random(in: 0.0...1.0)
            FlowerOrder.shared.reshuffle()
            currentFlower = FlowerOrder.shared.sequence[0]
            nextFlower    = currentFlower
            morphProgress = 1.0
            scheduleNextFlower()
        }
        .onReceive(idleCheckTimer) { _ in
            if Date().timeIntervalSince(lastTouchDate) >= 60 { isIdle = true }
        }
        .onReceive(Timer.publish(every: 1.0/10.0, on: .main, in: .common).autoconnect()) { now in
            // Morph progress (1.5s transition)
            if morphProgress < 1.0 {
                morphProgress = min(1.0, morphProgress + (1.0/10.0) / 1.5)
                if morphProgress >= 1.0 { currentFlower = nextFlower }
            }
            // Schedule next flower
            if morphProgress >= 1.0 && now >= nextFlowerAt {
                nextFlower    = FlowerOrder.shared.next(after: currentFlower)
                morphProgress = 0.0
                scheduleNextFlower()
            }
            // AUTO: color drift
            guard isAutoMode else { lastAutoTick = nil; return }
            let dt = min(lastAutoTick.map { now.timeIntervalSince($0) } ?? (1.0/10.0), 0.5)
            lastAutoTick = now
            colorHue += (autoColorTarget - colorHue) * 0.008 * dt * 60
            colorHue  = colorHue.truncatingRemainder(dividingBy: 1.0)
            if colorHue < 0 { colorHue += 1.0 }
        }
    }

    private func scheduleNextFlower() {
        nextFlowerAt    = Date().addingTimeInterval(Double.random(in: 8...13))
        autoColorTarget = Double.random(in: 0...1)
    }

    // MARK: - Recording Overlay

    @ViewBuilder
    private var recordingOverlay: some View {
        ZStack {
            Color(red: 0.06, green: 0.03, blue: 0.05).ignoresSafeArea()
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
                Text("FLOWER")
                    .font(.system(size: 38, weight: .black, design: .monospaced))
                    .tracking(6)
                    .foregroundStyle(LinearGradient(
                        colors: [accent, accent.opacity(0.55)],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .shadow(color: accent.opacity(0.9), radius: 14)
                Text(currentFlower.rawValue)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(3)
                    .foregroundColor(accent.opacity(0.60))
                    .animation(.easeInOut(duration: 0.4), value: currentFlower)
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
                if isAutoMode { scheduleNextFlower(); lastAutoTick = nil }
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
                let startT = Date.timeIntervalSinceReferenceDate
                Task {
                    await recorder.startFlower(kind: currentFlower, speed: speed,
                                               colorHue: colorHue, startT: startT)
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
                .frame(width: 52, alignment: .trailing)
        }
    }

    private var speedLabel: String {
        switch speed {
        case ..<0.25: "STILL"; case 0.25..<0.5: "BREEZE"
        case 0.5..<0.75: "SWAY"; default: "DANCE"
        }
    }

    private var colorLabel: String {
        switch colorHue {
        case ..<0.125:      "CRIMSON"
        case 0.125..<0.25:  "CORAL"
        case 0.25..<0.375:  "GOLD"
        case 0.375..<0.5:   "SAGE"
        case 0.5..<0.625:   "SKY"
        case 0.625..<0.75:  "IRIS"
        case 0.75..<0.875:  "VIOLET"
        default:             "BLUSH"
        }
    }
}

#Preview { FlowerView(onPickerTap: {}) }
