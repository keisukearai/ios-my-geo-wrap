#if canImport(UIKit)
import Combine
import SpriteKit
import SwiftUI

// MARK: - Hourglass Frame (ImageRenderer用 — 決定的アニメーション)

struct HourglassFrame: View {
    var t: Double
    let speed: Double
    let colorHue: Double
    let form: Double
    let size: CGSize

    private var cycleDuration: Double { 30.0 + (1.0 - speed) * 330.0 }

    var body: some View {
        Canvas { ctx, sz in
            ctx.fill(Path(CGRect(origin: .zero, size: sz)),
                     with: .color(Color(red: 0.08, green: 0.06, blue: 0.12)))

            let r  = min(sz.width, sz.height) * 0.40
            let cx = sz.width  / 2
            let cy = sz.height / 2

            let containerAngle = floor(t / (cycleDuration / 2)) * .pi

            drawGlass(&ctx, cx: cx, cy: cy, r: r, rotation: containerAngle)
            drawSand(&ctx, cx: cx, cy: cy, r: r, t: t, rotation: containerAngle)
        }
        .frame(width: size.width, height: size.height)
    }

    private func drawGlass(_ ctx: inout GraphicsContext,
                            cx: Double, cy: Double, r: Double, rotation: Double) {
        let glassColor = Color(hue: colorHue, saturation: 0.35, brightness: 0.90).opacity(0.55)

        // hourglass outline (rotated)
        let glassPath = hourglassCGPath(cx: cx, cy: cy, r: r, rotation: rotation)
        ctx.stroke(glassPath, with: .color(glassColor), lineWidth: 2.0)
    }

    private func hourglassCGPath(cx: Double, cy: Double, r: Double, rotation: Double) -> Path {
        let slender = form < 0.5 ? (0.5 - form) * 2.0 : 0.0
        let barrel  = form > 0.5 ? (form - 0.5) * 2.0 : 0.0
        let baseTop = r * 0.88
        let neck    = r * 0.108
        let topX    = baseTop * (1.0 - slender * 0.40)
        let topY    = baseTop * (1.0 + slender * 0.50)
        let bulge   = baseTop * barrel * 0.45

        return Path { p in
            func rotPt(_ x: Double, _ y: Double) -> CGPoint {
                let rx = x * cos(rotation) - y * sin(rotation)
                let ry = x * sin(rotation) + y * cos(rotation)
                return CGPoint(x: cx + rx, y: cy + ry)
            }
            p.move(to: rotPt(-topX, -topY))
            p.addLine(to: rotPt(topX, -topY))
            if bulge > 0 {
                p.addQuadCurve(to: rotPt(neck, 0),    control: rotPt(topX + bulge, -topY / 2))
                p.addQuadCurve(to: rotPt(topX, topY), control: rotPt(topX + bulge,  topY / 2))
            } else {
                p.addLine(to: rotPt(neck, 0))
                p.addLine(to: rotPt(topX, topY))
            }
            p.addLine(to: rotPt(-topX, topY))
            if bulge > 0 {
                p.addQuadCurve(to: rotPt(-neck, 0),    control: rotPt(-topX - bulge,  topY / 2))
                p.addQuadCurve(to: rotPt(-topX, -topY), control: rotPt(-topX - bulge, -topY / 2))
            } else {
                p.addLine(to: rotPt(-neck, 0))
            }
            p.closeSubpath()
        }
    }

    private func drawSand(_ ctx: inout GraphicsContext,
                           cx: Double, cy: Double, r: Double, t: Double, rotation: Double) {
        let sandColor = Color(hue: colorHue, saturation: 0.65, brightness: 0.95).opacity(0.82)
        let phase = (t.truncatingRemainder(dividingBy: cycleDuration)) / cycleDuration
        let fillRatio = 1.0 - phase

        let slender = form < 0.5 ? (0.5 - form) * 2.0 : 0.0
        let baseTop = r * 0.88
        let neck    = r * 0.108
        let topX    = baseTop * (1.0 - slender * 0.40)
        let topY    = baseTop * (1.0 + slender * 0.50)

        let rot = rotation
        func rotPt(_ x: Double, _ y: Double) -> CGPoint {
            let rx = x * cos(rot) - y * sin(rot)
            let ry = x * sin(rot) + y * cos(rot)
            return CGPoint(x: cx + rx, y: cy + ry)
        }

        // bottom chamber fill
        let bottomFill = fillRatio * topY * 1.8
        var sandPath = Path()
        let fillY = topY - bottomFill
        let edgeX = neck + (topX - neck) * max(0, min(1, (topY - fillY) / topY))
        sandPath.move(to: rotPt(-edgeX, fillY))
        sandPath.addLine(to: rotPt(edgeX, fillY))
        sandPath.addLine(to: rotPt(topX, topY))
        sandPath.addLine(to: rotPt(-topX, topY))
        sandPath.closeSubpath()
        ctx.fill(sandPath, with: .color(sandColor.opacity(0.45)))

        // falling stream
        if phase > 0.02 && phase < 0.98 {
            let streamLen = r * 0.25
            var stream = Path()
            stream.move(to: rotPt(0, -neck))
            stream.addLine(to: rotPt(0, -neck + streamLen))
            ctx.stroke(stream, with: .color(sandColor.opacity(0.70)), lineWidth: 2.5)
        }
    }
}

// MARK: - Hourglass Scene

class HourglassScene: SKScene {

    var speed2: Double = 0.5 {
        didSet { updateFlipAction() }
    }
    var colorHue: Double = 0.08 {
        didSet { updateColors() }
    }
    var form2: Double = 0.5 {
        didSet { rebuildWalls() }
    }

    private var halfCycleDuration: Double { 5.0 + (1.0 - speed2) * 55.0 }
    private weak var containerNode: SKNode?
    private var grainNodes: [SKNode] = []
    private var wallNodes:  [SKNode] = []
    private weak var outlineNode: SKShapeNode?

    override func didMove(to view: SKView) {
        view.preferredFramesPerSecond = 30
        backgroundColor = UIColor(red: 0.08, green: 0.06, blue: 0.12, alpha: 1.0)
        physicsWorld.gravity = CGVector(dx: 0, dy: -9.8)
        setupContainer()
        spawnGrains()
        scheduleFlip()
    }

    private var containerRadius: CGFloat { min(size.width, size.height) * 0.40 }
    private var containerCenter: CGPoint { CGPoint(x: size.width / 2, y: size.height / 2) }

    // MARK: - Container setup

    private func setupContainer() {
        let r = containerRadius
        let c = containerCenter

        let node = SKNode()
        node.position = c
        addChild(node)
        containerNode = node

        // hourglass glass walls (edgeChain physics)
        buildGlassWalls(node: node, r: r)
    }

    private func shapeParams() -> (neck: CGFloat, topX: CGFloat, topY: CGFloat, bulge: CGFloat) {
        let r       = containerRadius
        let baseTop: CGFloat = r * 0.88
        let neck: CGFloat    = r * 0.108
        let slender = form2 < 0.5 ? CGFloat((0.5 - form2) * 2.0) : 0.0
        let barrel  = form2 > 0.5 ? CGFloat((form2 - 0.5) * 2.0) : 0.0
        return (neck,
                baseTop * (1.0 - slender * 0.40),
                baseTop * (1.0 + slender * 0.50),
                baseTop * barrel * 0.45)
    }

    private func rebuildWalls() {
        guard let node = containerNode else { return }
        let oldWalls   = wallNodes
        let oldOutline = outlineNode
        wallNodes = []
        buildGlassWalls(node: node, r: containerRadius)
        oldWalls.forEach   { $0.removeFromParent() }
        oldOutline?.removeFromParent()
    }

    private func buildGlassWalls(node: SKNode, r: CGFloat) {
        let (neck, topX, topY, bulge) = shapeParams()

        // Quadratic Bezier sampler for physics approximation
        func bezPts(_ p0: CGPoint, _ ctrl: CGPoint, _ p1: CGPoint, steps: Int = 5) -> [CGPoint] {
            var result: [CGPoint] = []
            for i in 0...steps {
                let t:  CGFloat = CGFloat(i) / CGFloat(steps)
                let mt: CGFloat = 1.0 - t
                let x = mt*mt*p0.x + 2*mt*t*ctrl.x + t*t*p1.x
                let y = mt*mt*p0.y + 2*mt*t*ctrl.y + t*t*p1.y
                result.append(CGPoint(x: x, y: y))
            }
            return result
        }

        func addWall(_ pts: [CGPoint], friction: CGFloat = 0.4, restitution: CGFloat = 0.1) {
            let path = CGMutablePath()
            path.move(to: pts[0])
            pts.dropFirst().forEach { path.addLine(to: $0) }
            let w = SKNode()
            w.physicsBody = SKPhysicsBody(edgeChainFrom: path)
            w.physicsBody?.friction    = friction
            w.physicsBody?.restitution = restitution
            node.addChild(w)
            wallNodes.append(w)
        }

        // right wall (SpriteKit y-up): top-right → neck → bottom-right
        let rUpper = bulge > 0
            ? bezPts(CGPoint(x:  topX, y:  topY), CGPoint(x:  topX + bulge, y:  topY / 2), CGPoint(x:  neck, y: 0))
            : [CGPoint(x:  topX, y:  topY), CGPoint(x:  neck, y: 0)]
        let rLower = bulge > 0
            ? bezPts(CGPoint(x:  neck, y: 0), CGPoint(x:  topX + bulge, y: -topY / 2), CGPoint(x:  topX, y: -topY))
            : [CGPoint(x:  neck, y: 0), CGPoint(x:  topX, y: -topY)]
        addWall(rUpper + rLower.dropFirst())

        // left wall: top-left → neck → bottom-left
        let lUpper = bulge > 0
            ? bezPts(CGPoint(x: -topX, y:  topY), CGPoint(x: -topX - bulge, y:  topY / 2), CGPoint(x: -neck, y: 0))
            : [CGPoint(x: -topX, y:  topY), CGPoint(x: -neck, y: 0)]
        let lLower = bulge > 0
            ? bezPts(CGPoint(x: -neck, y: 0), CGPoint(x: -topX - bulge, y: -topY / 2), CGPoint(x: -topX, y: -topY))
            : [CGPoint(x: -neck, y: 0), CGPoint(x: -topX, y: -topY)]
        addWall(lUpper + lLower.dropFirst())

        addWall([CGPoint(x: -topX, y: -topY), CGPoint(x:  topX, y: -topY)], friction: 0.6, restitution: 0.05)
        addWall([CGPoint(x: -topX, y:  topY), CGPoint(x:  topX, y:  topY)], friction: 0.6, restitution: 0.05)

        // visual outline (smooth curves via CGPath)
        let outlinePath = CGMutablePath()
        outlinePath.move(to: CGPoint(x: -topX, y:  topY))
        outlinePath.addLine(to: CGPoint(x:  topX, y:  topY))
        if bulge > 0 {
            outlinePath.addQuadCurve(to: CGPoint(x:  neck, y:  0),    control: CGPoint(x:  topX + bulge, y:  topY / 2))
            outlinePath.addQuadCurve(to: CGPoint(x:  topX, y: -topY), control: CGPoint(x:  topX + bulge, y: -topY / 2))
        } else {
            outlinePath.addLine(to: CGPoint(x:  neck, y:  0))
            outlinePath.addLine(to: CGPoint(x:  topX, y: -topY))
        }
        outlinePath.addLine(to: CGPoint(x: -topX, y: -topY))
        if bulge > 0 {
            outlinePath.addQuadCurve(to: CGPoint(x: -neck, y:  0),    control: CGPoint(x: -topX - bulge, y: -topY / 2))
            outlinePath.addQuadCurve(to: CGPoint(x: -topX, y:  topY), control: CGPoint(x: -topX - bulge, y:  topY / 2))
        } else {
            outlinePath.addLine(to: CGPoint(x: -neck, y:  0))
        }
        outlinePath.closeSubpath()

        let outline = SKShapeNode()
        outline.path        = outlinePath
        outline.fillColor   = UIColor(hue: CGFloat(colorHue), saturation: 0.20, brightness: 0.15, alpha: 0.35)
        outline.strokeColor = UIColor(hue: CGFloat(colorHue), saturation: 0.35, brightness: 0.90, alpha: 0.60)
        outline.lineWidth   = 2.0
        outline.glowWidth   = 2.5
        node.addChild(outline)
        outlineNode = outline
    }

    // MARK: - Grains

    private func makeGrainTexture(radius: CGFloat, hue: CGFloat) -> SKTexture {
        let diameter = Int(ceil(radius * 2))
        let size = CGSize(width: diameter, height: diameter)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor(hue: hue, saturation: 0.60, brightness: 0.90, alpha: 0.88).setFill()
            ctx.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
            UIColor(white: 1.0, alpha: 0.25).setFill()
            let inset: CGFloat = max(1, radius * 0.15)
            ctx.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset))
        }
        return SKTexture(image: image)
    }

    private func spawnGrains() {
        guard let node = containerNode else { return }
        let r = containerRadius
        let grainRadius: CGFloat = r / 44.0 * 0.6
        let hue = CGFloat(colorHue)
        let grainSize = CGSize(width: grainRadius * 2, height: grainRadius * 2)

        let textures = (0..<5).map { i in
            makeGrainTexture(radius: grainRadius, hue: hue + CGFloat(i) * 0.02)
        }

        let neck: CGFloat = r * 0.108
        let top:  CGFloat = r * 0.88
        let wallMargin = grainRadius * 2.5

        for i in 0..<512 {
            let grain = SKSpriteNode(texture: textures[i % 5], size: grainSize)
            let y = CGFloat.random(in: -(top - wallMargin) ... -(wallMargin))
            // compute wall position at this y so grains stay inside the hourglass
            let wallX = neck + (top - neck) * (-y) / top
            let maxX = wallX - wallMargin
            guard maxX > 0 else { continue }
            let x = CGFloat.random(in: -maxX...maxX)
            grain.position = CGPoint(x: x, y: y)

            grain.physicsBody = SKPhysicsBody(circleOfRadius: grainRadius)
            grain.physicsBody?.restitution    = 0.15
            grain.physicsBody?.friction       = 0.50
            grain.physicsBody?.density        = 2.0
            grain.physicsBody?.linearDamping  = 0.3
            grain.physicsBody?.angularDamping = 0.5
            grain.physicsBody?.allowsRotation = false

            node.addChild(grain)
            grainNodes.append(grain)
        }
    }

    // MARK: - Rotation

    private func scheduleFlip() {
        guard let node = containerNode else { return }
        node.run(
            SKAction.repeatForever(SKAction.rotate(byAngle: -.pi * 2, duration: halfCycleDuration * 2.0)),
            withKey: "rotation"
        )
    }

    private func updateFlipAction() {
        guard let node = containerNode else { return }
        node.removeAction(forKey: "rotation")
        scheduleFlip()
    }

    private func updateColors() {
        let hue = CGFloat(colorHue)
        outlineNode?.fillColor   = UIColor(hue: hue, saturation: 0.20, brightness: 0.15, alpha: 0.35)
        outlineNode?.strokeColor = UIColor(hue: hue, saturation: 0.35, brightness: 0.90, alpha: 0.60)

        let grainRadius = containerRadius / 44.0 * 0.6
        let textures = (0..<5).map { i in
            makeGrainTexture(radius: grainRadius, hue: hue + CGFloat(i) * 0.02)
        }
        for (i, grain) in grainNodes.enumerated() {
            (grain as? SKSpriteNode)?.texture = textures[i % 5]
        }
    }

    override func willMove(from view: SKView) {}
}

// MARK: - Scene Store

private final class HourglassSceneStore: ObservableObject {
    private(set) var scene: HourglassScene?
    func scene(for size: CGSize) -> HourglassScene {
        if let s = scene { return s }
        let s = HourglassScene(size: size)
        s.scaleMode = .resizeFill
        scene = s
        return s
    }
}

// MARK: - Hourglass View

struct HourglassView: View {
    let onPickerTap: () -> Void

    @StateObject private var store    = HourglassSceneStore()
    @StateObject private var recorder = WallpaperRecorder()

    @State private var speed:      Double = 0.5
    @State private var form:       Double = 0.5
    @State private var colorHue:   Double = 0.08
    @State private var showUI:     Bool   = true
    @State private var autoColor:  Bool   = false

    private let accent      = Color(red: 0.95, green: 0.78, blue: 0.45)
    private let colorTimer  = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            mainContent
                .opacity(recorder.isActive ? 0 : 1)
                .allowsHitTesting(!recorder.isActive)

            if recorder.isActive { recordingOverlay }
        }
        .onChange(of: speed)    { store.scene?.speed2    = $0 }
        .onChange(of: form)     { store.scene?.form2     = $0 }
        .onChange(of: colorHue) { store.scene?.colorHue  = $0 }
        .onChange(of: showUI)   { store.scene?.view?.preferredFramesPerSecond = $0 ? 30 : 20 }
        .onReceive(colorTimer) { _ in
            guard autoColor else { return }
            colorHue = (colorHue + 0.003).truncatingRemainder(dividingBy: 1.0)
        }
        .onAppear {
            speed    = Double.random(in: 0.3...0.7)
            colorHue = Double.random(in: 0.05...0.15)
        }
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
            Color(red: 0.08, green: 0.06, blue: 0.12).ignoresSafeArea()
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
                Text("HOURGLASS")
                    .font(.system(size: 38, weight: .black, design: .monospaced))
                    .tracking(6)
                    .foregroundStyle(LinearGradient(
                        colors: [accent, accent.opacity(0.55)],
                        startPoint: .leading, endPoint: .trailing
                    ))
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
        VStack(spacing: 18) {
            sliderRow("SPEED", speedLabel, value: $speed)
            sliderRow("FORM",  formLabel,  value: $form)
            colorSliderRow
            saveButton
        }
        .padding(.horizontal, 24).padding(.top, 20)
    }

    @ViewBuilder
    private var colorSliderRow: some View {
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
    }

    @ViewBuilder
    private var saveButton: some View {
        Button {
            let snapshot = captureCurrentFrame()
            Task {
                await recorder.startHourglass(speed: speed, colorHue: colorHue, form: form,
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

    // MARK: - Snapshot

    private func captureCurrentFrame() -> CGImage? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.keyWindow,
              let skView = findView(ofType: SKView.self, in: window),
              skView.bounds.width > 0 else { return nil }
        let renderer = UIGraphicsImageRenderer(bounds: skView.bounds)
        return renderer.image { _ in
            skView.drawHierarchy(in: skView.bounds, afterScreenUpdates: false)
        }.cgImage
    }

    private func findView<T: UIView>(ofType type: T.Type, in view: UIView) -> T? {
        if let found = view as? T { return found }
        for sub in view.subviews {
            if let found = findView(ofType: type, in: sub) { return found }
        }
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
        case ..<0.25: "SLOW"; case 0.25..<0.5: "STEADY"
        case 0.5..<0.75: "BRISK"; default: "FAST"
        }
    }
    private var formLabel: String {
        switch form {
        case ..<0.2:      "SLENDER"
        case 0.2..<0.45:  "SLIM"
        case 0.45..<0.55: "NORMAL"
        case 0.55..<0.8:  "ROUND"
        default:          "BARREL"
        }
    }
    private var colorLabel: String {
        switch colorHue {
        case ..<0.08: "AMBER"; case 0.08..<0.15: "GOLD"
        case 0.15..<0.40: "GREEN"; case 0.40..<0.65: "BLUE"
        case 0.65..<0.80: "VIOLET"; default: "ROSE"
        }
    }
}

#Preview { HourglassView(onPickerTap: {}) }
#endif
