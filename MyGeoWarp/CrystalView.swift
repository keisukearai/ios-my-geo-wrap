#if canImport(UIKit)
import SwiftUI
import SpriteKit
import CoreMotion
import Combine

// MARK: - Crystal Frame (ImageRenderer用 — 決定的アニメーション)

private struct CrystalSeedItem {
    let baseAngle, baseDist, crystalSize: Double
    let type, colorIdx: Int
    let floatPhase, floatFreq, floatAmp, initRot, rotSpeed: Double
}

private let crystalSeed: [CrystalSeedItem] = (0..<440).map { i in
    let f = Double(i)
    return CrystalSeedItem(
        baseAngle:   f * 2.3999,
        baseDist:    sqrt((f + 1.0) / 440.0) * 0.78,
        crystalSize: 1.75 + (f.truncatingRemainder(dividingBy: 5.0)) * 0.75,
        type:        i % 3,
        colorIdx:    i % 6,
        floatPhase:  f * 1.6180,
        floatFreq:   0.28 + (f.truncatingRemainder(dividingBy: 7.0)) * 0.09,
        floatAmp:    4.0  + (f.truncatingRemainder(dividingBy: 4.0)) * 2.0,
        initRot:     f * 0.70,
        rotSpeed:    0.10 + (f.truncatingRemainder(dividingBy: 5.0)) * 0.04
    )
}

struct CrystalFrame: View {
    var t: Double
    let spin:    Double
    let gravity: Double
    let size:    CGSize

    var body: some View {
        Canvas { ctx, sz in
            ctx.fill(Path(CGRect(origin: .zero, size: sz)),
                     with: .color(Color(red: 0.04, green: 0.05, blue: 0.14)))

            let r  = min(sz.width, sz.height) * 0.40
            let cx = sz.width  / 2
            let cy = sz.height / 2

            let ringAngle = t * (0.08 + spin * 0.22)
            drawRing(&ctx, cx: cx, cy: cy, r: r, angle: ringAngle)
            drawCrystals(&ctx, cx: cx, cy: cy, r: r)
        }
        .frame(width: size.width, height: size.height)
    }

    private func drawRing(_ ctx: inout GraphicsContext,
                          cx: Double, cy: Double, r: Double, angle: Double) {
        // outer glow
        ctx.stroke(
            Path(ellipseIn: CGRect(x: cx-(r+5), y: cy-(r+5), width: (r+5)*2, height: (r+5)*2)),
            with: .color(Color(red: 0.50, green: 0.85, blue: 1.0).opacity(0.18)),
            lineWidth: 10
        )
        // main ring
        ctx.stroke(
            Path(ellipseIn: CGRect(x: cx-r, y: cy-r, width: r*2, height: r*2)),
            with: .color(Color(red: 0.72, green: 0.93, blue: 1.0).opacity(0.85)),
            lineWidth: 1.5
        )
        // ticks
        for i in 0..<12 {
            let a     = angle + Double(i) * .pi / 6
            let major = i % 3 == 0
            let inn   = r - (major ? 10.0 : 6.0)
            let out   = r + (major ? 10.0 : 6.0)
            var p = Path()
            p.move(to:    CGPoint(x: cx + cos(a)*inn, y: cy + sin(a)*inn))
            p.addLine(to: CGPoint(x: cx + cos(a)*out, y: cy + sin(a)*out))
            ctx.stroke(p, with: .color(.white.opacity(major ? 0.85 : 0.42)),
                       lineWidth: major ? 1.5 : 1.0)
        }
        // gems
        for i in 0..<8 {
            let a = angle + Double(i) * .pi / 4
            let gx = cx + cos(a) * r
            let gy = cy + sin(a) * r
            let gem = diamondPath(size: 5).applying(
                CGAffineTransform(translationX: gx, y: gy).rotated(by: a))
            ctx.fill(gem,   with: .color(Color(red: 0.75, green: 0.96, blue: 1.0).opacity(0.90)))
            ctx.stroke(gem, with: .color(.white.opacity(0.80)), lineWidth: 0.5)
        }
    }

    private func drawCrystals(_ ctx: inout GraphicsContext,
                               cx: Double, cy: Double, r: Double) {
        let palette: [Color] = [
            Color(red: 0.75, green: 0.92, blue: 1.00).opacity(0.70),
            Color(red: 0.82, green: 0.72, blue: 1.00).opacity(0.65),
            Color(red: 0.55, green: 0.95, blue: 1.00).opacity(0.60),
            Color(red: 0.95, green: 0.95, blue: 1.00).opacity(0.75),
            Color(red: 0.65, green: 0.85, blue: 0.95).opacity(0.55),
            Color(red: 0.90, green: 0.80, blue: 1.00).opacity(0.62),
        ]
        let gravOffset = gravity * r * 0.30

        for s in crystalSeed {
            var fx = cx + cos(s.baseAngle) * s.baseDist * r
                       + sin(t * s.floatFreq + s.floatPhase) * s.floatAmp
            var fy = cy + sin(s.baseAngle) * s.baseDist * r + gravOffset
                       + cos(t * s.floatFreq * 0.8 + s.floatPhase) * s.floatAmp * 0.5

            let dx = fx - cx, dy = fy - cy
            let dist = sqrt(dx*dx + dy*dy)
            let limit = r * 0.82
            if dist > limit { fx = cx + dx/dist*limit; fy = cy + dy/dist*limit }

            let rot = s.initRot + t * s.rotSpeed
            let xf  = CGAffineTransform(translationX: fx, y: fy).rotated(by: rot)
            let path: Path
            switch s.type {
            case 0:  path = hexPath(size: s.crystalSize).applying(xf)
            case 1:  path = diamondPath(size: s.crystalSize).applying(xf)
            default: path = triPath(size: s.crystalSize).applying(xf)
            }
            ctx.fill(path,   with: .color(palette[s.colorIdx]))
            ctx.stroke(path, with: .color(.white.opacity(0.72)), lineWidth: 0.8)
        }
    }

    // MARK: Path helpers

    private func hexPath(size s: Double) -> Path {
        Path { p in
            for i in 0..<6 {
                let a = Double(i) * .pi / 3
                let pt = CGPoint(x: cos(a)*s, y: sin(a)*s)
                i == 0 ? p.move(to: pt) : p.addLine(to: pt)
            }
            p.closeSubpath()
        }
    }
    private func diamondPath(size s: Double) -> Path {
        Path { p in
            p.move(to:    CGPoint(x:  0,      y:  s))
            p.addLine(to: CGPoint(x:  s*0.55, y:  0))
            p.addLine(to: CGPoint(x:  0,      y: -s))
            p.addLine(to: CGPoint(x: -s*0.55, y:  0))
            p.closeSubpath()
        }
    }
    private func triPath(size s: Double) -> Path {
        Path { p in
            p.move(to:    CGPoint(x:  0,     y:  s))
            p.addLine(to: CGPoint(x:  s*0.87, y: -s*0.5))
            p.addLine(to: CGPoint(x: -s*0.87, y: -s*0.5))
            p.closeSubpath()
        }
    }
}

// MARK: - Crystal Scene

class CrystalScene: SKScene, SKPhysicsContactDelegate {

    var spinSpeed: Double = 0.5 {
        didSet { run(SKAction.run { [weak self] in self?.updateContainerRotation() }) }
    }
    var gravityScale: Double = 0.5
    var chaosLevel:   Double = 0.0

    private let motionManager = CMMotionManager()
    private var lastSparkTime: TimeInterval = 0
    private var lastChaosTime: TimeInterval = 0
    private var lastNudgeTime: TimeInterval = 0
    private weak var containerNode: SKNode?

    override func didMove(to view: SKView) {
        view.preferredFramesPerSecond = 30
        backgroundColor = UIColor(red: 0.04, green: 0.05, blue: 0.14, alpha: 1.0)
        physicsWorld.gravity = CGVector(dx: 0, dy: -5.0)
        physicsWorld.contactDelegate = self
        setupContainer()
        spawnCrystalsWithDelay()
        startMotionUpdates()
    }

    private var containerRadius: CGFloat { min(size.width, size.height) * 0.40 }
    private var containerCenter: CGPoint { CGPoint(x: size.width / 2, y: size.height / 2) }

    // MARK: - Container

    private func setupContainer() {
        let r = containerRadius
        let c = containerCenter

        let node = SKNode()
        node.position = c

        // 外周の物理境界（円）
        let circlePath = CGMutablePath()
        circlePath.addEllipse(in: CGRect(x: -r, y: -r, width: r*2, height: r*2))
        node.physicsBody = SKPhysicsBody(edgeLoopFrom: circlePath)
        node.physicsBody?.friction    = 0.50
        node.physicsBody?.restitution = 0.15

        // 内部フィン ×3（120° 間隔）— 回転で水晶を押し動かす
        for i in 0..<3 {
            let angle = CGFloat(i) * (.pi * 2 / 3)

            // 物理エッジ（V字形：中央でくぼみ、石が引っかかるポケットを作る）
            let finPhys = SKNode()
            let fp = CGMutablePath()
            fp.move(to:    CGPoint(x: r * 0.10, y:  0))
            fp.addLine(to: CGPoint(x: r * 0.53, y: -r * 0.10))
            fp.addLine(to: CGPoint(x: r * 0.96, y:  0))
            finPhys.physicsBody = SKPhysicsBody(edgeChainFrom: fp)
            finPhys.physicsBody?.friction    = 0.80
            finPhys.physicsBody?.restitution = 0.05
            finPhys.zRotation = angle
            node.addChild(finPhys)

            // 視覚ライン
            let finShape = SKShapeNode(path: fp)
            finShape.strokeColor = UIColor(red: 0.60, green: 0.88, blue: 1.0, alpha: 0.38)
            finShape.lineWidth   = 2.0
            finShape.glowWidth   = 2.5
            finShape.zRotation   = angle
            node.addChild(finShape)
        }

        // 装飾リング
        node.addChild(buildRing(radius: r))

        addChild(node)
        containerNode = node
        updateContainerRotation()
    }

    private func buildRing(radius r: CGFloat) -> SKNode {
        let root = SKNode()

        let glow = SKShapeNode(circleOfRadius: r + 5)
        glow.fillColor = .clear
        glow.strokeColor = UIColor(red: 0.50, green: 0.85, blue: 1.0, alpha: 0.20)
        glow.lineWidth = 10
        root.addChild(glow)

        let main = SKShapeNode(circleOfRadius: r)
        main.fillColor = .clear
        main.strokeColor = UIColor(red: 0.72, green: 0.93, blue: 1.0, alpha: 0.85)
        main.lineWidth = 1.5
        main.glowWidth = 2.5
        root.addChild(main)

        for i in 0..<12 {
            let a     = CGFloat(i) * .pi / 6
            let major = i % 3 == 0
            let inn   = r - (major ? 10 : 6) as CGFloat
            let out   = r + (major ? 10 : 6) as CGFloat
            let p = CGMutablePath()
            p.move(to:    CGPoint(x: cos(a)*inn, y: sin(a)*inn))
            p.addLine(to: CGPoint(x: cos(a)*out, y: sin(a)*out))
            let tick = SKShapeNode(path: p)
            tick.strokeColor = UIColor(white: 1.0, alpha: major ? 0.85 : 0.45)
            tick.lineWidth   = major ? 1.5 : 1.0
            if major { tick.glowWidth = 1.0 }
            root.addChild(tick)
        }

        for i in 0..<8 {
            let a   = CGFloat(i) * .pi / 4
            let gem = SKShapeNode(path: diamondCGPath(size: 5))
            gem.position    = CGPoint(x: cos(a)*r, y: sin(a)*r)
            gem.zRotation   = a
            gem.fillColor   = UIColor(red: 0.75, green: 0.96, blue: 1.0, alpha: 0.90)
            gem.strokeColor = UIColor(white: 1.0, alpha: 0.8)
            gem.lineWidth   = 0.5
            gem.glowWidth   = 2.0
            root.addChild(gem)
        }

        return root
    }

    private func updateContainerRotation() {
        guard let c = containerNode else { return }
        c.removeAllActions()
        guard spinSpeed > 0.01 else { return }
        let dur = 8.0 + (1.0 - spinSpeed) * 72.0
        c.run(SKAction.repeatForever(
            SKAction.rotate(byAngle: .pi * 2, duration: dur)
        ))
    }

    // MARK: - Crystal shapes (CGPath)

    private func hexCGPath(size s: CGFloat) -> CGPath {
        let p = CGMutablePath()
        for i in 0..<6 {
            let a = CGFloat(i) * .pi / 3
            let pt = CGPoint(x: cos(a)*s, y: sin(a)*s)
            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
        p.closeSubpath(); return p
    }
    private func diamondCGPath(size s: CGFloat) -> CGPath {
        let p = CGMutablePath()
        p.move(to:    CGPoint(x:  0,      y:  s))
        p.addLine(to: CGPoint(x:  s*0.55, y:  0))
        p.addLine(to: CGPoint(x:  0,      y: -s))
        p.addLine(to: CGPoint(x: -s*0.55, y:  0))
        p.closeSubpath(); return p
    }
    private func triCGPath(size s: CGFloat) -> CGPath {
        let p = CGMutablePath()
        p.move(to:    CGPoint(x:  0,      y:  s))
        p.addLine(to: CGPoint(x:  s*0.87, y: -s*0.5))
        p.addLine(to: CGPoint(x: -s*0.87, y: -s*0.5))
        p.closeSubpath(); return p
    }

    // MARK: - Spawn

    private func spawnCrystalsWithDelay() {
        let batchSize = 20
        let totalBatches = (440 + batchSize - 1) / batchSize
        for b in 0..<totalBatches {
            run(SKAction.sequence([
                SKAction.wait(forDuration: Double(b) * 0.08),
                SKAction.run { [weak self] in
                    guard let self else { return }
                    let start = b * batchSize
                    let end   = min(start + batchSize, 440)
                    for _ in start..<end { self.addCrystal() }
                }
            ]))
        }
    }

    private func addCrystal() {
        let r = containerRadius; let c = containerCenter
        let sz = CGFloat.random(in: 1.75...5.5)
        let type = Int.random(in: 0..<3)
        let path: CGPath
        switch type {
        case 0:  path = hexCGPath(size: sz)
        case 1:  path = diamondCGPath(size: sz)
        default: path = triCGPath(size: sz)
        }

        let node = SKShapeNode(path: path)
        let angle = CGFloat.random(in: 0...(2 * .pi))
        let dist  = CGFloat.random(in: 0...(r * 0.55))
        node.position  = CGPoint(x: c.x + cos(angle)*dist, y: c.y + dist*0.1 + r*0.15)
        node.zRotation = CGFloat.random(in: 0...(2 * .pi))

        let palette: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (0.75, 0.92, 1.00, 0.70), (0.82, 0.72, 1.00, 0.65),
            (0.55, 0.95, 1.00, 0.60), (0.95, 0.95, 1.00, 0.75),
            (0.65, 0.85, 0.95, 0.55), (0.90, 0.80, 1.00, 0.62),
        ]
        let col = palette.randomElement()!
        node.fillColor   = UIColor(red: col.0, green: col.1, blue: col.2, alpha: col.3)
        node.strokeColor = UIColor(white: 1.0, alpha: 0.72)
        node.lineWidth   = 0.8
        node.glowWidth   = Bool.random() ? 1.5 : 0.0

        node.physicsBody = SKPhysicsBody(polygonFrom: path)
        node.physicsBody?.restitution                = 0.60
        node.physicsBody?.friction                   = 0.10
        node.physicsBody?.density                    = 1.5
        node.physicsBody?.linearDamping              = 0.05
        node.physicsBody?.angularDamping             = 0.05
        node.physicsBody?.usesPreciseCollisionDetection = false
        node.physicsBody?.categoryBitMask    = 0x1
        node.physicsBody?.contactTestBitMask = 0x1
        node.physicsBody?.collisionBitMask   = 0xFFFFFFFF
        addChild(node)
    }

    // MARK: - CoreMotion + Update

    private func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        motionManager.startDeviceMotionUpdates()
    }

    override func update(_ currentTime: TimeInterval) {
        // 重力の「強さ」= スライダー、「方向」= 傾き
        let strength = 1.0 + gravityScale * 19.0   // 1（FLOAT）… 20（HEAVY）
        if let g = motionManager.deviceMotion?.gravity {
            let len = sqrt(g.x*g.x + g.y*g.y)
            if len > 0.05 {
                physicsWorld.gravity = CGVector(dx: g.x/len * strength,
                                                dy: g.y/len * strength)
            } else {
                physicsWorld.gravity = CGVector(dx: 0, dy: -strength)
            }
        } else {
            physicsWorld.gravity = CGVector(dx: 0, dy: -strength)
        }
        if chaosLevel > 0.01 {
            let interval = max(0.80, 3.6 - chaosLevel * 2.2)
            if currentTime - lastChaosTime > interval {
                lastChaosTime = currentTime
                applyChaos()
            }
        }
        if chaosLevel > 0.01, currentTime - lastNudgeTime > 1.5 {
            lastNudgeTime = currentTime
            nudgeStillBodies()
        }
    }

    private func nudgeStillBodies() {
        children.compactMap { $0 as? SKShapeNode }.forEach { node in
            guard let body = node.physicsBody, body.isDynamic else { return }
            let v = body.velocity
            if sqrt(v.dx*v.dx + v.dy*v.dy) < 2.0 {
                body.applyImpulse(CGVector(
                    dx: CGFloat.random(in: -0.4...0.4),
                    dy: CGFloat.random(in: 0.1...0.5)
                ))
            }
        }
    }

    private func applyChaos() {
        let strength = CGFloat(chaosLevel * 2)
        children.compactMap { $0 as? SKShapeNode }.forEach { node in
            guard node.physicsBody?.isDynamic == true, Bool.random() else { return }
            node.physicsBody?.applyImpulse(CGVector(
                dx: CGFloat.random(in: -strength...strength),
                dy: CGFloat.random(in: 0...strength * 0.8)
            ))
        }
    }

    // MARK: - Sparkle

    func didBegin(_ contact: SKPhysicsContact) {
        let now = CACurrentMediaTime()
        guard now - lastSparkTime > 0.08, contact.collisionImpulse > 0.5 else { return }
        lastSparkTime = now
        for _ in 0..<3 {
            let spark = SKShapeNode(circleOfRadius: CGFloat.random(in: 1.0...2.5))
            spark.position    = contact.contactPoint
            spark.fillColor   = UIColor(hue: CGFloat.random(in: 0.55...0.72),
                                        saturation: 0.3, brightness: 1.0, alpha: 0.95)
            spark.strokeColor = .clear
            spark.glowWidth   = 3.5
            addChild(spark)
            spark.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: CGFloat.random(in: -30...30),
                                   y: CGFloat.random(in: 15...55), duration: 0.28),
                    SKAction.fadeOut(withDuration: 0.28),
                ]),
                SKAction.removeFromParent()
            ]))
        }
    }

    override func willMove(from view: SKView) {
        motionManager.stopDeviceMotionUpdates()
    }
}

// MARK: - Scene Store

private final class CrystalSceneStore: ObservableObject {
    private(set) var scene: CrystalScene?
    func scene(for size: CGSize) -> CrystalScene {
        if let s = scene { return s }
        let s = CrystalScene(size: size); s.scaleMode = .resizeFill
        scene = s; return s
    }
}

// MARK: - Crystal View

struct CrystalView: View {
    let onPickerTap: () -> Void

    @StateObject private var store    = CrystalSceneStore()
    @StateObject private var recorder = WallpaperRecorder()

    @State private var spin:    Double = 0.5
    @State private var gravity: Double = 0.5
    @State private var chaos:   Double = 0.0
    @State private var showUI:  Bool   = true

    @State private var isAutoMode:        Bool   = false
    @State private var autoTargetGravity: Double = 0.5
    @State private var autoTargetChaos:  Double = 0.0
    @State private var autoNextGravity:  Date   = .distantPast
    @State private var autoNextChaos:    Date   = .distantPast
    @State private var lastAutoTick:     Date?  = nil

    private let accent = Color(red: 0.55, green: 0.88, blue: 1.00)

    var body: some View {
        ZStack {
            mainContent
                .opacity(recorder.isActive ? 0 : 1)
                .allowsHitTesting(!recorder.isActive)

            if recorder.isActive { recordingOverlay }
        }
        .onChange(of: spin)    { store.scene?.spinSpeed    = $0 }
        .onChange(of: gravity) { store.scene?.gravityScale = $0 }
        .onChange(of: chaos)   { store.scene?.chaosLevel   = $0 }
        .onChange(of: showUI)  { store.scene?.view?.preferredFramesPerSecond = $0 ? 30 : 24 }
        .onAppear {
            spin    = Double.random(in: 0.2...0.8)
            gravity = Double.random(in: 0.3...0.7)
            chaos   = 0.0
        }
        .onReceive(Timer.publish(every: 1.0/10.0, on: .main, in: .common).autoconnect()) { now in
            guard isAutoMode else { lastAutoTick = nil; return }
            let dt = min(lastAutoTick.map { now.timeIntervalSince($0) } ?? (1.0/10.0), 0.5)
            lastAutoTick = now
            if now >= autoNextGravity { autoTargetGravity = Double.random(in: 0...1);    autoNextGravity = now.addingTimeInterval(9) }
            if now >= autoNextChaos   { autoTargetChaos   = Double.random(in: 0...0.55); autoNextChaos   = now.addingTimeInterval(5) }
            gravity += (autoTargetGravity - gravity) * 0.03 * dt
            chaos   += (autoTargetChaos   - chaos)   * 0.08 * dt
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
            Color(red: 0.04, green: 0.05, blue: 0.14).ignoresSafeArea()
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
                Text("CRYSTAL")
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
            sliderRow("SPIN",    spinLabel,    value: $spin)
            sliderRow("GRAVITY", gravityLabel, value: $gravity)
            sliderRow("CHAOS",   chaosLabel,   value: $chaos)
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
                    autoTargetGravity = Double.random(in: 0...1)
                    autoTargetChaos   = Double.random(in: 0...0.4)
                    autoNextGravity   = Date().addingTimeInterval(9)
                    autoNextChaos     = Date().addingTimeInterval(5)
                    lastAutoTick      = nil
                } else {
                    lastAutoTick = nil
                }
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
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(accent.opacity(isAutoMode ? 0 : 0.35), lineWidth: 1)
                    )
            }
            .shadow(color: isAutoMode ? accent.opacity(0.45) : .clear, radius: 8)

            Button {
                let snapshot = captureCurrentFrame()
                Task {
                    await recorder.startCrystal(spin: spin, gravity: gravity, stillSnapshot: snapshot)
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

    private var spinLabel: String {
        switch spin {
        case ..<0.25: "STILL"; case 0.25..<0.5: "SLOW"
        case 0.5..<0.75: "SPIN"; default: "RAPID"
        }
    }
    private var gravityLabel: String {
        switch gravity {
        case ..<0.25: "FLOAT"; case 0.25..<0.5: "SOFT"
        case 0.5..<0.75: "PULL"; default: "HEAVY"
        }
    }
    private var chaosLabel: String {
        switch chaos {
        case ..<0.25: "CALM"; case 0.25..<0.5: "STIR"
        case 0.5..<0.75: "WILD"; default: "STORM"
        }
    }
}

#Preview { CrystalView(onPickerTap: {}) }
#endif
