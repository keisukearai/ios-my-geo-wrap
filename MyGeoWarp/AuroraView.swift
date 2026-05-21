import SwiftUI
import Combine

// MARK: - Aurora Frame (for Live Photo recording)

struct AuroraFrame: View {
    var t: Double
    let speed: Double
    let spread: Double
    let colorParam: Double
    let size: CGSize

    var body: some View {
        AuroraCanvas(t: t, speed: speed, spread: spread, colorParam: colorParam)
            .frame(width: size.width, height: size.height)
    }
}

// MARK: - Aurora Canvas

struct AuroraCanvas: View {
    let t: Double
    let speed: Double
    let spread: Double
    let colorParam: Double   // 0 = Boreal (green), 1 = Mystic (purple)

    private struct Band {
        let baseYFrac: Double
        let heightFrac: Double
        let freq: Double
        let phase: Double
        let colorFrac: Double
        let speedMult: Double
    }

    private let bands: [Band] = [
        Band(baseYFrac: 0.30, heightFrac: 0.14, freq: 1.8, phase: 0.00, colorFrac: 0.0, speedMult: 1.00),
        Band(baseYFrac: 0.25, heightFrac: 0.18, freq: 2.3, phase: 1.10, colorFrac: 0.2, speedMult: 0.82),
        Band(baseYFrac: 0.35, heightFrac: 0.16, freq: 1.5, phase: 2.20, colorFrac: 0.4, speedMult: 1.18),
        Band(baseYFrac: 0.28, heightFrac: 0.20, freq: 2.7, phase: 3.40, colorFrac: 0.6, speedMult: 0.92),
        Band(baseYFrac: 0.32, heightFrac: 0.15, freq: 1.9, phase: 4.50, colorFrac: 0.8, speedMult: 1.08),
        Band(baseYFrac: 0.22, heightFrac: 0.22, freq: 1.3, phase: 5.60, colorFrac: 1.0, speedMult: 0.75),
    ]

    var body: some View {
        Canvas { [self] gfx, size in
            drawStarfield(gfx, size)
            for band in bands {
                drawBand(gfx, size, band: band)
            }
            drawHorizonGlow(gfx, size)
            drawVignette(gfx, size)
        }
        .background(Color(red: 0.01, green: 0.02, blue: 0.08))
    }

    // MARK: - Starfield

    private func drawStarfield(_ gfx: GraphicsContext, _ size: CGSize) {
        for i in 0..<120 {
            let fi = Double(i)
            let x = (sin(fi * 127.1) * 0.5 + 0.5) * size.width
            let y = (sin(fi * 311.7) * 0.5 + 0.5) * size.height * 0.90
            let r = 0.5 + (sin(fi * 74.3) * 0.5 + 0.5) * 1.2
            let twinkle = 0.4 + 0.6 * (sin(t * (0.3 + fi * 0.07) + fi) * 0.5 + 0.5)
            let alpha = twinkle * (0.25 + (sin(fi * 198.5) * 0.5 + 0.5) * 0.50)
            var path = Path()
            path.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
            gfx.fill(path, with: .color(Color.white.opacity(alpha)))
        }
    }

    // MARK: - Aurora Color

    private func auroraColor(frac: Double) -> Color {
        func lerp(_ a: SIMD3<Double>, _ b: SIMD3<Double>, _ f: Double) -> SIMD3<Double> {
            a + (b - a) * max(0, min(1, f))
        }
        let borealis: [SIMD3<Double>] = [
            SIMD3(0.00, 0.92, 0.42),
            SIMD3(0.00, 0.78, 0.68),
            SIMD3(0.00, 0.58, 0.90),
            SIMD3(0.20, 0.38, 1.00),
            SIMD3(0.45, 0.18, 0.96),
            SIMD3(0.65, 0.08, 0.88),
        ]
        let mystic: [SIMD3<Double>] = [
            SIMD3(0.88, 0.08, 0.62),
            SIMD3(0.78, 0.12, 0.82),
            SIMD3(0.62, 0.06, 0.96),
            SIMD3(0.42, 0.10, 1.00),
            SIMD3(0.28, 0.28, 1.00),
            SIMD3(0.58, 0.42, 1.00),
        ]
        let n = borealis.count
        let pos = max(0, min(Double(n - 1), frac * Double(n - 1)))
        let i = min(n - 2, Int(pos))
        let f = pos - Double(i)
        let b = lerp(borealis[i], borealis[i + 1], f)
        let m = lerp(mystic[i], mystic[i + 1], f)
        let c = lerp(b, m, colorParam)
        return Color(red: c.x, green: c.y, blue: c.z)
    }

    // MARK: - Aurora Band

    private func drawBand(_ gfx: GraphicsContext, _ size: CGSize, band: Band) {
        let baseY = band.baseYFrac * size.height
        let amplitude = band.heightFrac * size.height * (0.4 + spread * 1.2)
        let rate = (0.08 + speed * 0.44) * band.speedMult
        let col = auroraColor(frac: band.colorFrac)

        let steps = 100
        var topPoints: [CGPoint] = []
        for i in 0...steps {
            let x = Double(i) / Double(steps) * size.width
            let p1 = x / size.width * .pi * 2 * band.freq + t * rate + band.phase
            let p2 = x / size.width * .pi * 2 * band.freq * 0.58 + t * rate * 1.4 + band.phase * 1.3
            let waveY = baseY - amplitude * (0.4 + 0.35 * sin(p1) + 0.25 * sin(p2))
            topPoints.append(CGPoint(x: x, y: max(0, waveY)))
        }

        let fadeHeight = size.height * (0.15 + spread * 0.10)
        let bottomY = min(size.height, baseY + fadeHeight)
        let topY = topPoints.map(\.y).min() ?? 0

        var bandPath = Path()
        bandPath.move(to: topPoints[0])
        for pt in topPoints.dropFirst() { bandPath.addLine(to: pt) }
        bandPath.addLine(to: CGPoint(x: size.width, y: bottomY))
        bandPath.addLine(to: CGPoint(x: 0, y: bottomY))
        bandPath.closeSubpath()

        let opacity = 0.12 + spread * 0.08
        gfx.fill(bandPath, with: .linearGradient(
            Gradient(stops: [
                .init(color: col.opacity(opacity),       location: 0.0),
                .init(color: col.opacity(opacity * 0.4), location: 0.6),
                .init(color: .clear,                      location: 1.0),
            ]),
            startPoint: CGPoint(x: size.width / 2, y: topY),
            endPoint:   CGPoint(x: size.width / 2, y: bottomY)
        ))

        var edgePath = Path()
        edgePath.move(to: topPoints[0])
        for pt in topPoints.dropFirst() { edgePath.addLine(to: pt) }

        var blurCtx = gfx; blurCtx.addFilter(.blur(radius: 6))
        blurCtx.stroke(edgePath, with: .color(col.opacity(0.55)), lineWidth: 2.5)
        gfx.stroke(edgePath, with: .color(col.opacity(0.85)), lineWidth: 0.8)
    }

    // MARK: - Horizon Glow

    private func drawHorizonGlow(_ gfx: GraphicsContext, _ size: CGSize) {
        let col = auroraColor(frac: 0.3)
        var path = Path()
        path.addRect(CGRect(origin: .zero, size: size))
        gfx.fill(path, with: .linearGradient(
            Gradient(stops: [
                .init(color: .clear,             location: 0.0),
                .init(color: .clear,             location: 0.55),
                .init(color: col.opacity(0.06),  location: 0.75),
                .init(color: col.opacity(0.14),  location: 1.0),
            ]),
            startPoint: CGPoint(x: 0, y: 0),
            endPoint:   CGPoint(x: 0, y: size.height)
        ))
    }

    // MARK: - Vignette

    private func drawVignette(_ gfx: GraphicsContext, _ size: CGSize) {
        var path = Path()
        path.addRect(CGRect(origin: .zero, size: size))
        gfx.fill(path, with: .radialGradient(
            Gradient(colors: [.clear, Color.black.opacity(0.72)]),
            center: CGPoint(x: size.width / 2, y: size.height / 2),
            startRadius: min(size.width, size.height) * 0.28,
            endRadius:   max(size.width, size.height) * 0.75
        ))
    }
}

// MARK: - AuroraView

struct AuroraView: View {
    let onPickerTap: () -> Void

    @State private var speed:  Double = 0.30
    @State private var spread: Double = 0.50
    @State private var color:  Double = 0.0
    @State private var showUI: Bool   = true

    @State private var isAutoMode:      Bool   = false
    @State private var autoTargetSpread: Double = 0.50
    @State private var autoNextSpread:   Date   = .distantPast
    @State private var lastAutoTick:     Date?  = nil

    @StateObject private var recorder = WallpaperRecorder()

    var body: some View {
        ZStack {
            Color(red: 0.01, green: 0.02, blue: 0.08).ignoresSafeArea()
            if recorder.isActive {
                recordingOverlay
            } else {
                TimelineView(.animation(minimumInterval: 1.0/30.0)) { tl in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    ZStack {
                        AuroraCanvas(t: t, speed: speed, spread: spread, colorParam: color)
                            .ignoresSafeArea()
                            .onTapGesture {
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
            speed  = Double.random(in: 0...1)
            spread = Double.random(in: 0...1)
            color  = Double.random(in: 0...1)
        }
        .onReceive(Timer.publish(every: 1.0/10.0, on: .main, in: .common).autoconnect()) { now in
            guard isAutoMode else {
                lastAutoTick = nil
                return
            }
            let dt = min(lastAutoTick.map { now.timeIntervalSince($0) } ?? (1.0/10.0), 0.5)
            lastAutoTick = now
            if now >= autoNextSpread {
                autoTargetSpread = Double.random(in: 0...1)
                autoNextSpread   = now.addingTimeInterval(8)
            }
            spread += (autoTargetSpread - spread) * 0.06 * dt
        }
    }

    // MARK: - Recording Overlay

    @ViewBuilder
    private var recordingOverlay: some View {
        ZStack {
            Color(red: 0.01, green: 0.02, blue: 0.08).ignoresSafeArea()
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
                            .tint(uiColor)
                            .padding(.horizontal, 40)
                        Text("\(Int(p * 100))%")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                    }
                } else if case .saving = recorder.state {
                    ProgressView().tint(uiColor)
                }
                Spacer()
            }
        }
    }

    // MARK: - UI Color

    private var uiColor: Color {
        let g = SIMD3<Double>(0.00, 0.85, 0.50)
        let p = SIMD3<Double>(0.65, 0.25, 1.00)
        let c = g + (p - g) * max(0, min(1, color))
        return Color(red: c.x, green: c.y, blue: c.z)
    }

    // MARK: - Header

    @ViewBuilder
    private var headerView: some View {
        ZStack {
            VStack(spacing: 4) {
                Text("AURORA")
                    .font(.system(size: 38, weight: .black, design: .monospaced))
                    .tracking(6)
                    .foregroundStyle(LinearGradient(
                        colors: [uiColor, uiColor.opacity(0.55)],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .shadow(color: uiColor.opacity(0.9), radius: 14)
                Rectangle()
                    .fill(uiColor.opacity(0.3))
                    .frame(height: 1).padding(.horizontal, 32)
            }

            HStack {
                Spacer()
                Button(action: onPickerTap) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(uiColor.opacity(0.75))
                        .frame(width: 44, height: 44)
                        .background(uiColor.opacity(0.08))
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
            sliderRow("SPEED",  speedLabel,  value: $speed)
            sliderRow("SPREAD", spreadLabel, value: $spread)
            colorSliderRow
            actionButtons
        }
        .padding(.horizontal, 24).padding(.top, 20)
    }

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button {
                isAutoMode.toggle()
                if isAutoMode {
                    autoTargetSpread = Double.random(in: 0...1)
                    spread           = autoTargetSpread
                    autoNextSpread   = Date().addingTimeInterval(8)
                    lastAutoTick     = nil
                } else {
                    lastAutoTick = nil
                }
            } label: {
                Text("AUTO")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(isAutoMode ? .black : uiColor)
                    .frame(width: 44)
                    .padding(.vertical, 14)
                    .background(
                        isAutoMode
                            ? LinearGradient(colors: [uiColor.opacity(0.95), uiColor.opacity(0.82)],
                                             startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [uiColor.opacity(0.12), uiColor.opacity(0.12)],
                                             startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(uiColor.opacity(isAutoMode ? 0 : 0.35), lineWidth: 1)
                    )
            }
            .shadow(color: isAutoMode ? uiColor.opacity(0.45) : .clear, radius: 8)

            Button {
                let startT = Date.timeIntervalSinceReferenceDate
                Task {
                    await recorder.startAurora(speed: speed, spread: spread, colorParam: color, startT: startT)
                }
            } label: {
                Text("Save as Live Photo")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: [uiColor, uiColor.opacity(0.75)],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private var colorSliderRow: some View {
        HStack(spacing: 12) {
            Text("BOREAL")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(uiColor.opacity(color > 0.5 ? 0.38 : 0.90))
                .frame(width: 46, alignment: .leading)
            Slider(value: $color, in: 0...1).tint(uiColor)
            Text("MYSTIC")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(uiColor.opacity(color < 0.5 ? 0.38 : 0.90))
                .frame(width: 46, alignment: .trailing)
        }
    }

    private var speedLabel: String {
        switch speed {
        case ..<0.25:    "SLOW"
        case 0.25..<0.5: "DRIFT"
        case 0.5..<0.75: "FLOW"
        default:          "RUSH"
        }
    }

    private var spreadLabel: String {
        switch spread {
        case ..<0.33:    "THIN"
        case 0.33..<0.66: "SOFT"
        default:          "WIDE"
        }
    }

    @ViewBuilder
    private func sliderRow(_ label: String, _ val: String, value: Binding<Double>) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(uiColor.opacity(0.5))
                .frame(width: 46, alignment: .leading)
            Slider(value: value, in: 0...1).tint(uiColor)
            Text(val)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(uiColor)
                .frame(width: 46, alignment: .trailing)
        }
    }
}

#Preview { AuroraView(onPickerTap: {}) }
