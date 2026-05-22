#if canImport(UIKit)
import Combine
import SwiftUI

// MARK: - Clock Face

struct ClockFace: View {
    let now: Date
    let colorHue: Double
    var bezelAngle: Double = 0
    var phase: Double = 0

    private let calendar = Calendar.current

    private var secondFraction: Double {
        let t = now.timeIntervalSince1970
        return t.truncatingRemainder(dividingBy: 60) / 60
    }
    private var minuteFraction: Double {
        let t = now.timeIntervalSince1970
        return t.truncatingRemainder(dividingBy: 3600) / 3600
    }
    private var hourFraction: Double {
        let hour   = Double(calendar.component(.hour,   from: now))
        let minute = Double(calendar.component(.minute, from: now))
        let second = Double(calendar.component(.second, from: now))
        return (hour.truncatingRemainder(dividingBy: 12) * 3600 + minute * 60 + second) / 43200
    }
    private var dayFraction: Double {
        let d   = Double(calendar.component(.day, from: now))
        let max = Double(calendar.range(of: .day, in: .month, for: now)?.count ?? 30)
        let h   = Double(calendar.component(.hour, from: now)) / 24.0
        return (d - 1 + h) / max
    }
    private var monthFraction: Double {
        let m = Double(calendar.component(.month, from: now))
        return (m - 1 + dayFraction) / 12.0
    }

    var body: some View {
        Canvas { ctx, sz in
            let cx     = sz.width  / 2
            let cy     = sz.height / 2
            let radius = min(sz.width, sz.height) * 0.38

            ctx.fill(Path(CGRect(origin: .zero, size: sz)),
                     with: .color(Color(red: 0.06, green: 0.05, blue: 0.10)))

            let dotR = max(4.5, radius * 0.02)
            ctx.fill(Path(ellipseIn: CGRect(x: cx - dotR, y: cy - dotR,
                                            width: dotR * 2, height: dotR * 2)),
                     with: .color(Color(hue: colorHue, saturation: 0.4, brightness: 1.0)))

            let hMonth  = (colorHue + 0.28).truncatingRemainder(dividingBy: 1.0)
            let hDay    = (colorHue + 0.21).truncatingRemainder(dividingBy: 1.0)
            let hHour   = (colorHue + 0.14).truncatingRemainder(dividingBy: 1.0)
            let hMinute = (colorHue + 0.07).truncatingRemainder(dividingBy: 1.0)
            drawHand(&ctx, cx: cx, cy: cy,
                     angle: monthFraction  * .pi * 2 - .pi / 2, len: radius * 0.28,
                     kind: .block,    color: Color(hue: hMonth,  saturation: 0.55, brightness: 0.95, opacity: 0.50),
                     tipDecor: .crescent)
            drawHand(&ctx, cx: cx, cy: cy,
                     angle: dayFraction    * .pi * 2 - .pi / 2, len: radius * 0.58,
                     kind: .drop,     color: Color(hue: hDay,    saturation: 0.55, brightness: 0.95, opacity: 0.62),
                     tipDecor: .sun)
            drawHand(&ctx, cx: cx, cy: cy,
                     angle: hourFraction   * .pi * 2 - .pi / 2, len: radius * 0.78,
                     kind: .sword,    color: Color(hue: hHour,   saturation: 0.55, brightness: 0.95, opacity: 0.75))
            drawHand(&ctx, cx: cx, cy: cy,
                     angle: minuteFraction * .pi * 2 - .pi / 2, len: radius * 1.02,
                     kind: .arrow,    color: Color(hue: hMinute, saturation: 0.55, brightness: 0.95, opacity: 0.86))
            drawHand(&ctx, cx: cx, cy: cy,
                     angle: secondFraction * .pi * 2 - .pi / 2, len: radius * 1.25,
                     kind: .hairline, color: Color(hue: colorHue, saturation: 0.55, brightness: 0.95, opacity: 0.95))

            drawBezel(&ctx, cx: cx, cy: cy, radius: radius)
            drawSparkles(&ctx, cx: cx, cy: cy, radius: radius)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }

    private func drawSparkles(_ ctx: inout GraphicsContext, cx: Double, cy: Double, radius: Double) {
        let bezelR       = radius * 1.10
        let secAngle     = secondFraction * .pi * 2 - .pi / 2
        let minAngle     = minuteFraction * .pi * 2 - .pi / 2
        let secThreshold = 0.21
        // minute hand is 1/60 as fast; 0.007 ≈ 2s of strong sparkle (intensity > 0.5)
        let minThreshold = 0.007
        let hMinute      = (colorHue + 0.07).truncatingRemainder(dividingBy: 1.0)

        for i in [0, 12, 24] {
            let tickAngle = Double(i) * .pi * 2.0 / 36.0 - .pi / 2.0 + bezelAngle
            let tx = cx + cos(tickAngle) * bezelR
            let ty = cy + sin(tickAngle) * bezelR

            // --- second hand sparkle ---
            var secDiff = (secAngle - tickAngle).truncatingRemainder(dividingBy: .pi * 2)
            if secDiff >  .pi { secDiff -= .pi * 2 }
            if secDiff < -.pi { secDiff += .pi * 2 }
            let absSecDiff = abs(secDiff)
            if absSecDiff < secThreshold {
                let intensity = 1.0 - absSecDiff / secThreshold
                let shimmer   = 0.7 + 0.3 * sin(phase * 6.0)

                let glowR = 10.0 * intensity
                let glowColor = Color(hue: colorHue, saturation: 0.2, brightness: 1.0,
                                      opacity: intensity * 0.55 * shimmer)
                ctx.fill(Path(ellipseIn: CGRect(x: tx - glowR, y: ty - glowR,
                                                 width: glowR * 2, height: glowR * 2)),
                         with: .color(glowColor))

                let sparkColor = Color(hue: colorHue, saturation: 0.25, brightness: 1.0,
                                       opacity: intensity * 0.65 * shimmer)
                for r in 0..<4 {
                    let rayAngle = tickAngle + Double(r) * .pi / 2.0
                    let outer = 6.0 + 18.0 * intensity
                    var ray = Path()
                    ray.move(to:    CGPoint(x: tx + cos(rayAngle) * 6.0, y: ty + sin(rayAngle) * 6.0))
                    ray.addLine(to: CGPoint(x: tx + cos(rayAngle) * outer, y: ty + sin(rayAngle) * outer))
                    ctx.stroke(ray, with: .color(sparkColor),
                               style: StrokeStyle(lineWidth: 2.0, lineCap: .round))
                }
                for r in 0..<4 {
                    let rayAngle = tickAngle + Double(r) * .pi / 2.0 + .pi / 4.0
                    let outer = 4.0 + 10.0 * intensity
                    var ray = Path()
                    ray.move(to:    CGPoint(x: tx + cos(rayAngle) * 4.0, y: ty + sin(rayAngle) * 4.0))
                    ray.addLine(to: CGPoint(x: tx + cos(rayAngle) * outer, y: ty + sin(rayAngle) * outer))
                    ctx.stroke(ray, with: .color(sparkColor.opacity(0.7)),
                               style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                }
            }

            // --- minute hand sparkle (half size, 2s duration) ---
            var minDiff = (minAngle - tickAngle).truncatingRemainder(dividingBy: .pi * 2)
            if minDiff >  .pi { minDiff -= .pi * 2 }
            if minDiff < -.pi { minDiff += .pi * 2 }
            let absMinDiff = abs(minDiff)
            if absMinDiff < minThreshold {
                let intensity = 1.0 - absMinDiff / minThreshold
                let shimmer   = 0.7 + 0.3 * sin(phase * 6.0)

                let glowR = 5.0 * intensity
                let glowColor = Color(hue: hMinute, saturation: 0.2, brightness: 1.0,
                                      opacity: intensity * 0.55 * shimmer)
                ctx.fill(Path(ellipseIn: CGRect(x: tx - glowR, y: ty - glowR,
                                                 width: glowR * 2, height: glowR * 2)),
                         with: .color(glowColor))

                let sparkColor = Color(hue: hMinute, saturation: 0.25, brightness: 1.0,
                                       opacity: intensity * 0.65 * shimmer)
                for r in 0..<4 {
                    let rayAngle = tickAngle + Double(r) * .pi / 2.0
                    let outer = 3.0 + 9.0 * intensity
                    var ray = Path()
                    ray.move(to:    CGPoint(x: tx + cos(rayAngle) * 3.0, y: ty + sin(rayAngle) * 3.0))
                    ray.addLine(to: CGPoint(x: tx + cos(rayAngle) * outer, y: ty + sin(rayAngle) * outer))
                    ctx.stroke(ray, with: .color(sparkColor),
                               style: StrokeStyle(lineWidth: 1.0, lineCap: .round))
                }
                for r in 0..<4 {
                    let rayAngle = tickAngle + Double(r) * .pi / 2.0 + .pi / 4.0
                    let outer = 2.0 + 5.0 * intensity
                    var ray = Path()
                    ray.move(to:    CGPoint(x: tx + cos(rayAngle) * 2.0, y: ty + sin(rayAngle) * 2.0))
                    ray.addLine(to: CGPoint(x: tx + cos(rayAngle) * outer, y: ty + sin(rayAngle) * outer))
                    ctx.stroke(ray, with: .color(sparkColor.opacity(0.7)),
                               style: StrokeStyle(lineWidth: 0.7, lineCap: .round))
                }
            }
        }
    }

    private func drawBezel(_ ctx: inout GraphicsContext, cx: Double, cy: Double, radius: Double) {
        let bezelR = radius * 1.10
        var path = Path()
        for i in 0..<36 {
            let θ: Double = Double(i) * Double.pi * 2.0 / 36.0 - Double.pi / 2.0 + bezelAngle
            let pt = CGPoint(x: cx + cos(θ) * bezelR, y: cy + sin(θ) * bezelR)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        ctx.stroke(path, with: .color(Color(white: 0.80, opacity: 0.20)),
                   style: StrokeStyle(lineWidth: 1.0, lineJoin: .miter))

        // tick marks at each of the 36 vertices, every 12th is major
        for i in 0..<36 {
            let θ: Double = Double(i) * Double.pi * 2.0 / 36.0 - Double.pi / 2.0 + bezelAngle
            let major = i % 12 == 0
            let inner = bezelR - (major ? 7.0 : 4.0)
            let outer = bezelR + (major ? 7.0 : 4.0)
            var tick = Path()
            tick.move(to:    CGPoint(x: cx + cos(θ) * inner, y: cy + sin(θ) * inner))
            tick.addLine(to: CGPoint(x: cx + cos(θ) * outer, y: cy + sin(θ) * outer))
            ctx.stroke(tick,
                       with: .color(Color(white: 1.0, opacity: major ? 0.70 : 0.20)),
                       style: StrokeStyle(lineWidth: major ? 1.2 : 0.7, lineCap: .round))
        }
    }

    private enum HandKind { case block, drop, sword, arrow, hairline }
    private enum TipDecor { case none, crescent, sun }

    private func drawHand(_ ctx: inout GraphicsContext,
                           cx: Double, cy: Double,
                           angle: Double, len: Double,
                           kind: HandKind, color: Color,
                           tipDecor: TipDecor = .none) {
        let dx  =  cos(angle)
        let dy  =  sin(angle)
        let px  = -sin(angle)
        let py  =  cos(angle)
        let tx  = cx + dx * len
        let ty  = cy + dy * len

        switch kind {
        case .hairline:
            var p = Path()
            p.move(to: CGPoint(x: cx, y: cy))
            p.addLine(to: CGPoint(x: tx, y: ty))
            ctx.stroke(p, with: .color(color),
                       style: StrokeStyle(lineWidth: 0.8, lineCap: .round))

        case .arrow:
            var p = Path()
            p.move(to: CGPoint(x: cx, y: cy))
            p.addLine(to: CGPoint(x: tx, y: ty))
            ctx.stroke(p, with: .color(color),
                       style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
            let aw = len * 0.07
            let ab = aw * 1.6
            var head = Path()
            head.move(to: CGPoint(x: tx - dx * ab + px * aw, y: ty - dy * ab + py * aw))
            head.addLine(to: CGPoint(x: tx, y: ty))
            head.addLine(to: CGPoint(x: tx - dx * ab - px * aw, y: ty - dy * ab - py * aw))
            ctx.stroke(head, with: .color(color),
                       style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))

        case .sword:
            let w  = len * 0.044
            let mx = cx + dx * len * 0.22
            let my = cy + dy * len * 0.22
            var p = Path()
            p.move(to: CGPoint(x: cx, y: cy))
            p.addLine(to: CGPoint(x: mx + px * w, y: my + py * w))
            p.addCurve(
                to:       CGPoint(x: tx, y: ty),
                control1: CGPoint(x: mx + px * w * 0.7 + dx * len * 0.28,
                                  y: my + py * w * 0.7 + dy * len * 0.28),
                control2: CGPoint(x: tx + px * w * 0.15 - dx * len * 0.08,
                                  y: ty + py * w * 0.15 - dy * len * 0.08))
            p.addCurve(
                to:       CGPoint(x: mx - px * w, y: my - py * w),
                control1: CGPoint(x: tx - px * w * 0.15 - dx * len * 0.08,
                                  y: ty - py * w * 0.15 - dy * len * 0.08),
                control2: CGPoint(x: mx - px * w * 0.7 + dx * len * 0.28,
                                  y: my - py * w * 0.7 + dy * len * 0.28))
            p.closeSubpath()
            ctx.fill(p, with: .color(color))

        case .drop:
            var p = Path()
            p.move(to: CGPoint(x: cx, y: cy))
            p.addLine(to: CGPoint(x: tx, y: ty))
            ctx.stroke(p, with: .color(color),
                       style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
            if tipDecor != .sun {
                let r = 7.6
                ctx.fill(Path(ellipseIn: CGRect(x: tx - r, y: ty - r, width: r * 2, height: r * 2)),
                         with: .color(color))
            }

        case .block:
            let w = len * 0.10 + 2.0
            var p = Path()
            p.move(to: CGPoint(x: cx, y: cy))
            p.addLine(to: CGPoint(x: tx, y: ty))
            ctx.stroke(p, with: .color(color),
                       style: StrokeStyle(lineWidth: w, lineCap: .square))
        }

        switch tipDecor {
        case .crescent:
            let moonColor = Color(red: 0.72, green: 0.76, blue: 0.84).opacity(0.88)
            let bigR = 10.08
            let smallR = 8.93
            let off = 6.48
            let gap = bigR + 12.0
            let stx = tx + dx * gap
            let sty = ty + dy * gap
            let bigRect   = CGRect(x: stx - bigR, y: sty - bigR, width: bigR * 2, height: bigR * 2)
            let smallRect = CGRect(x: stx + px * off - smallR, y: sty + py * off - smallR,
                                    width: smallR * 2, height: smallR * 2)
            ctx.drawLayer { layerCtx in
                layerCtx.fill(Path(ellipseIn: bigRect), with: .color(moonColor))
                layerCtx.blendMode = .destinationOut
                layerCtx.fill(Path(ellipseIn: smallRect), with: .color(.black))
            }
        case .sun:
            let sunColor = Color(red: 0.80, green: 0.28, blue: 0.25).opacity(0.88)
            let gap = 10.0
            let stx = tx + dx * gap
            let sty = ty + dy * gap
            let sunR = 4.79
            ctx.fill(Path(ellipseIn: CGRect(x: stx - sunR, y: sty - sunR,
                                             width: sunR * 2, height: sunR * 2)),
                     with: .color(sunColor))
            for i in 0..<8 {
                let ray = Double(i) * .pi / 4.0
                let innerR = sunR + 1.58
                let outerR = sunR + 3.78
                var spoke = Path()
                spoke.move(to:    CGPoint(x: stx + cos(ray) * innerR, y: sty + sin(ray) * innerR))
                spoke.addLine(to: CGPoint(x: stx + cos(ray) * outerR, y: sty + sin(ray) * outerR))
                ctx.stroke(spoke, with: .color(sunColor), style: StrokeStyle(lineWidth: 0.76, lineCap: .round))
            }
        case .none:
            break
        }
    }
}

// MARK: - Clock Frame (for ImageRenderer)

struct ClockFrame: View {
    var t: Double
    let colorHue: Double
    let startDate: Date
    let size: CGSize

    var body: some View {
        ClockFace(
            now: startDate.addingTimeInterval(t),
            colorHue: colorHue,
            bezelAngle: -(t / 60.0) * .pi * 2,
            phase: t
        )
        .frame(width: size.width, height: size.height)
    }
}

// MARK: - Clock View

struct ClockView: View {
    let onPickerTap: () -> Void

    @StateObject private var recorder = WallpaperRecorder()

    @State private var now:           Date   = .init()
    @State private var colorHue:      Double = Double.random(in: 0...1)
    @State private var autoColor:     Bool   = false
    @State private var showUI:        Bool   = false
    @State private var phase:         Double = 0.0

    @State private var isIdle:        Bool = false
    @State private var lastTouchDate: Date = .now
    @State private var lastFrameDate: Date = .now

    private var accent: Color { Color(hue: colorHue, saturation: 0.55, brightness: 0.90) }
    private let timer  = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    private var floatOffset: CGSize {
        CGSize(width:  sin(phase * 0.37) * 65 + cos(phase * 0.19) * 40,
               height: cos(phase * 0.29) * 55 + sin(phase * 0.13) * 35)
    }
    private var floatScale: CGFloat {
        CGFloat(0.85 + sin(phase * 0.23) * 0.15 + cos(phase * 0.11) * 0.08)
    }

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.05, blue: 0.10).ignoresSafeArea()
            if recorder.isActive {
                recordingOverlay
            } else {
                GeometryReader { geo in
                ZStack {
                    ClockFace(now: now, colorHue: colorHue,
                              bezelAngle: -(phase / 60.0) * .pi * 2,
                              phase: phase)
                        .onTapGesture {
                            lastTouchDate = .now
                            isIdle = false
                            withAnimation(.easeInOut(duration: 0.3)) { showUI.toggle() }
                        }

                    let cal = Calendar.current
                    let hh = String(format: "%02d", cal.component(.hour,   from: now))
                    let mm = String(format: "%02d", cal.component(.minute, from: now))
                    let ss = String(format: "%02d", cal.component(.second, from: now))
                    let monthNames = ["JAN","FEB","MAR","APR","MAY","JUN",
                                      "JUL","AUG","SEP","OCT","NOV","DEC"]
                    let moIdx = cal.component(.month, from: now) - 1
                    let mo    = monthNames[max(0, min(moIdx, 11))]
                    let dd    = String(format: "%02d", cal.component(.day,  from: now))
                    let yyyy  = String(cal.component(.year, from: now))
                    let cSecond = Color(hue: colorHue,                                                saturation: 0.45, brightness: 0.95)
                    let cMinute = Color(hue: (colorHue + 0.07).truncatingRemainder(dividingBy: 1.0), saturation: 0.45, brightness: 0.95)
                    let cHour   = Color(hue: (colorHue + 0.14).truncatingRemainder(dividingBy: 1.0), saturation: 0.45, brightness: 0.95)
                    let cDay    = Color(hue: (colorHue + 0.21).truncatingRemainder(dividingBy: 1.0), saturation: 0.45, brightness: 0.95)
                    let cMonth  = Color(hue: (colorHue + 0.28).truncatingRemainder(dividingBy: 1.0), saturation: 0.45, brightness: 0.95)
                    VStack(spacing: 4 * floatScale) {
                        HStack(spacing: 0) {
                            Text(hh).foregroundColor(cHour.opacity(0.88))
                            Text(":").foregroundColor(cHour.opacity(0.44))
                            Text(mm).foregroundColor(cMinute.opacity(0.88))
                            Text(":").foregroundColor(cMinute.opacity(0.44))
                            Text(ss).foregroundColor(cSecond.opacity(0.88))
                        }
                        .font(.system(size: 28 * floatScale, weight: .semibold, design: .monospaced))
                        HStack(spacing: 0) {
                            Text(dd).foregroundColor(cDay.opacity(0.50))
                            Text("/").foregroundColor(cDay.opacity(0.25))
                            Text(mo).foregroundColor(cMonth.opacity(0.50))
                            Text("/").foregroundColor(cMonth.opacity(0.25))
                            Text(yyyy).foregroundColor(cMonth.opacity(0.35))
                        }
                        .font(.system(size: 14 * floatScale, weight: .semibold, design: .monospaced))
                    }
                    .offset(x: floatOffset.width, y: floatOffset.height + geo.size.height * 0.25)
                    .allowsHitTesting(false)

                    VStack(spacing: 0) {
                        headerView
                        Spacer()
                        controlsView.padding(.bottom, 40)
                    }
                    .opacity(showUI ? 1 : 0)
                    .allowsHitTesting(showUI)
                    .animation(.easeInOut(duration: 0.3), value: showUI)
                }
                .onReceive(timer) { tick in
                    let nowIdle = tick.timeIntervalSince(lastTouchDate) >= 60
                    if nowIdle != isIdle { isIdle = nowIdle }

                    let dt = isIdle ? 1.0/15.0 : 1.0/30.0
                    guard tick.timeIntervalSince(lastFrameDate) >= dt else { return }
                    lastFrameDate = tick

                    now    = .init()
                    phase += dt
                    if autoColor {
                        colorHue = (colorHue + 0.001).truncatingRemainder(dividingBy: 1.0)
                    }
                }
                } // GeometryReader
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Text(isIdle ? "15fps" : (showUI ? "30fps" : "20fps"))
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.35))
                .padding(.trailing, 10).padding(.bottom, 12)
                .allowsHitTesting(false)
        }
        .onAppear {
            colorHue = Double.random(in: 0...1)
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerView: some View {
        ZStack {
            VStack(spacing: 4) {
                Text("CLOCK")
                    .font(.system(size: 38, weight: .black, design: .monospaced))
                    .tracking(6)
                    .foregroundStyle(LinearGradient(
                        colors: [accent, accent.opacity(0.55)],
                        startPoint: .leading, endPoint: .trailing))
                    .shadow(color: accent.opacity(0.9), radius: 14)
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
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Text("COLOR")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(accent.opacity(0.5))
                    .frame(width: 52, alignment: .leading)
                Slider(value: $colorHue, in: 0...1).tint(accent)
                Text(colorLabel)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(accent)
                    .frame(width: 46, alignment: .trailing)
                Button { autoColor.toggle() } label: {
                    Text("AUTO")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(autoColor ? .black : accent.opacity(0.7))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(autoColor ? accent : accent.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            saveButton
        }
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private var saveButton: some View {
        Button {
            let snapshot = captureCurrentFrame()
            let startDate = now
            Task {
                await recorder.startClock(colorHue: colorHue, startDate: startDate,
                                          stillSnapshot: snapshot)
            }
        } label: {
            Text("Save as Live Photo")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(colors: [accent, accent.opacity(0.75)],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(.top, 4)
    }

    // MARK: - Recording Overlay

    @ViewBuilder
    private var recordingOverlay: some View {
        ZStack {
            Color(red: 0.06, green: 0.05, blue: 0.10).ignoresSafeArea()
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

    // MARK: - Snapshot

    private func captureCurrentFrame() -> CGImage? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.keyWindow,
              window.bounds.width > 0 else { return nil }
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        return renderer.image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        }.cgImage
    }

    private var colorLabel: String {
        switch colorHue {
        case ..<0.08:       "AMBER"
        case 0.08..<0.15:   "GOLD"
        case 0.15..<0.40:   "GREEN"
        case 0.40..<0.65:   "BLUE"
        case 0.65..<0.80:   "VIOLET"
        default:             "ROSE"
        }
    }
}

#Preview { ClockView(onPickerTap: {}) }
#endif
