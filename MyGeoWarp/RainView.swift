import SwiftUI
import Combine

// MARK: - Rain Shape

enum RainShape: String, CaseIterable {
    case circle   = "CIRCLE"
    case ellipse  = "ELLIPSE"
    case rect     = "RECT"
    case triangle = "TRI"
    case star     = "STAR"
}

// MARK: - Rain Frame (for Live Photo recording)

struct RainFrame: View {
    var t: Double
    let speed: Double
    let colorHue: Double
    let shape: RainShape
    let size: CGSize

    var body: some View {
        RainCanvas(t: t, speed: speed, colorHue: colorHue, shape: shape)
            .frame(width: size.width, height: size.height)
    }
}

// MARK: - Rain Canvas

struct RainCanvas: View {
    let t: Double
    let speed: Double      // 0..1
    let colorHue: Double   // 0..1
    let shape: RainShape

    private struct Drop {
        let xFrac:     Double
        let yFrac:     Double
        let phase:     Double
        let scaleFrac: Double
    }

    private static let drops: [Drop] = (0..<20).map { i in
        let fi = Double(i)
        return Drop(
            xFrac:     (sin(fi * 127.1) * 0.5 + 0.5) * 0.85 + 0.075,
            yFrac:     (sin(fi * 311.7) * 0.5 + 0.5) * 0.85 + 0.075,
            phase:     abs(sin(fi * 73.4)),
            scaleFrac: 0.6 + abs(sin(fi * 41.3)) * 0.6
        )
    }

    var body: some View {
        Canvas { [self] gfx, size in
            drawBackground(gfx, size)
            for drop in Self.drops {
                drawRipple(gfx, size, drop: drop)
            }
            drawVignette(gfx, size)
        }
        .background(Color(red: 0.01, green: 0.03, blue: 0.07))
    }

    private func rippleColor() -> Color {
        // 0 = teal/cyan, 1 = deep blue
        let teal = SIMD3<Double>(0.20, 0.90, 0.85)
        let blue = SIMD3<Double>(0.28, 0.50, 1.00)
        let c = teal + (blue - teal) * max(0, min(1, colorHue))
        return Color(red: c.x, green: c.y, blue: c.z)
    }

    private func drawBackground(_ gfx: GraphicsContext, _ size: CGSize) {
        var path = Path()
        path.addRect(CGRect(origin: .zero, size: size))
        gfx.fill(path, with: .color(Color(red: 0.01, green: 0.03, blue: 0.07)))
    }

    private func drawRipple(_ gfx: GraphicsContext, _ size: CGSize, drop: Drop) {
        let effectiveSpeed = 0.2 + speed * 1.4
        let dropInterval   = 5.0 / effectiveSpeed

        let cx   = drop.xFrac * size.width
        let cy   = drop.yFrac * size.height
        let maxR = (50.0 + drop.scaleFrac * 70.0) * min(size.width, size.height) / 390.0

        let cycleTime = (t + drop.phase * dropInterval).truncatingRemainder(dividingBy: dropInterval)
        let progress  = cycleTime / dropInterval

        let col = rippleColor()

        for ring in 0..<3 {
            let delay = Double(ring) * 0.20
            let rp    = max(0, progress - delay)
            guard rp > 0 && rp < 1.0 else { continue }

            let radius    = maxR * easeOut(rp)
            let alpha     = pow(1.0 - rp, 1.6) * 0.75
            let lineWidth = max(0.4, 1.8 - rp * 1.2)

            gfx.stroke(ripplePath(cx: cx, cy: cy, radius: radius),
                       with: .color(col.opacity(alpha)),
                       style: StrokeStyle(lineWidth: lineWidth))
        }

        if progress < 0.10 {
            let dotAlpha  = (0.10 - progress) / 0.10
            let dotRadius = 3.0 * dotAlpha
            var dot = Path()
            dot.addEllipse(in: CGRect(
                x: cx - dotRadius, y: cy - dotRadius,
                width: dotRadius * 2, height: dotRadius * 2
            ))
            gfx.fill(dot, with: .color(col.opacity(dotAlpha)))
        }
    }

    private func ripplePath(cx: Double, cy: Double, radius: Double) -> Path {
        var path = Path()
        switch shape {
        case .circle:
            path.addEllipse(in: CGRect(x: cx - radius, y: cy - radius,
                                       width: radius * 2, height: radius * 2))
        case .ellipse:
            let rx = radius * 1.6, ry = radius * 0.72
            path.addEllipse(in: CGRect(x: cx - rx, y: cy - ry,
                                       width: rx * 2, height: ry * 2))
        case .rect:
            let hw = radius * 1.35, hh = radius * 1.0
            path.addRoundedRect(in: CGRect(x: cx - hw, y: cy - hh,
                                           width: hw * 2, height: hh * 2),
                                cornerSize: CGSize(width: 6, height: 6))
        case .triangle:
            path.move(to:    CGPoint(x: cx,              y: cy - radius))
            path.addLine(to: CGPoint(x: cx + radius * 0.866, y: cy + radius * 0.5))
            path.addLine(to: CGPoint(x: cx - radius * 0.866, y: cy + radius * 0.5))
            path.closeSubpath()
        case .star:
            let inner = radius * 0.382
            for i in 0..<10 {
                let angle = Double(i) * .pi / 5 - .pi / 2
                let r     = i.isMultiple(of: 2) ? radius : inner
                let pt    = CGPoint(x: cx + cos(angle) * r, y: cy + sin(angle) * r)
                i == 0 ? path.move(to: pt) : path.addLine(to: pt)
            }
            path.closeSubpath()
        }
        return path
    }

    private func easeOut(_ x: Double) -> Double {
        1 - pow(1 - x, 2)
    }

    private func drawVignette(_ gfx: GraphicsContext, _ size: CGSize) {
        var path = Path()
        path.addRect(CGRect(origin: .zero, size: size))
        gfx.fill(path, with: .radialGradient(
            Gradient(colors: [.clear, Color.black.opacity(0.70)]),
            center:      CGPoint(x: size.width / 2, y: size.height / 2),
            startRadius: min(size.width, size.height) * 0.22,
            endRadius:   max(size.width, size.height) * 0.72
        ))
    }
}

// MARK: - RainView

struct RainView: View {
    let onPickerTap: () -> Void

    @State private var speed:    Double    = 0.5
    @State private var colorHue: Double    = 0.0
    @State private var shape:    RainShape = .circle
    @State private var showUI:   Bool      = true

    @State private var isIdle:        Bool = false
    @State private var lastTouchDate: Date = .now

    @StateObject private var recorder = WallpaperRecorder()

    private let accent          = Color(red: 0.20, green: 0.90, blue: 0.85)
    private let idleCheckTimer  = Timer.publish(every: 5.0, on: .main, in: .common).autoconnect()

    private var currentColor: Color {
        let teal = SIMD3<Double>(0.20, 0.90, 0.85)
        let blue = SIMD3<Double>(0.28, 0.50, 1.00)
        let c = teal + (blue - teal) * max(0, min(1, colorHue))
        return Color(red: c.x, green: c.y, blue: c.z)
    }

    var body: some View {
        ZStack {
            Color(red: 0.01, green: 0.03, blue: 0.07).ignoresSafeArea()
            if recorder.isActive {
                recordingOverlay
            } else {
                TimelineView(.animation(minimumInterval: isIdle ? 1.0/15.0 : (showUI ? 1.0/30.0 : 1.0/20.0))) { tl in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    ZStack {
                        RainCanvas(t: t, speed: speed, colorHue: colorHue, shape: shape)
                            .ignoresSafeArea()
                            .onTapGesture {
                                lastTouchDate = .now
                                isIdle = false
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showUI.toggle()
                                }
                            }

                        VStack(spacing: 0) {
                            headerView
                            Spacer()
                            controlsView
                                .padding(.bottom, 40)
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
            colorHue = Double.random(in: 0...1)
        }
        .overlay(alignment: .bottomTrailing) {
            Text(isIdle ? "15fps" : (showUI ? "30fps" : "20fps"))
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.35))
                .padding(.trailing, 10).padding(.bottom, 12)
                .allowsHitTesting(false)
        }
        .onReceive(idleCheckTimer) { _ in
            if Date().timeIntervalSince(lastTouchDate) >= 60 { isIdle = true }
        }
    }

    // MARK: - Recording Overlay

    @ViewBuilder
    private var recordingOverlay: some View {
        ZStack {
            Color(red: 0.01, green: 0.03, blue: 0.07).ignoresSafeArea()
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
                            .tint(currentColor)
                            .padding(.horizontal, 40)
                        Text("\(Int(p * 100))%")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                    }
                } else if case .saving = recorder.state {
                    ProgressView().tint(currentColor)
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
                Text("RAIN")
                    .font(.system(size: 38, weight: .black, design: .monospaced))
                    .tracking(6)
                    .foregroundStyle(LinearGradient(
                        colors: [currentColor, currentColor.opacity(0.55)],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .shadow(color: currentColor.opacity(0.9), radius: 14)
                Rectangle()
                    .fill(currentColor.opacity(0.3))
                    .frame(height: 1).padding(.horizontal, 32)
            }
            HStack {
                Spacer()
                Button(action: onPickerTap) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(currentColor.opacity(0.75))
                        .frame(width: 44, height: 44)
                        .background(currentColor.opacity(0.08))
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
            sliderRow("SPEED", speedLabel, value: $speed, color: currentColor)
            sliderRow("COLOR", colorLabel, value: $colorHue, color: currentColor)
            shapeRow
            saveButton
        }
        .padding(.horizontal, 24).padding(.top, 20)
    }

    @ViewBuilder
    private var shapeRow: some View {
        HStack(spacing: 12) {
            Text("SHAPE")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(currentColor.opacity(0.5))
                .frame(width: 52, alignment: .leading)
            HStack(spacing: 6) {
                ForEach(RainShape.allCases, id: \.self) { s in
                    Button(action: { shape = s }) {
                        Text(s.rawValue)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(shape == s ? .black : currentColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(shape == s ? currentColor : currentColor.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var saveButton: some View {
        Button {
            Task { await recorder.startRain(speed: speed, colorHue: colorHue, shape: shape) }
        } label: {
            Text("Save as Live Photo")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(colors: [currentColor, currentColor.opacity(0.75)],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(.top, 4)
    }

    // MARK: - Slider helpers

    private var speedLabel: String {
        switch speed {
        case ..<0.25: "CALM"
        case 0.25..<0.5: "SOFT"
        case 0.5..<0.75: "STEADY"
        default: "HEAVY"
        }
    }

    private var colorLabel: String {
        switch colorHue {
        case ..<0.33: "TEAL"
        case 0.33..<0.66: "AZURE"
        default: "DEEP"
        }
    }

    @ViewBuilder
    private func sliderRow(_ label: String, _ val: String, value: Binding<Double>, color: Color? = nil) -> some View {
        let c = color ?? accent
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(c.opacity(0.5))
                .frame(width: 52, alignment: .leading)
            Slider(value: value, in: 0...1).tint(c)
            Text(val)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(c)
                .frame(width: 46, alignment: .trailing)
        }
    }
}

#if DEBUG
#Preview { RainView(onPickerTap: {}) }
#endif
