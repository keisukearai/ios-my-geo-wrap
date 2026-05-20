import SwiftUI

// Side-view cartoon elephant drawn with black outlines only (no fill).
// Coordinate space: 500 × 400 points, scaled uniformly to fit the view.
struct ElephantLineView: View {
    var strokeColor: Color = .black
    var lineWidth: CGFloat = 5

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width / 500, geo.size.height / 400)
            let ox = (geo.size.width  - 500 * s) / 2
            let oy = (geo.size.height - 400 * s) / 2
            Canvas { ctx, _ in
                draw(ctx: ctx, s: s, ox: ox, oy: oy)
            }
        }
        .aspectRatio(5.0 / 4.0, contentMode: .fit)
    }

    private func draw(ctx: GraphicsContext, s: CGFloat, ox: CGFloat, oy: CGFloat) {
        let sh = GraphicsContext.Shading.color(strokeColor)
        let lw = lineWidth

        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: ox + x * s, y: oy + y * s)
        }
        func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
            CGRect(x: ox + x * s, y: oy + y * s, width: w * s, height: h * s)
        }

        // Ear — draw first so head renders on top
        ctx.stroke(Path(ellipseIn: r(232, 16, 148, 208)), with: sh, lineWidth: lw)

        // Body
        ctx.stroke(Path(ellipseIn: r(18, 128, 330, 192)), with: sh, lineWidth: lw)

        // Head
        ctx.stroke(Path(ellipseIn: r(308, 58, 158, 155)), with: sh, lineWidth: lw)

        // Trunk (thick bezier, two segments)
        var trunk = Path()
        trunk.move(to: pt(458, 188))
        trunk.addCurve(to: pt(466, 284),
                       control1: pt(484, 220),
                       control2: pt(486, 262))
        trunk.addCurve(to: pt(428, 296),
                       control1: pt(463, 300),
                       control2: pt(444, 302))
        ctx.stroke(trunk, with: sh, lineWidth: lw * 2.4)

        // Tusk (small upward-curving arc)
        var tusk = Path()
        tusk.move(to: pt(430, 208))
        tusk.addQuadCurve(to: pt(474, 190), control: pt(453, 218))
        ctx.stroke(tusk, with: sh, lineWidth: lw)

        // Front legs (U-shape: left side, rounded bottom, right side)
        for lx: CGFloat in [292, 240] {
            var leg = Path()
            leg.move(to: pt(lx, 300))
            leg.addLine(to: pt(lx, 370))
            leg.addArc(center: pt(lx + 22.5, 370),
                       radius: 22.5 * s,
                       startAngle: .degrees(180), endAngle: .degrees(0),
                       clockwise: false)
            leg.addLine(to: pt(lx + 45, 300))
            ctx.stroke(leg, with: sh, lineWidth: lw)
        }

        // Back legs
        for lx: CGFloat in [122, 65] {
            var leg = Path()
            leg.move(to: pt(lx, 300))
            leg.addLine(to: pt(lx, 370))
            leg.addArc(center: pt(lx + 22.5, 370),
                       radius: 22.5 * s,
                       startAngle: .degrees(180), endAngle: .degrees(0),
                       clockwise: false)
            leg.addLine(to: pt(lx + 45, 300))
            ctx.stroke(leg, with: sh, lineWidth: lw)
        }

        // Eye (filled dot)
        ctx.fill(Path(ellipseIn: r(391, 104, 17, 17)), with: sh)

        // Tail
        var tail = Path()
        tail.move(to: pt(22, 192))
        tail.addQuadCurve(to: pt(10, 250), control: pt(14, 228))
        ctx.stroke(tail, with: sh, lineWidth: lw)
    }
}

#Preview {
    ElephantLineView()
        .frame(width: 350, height: 280)
        .background(Color.white)
        .padding()
}
