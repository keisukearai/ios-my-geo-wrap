#if canImport(UIKit)
import Combine
import SpriteKit
import SwiftUI

// MARK: - Stone Color Palette

private func hourglassGrainHSB(at t: CGFloat, variantOffset: CGFloat = 0) -> (h: CGFloat, s: CGFloat, b: CGFloat) {
    let palette: [(CGFloat, CGFloat, CGFloat)] = [
        (0.06, 0.30, 0.54),  // UMBER
        (0.07, 0.14, 0.44),  // FLINT
        (0.08, 0.05, 0.40),  // GRAY
        (0.78, 0.18, 0.42),  // DUSK
        (0.80, 0.22, 0.34),  // SHADOW
        (0.80, 0.15, 0.24),  // ONYX
    ]
    let clamped = min(max(t + variantOffset, 0), 1)
    let scaled  = clamped * CGFloat(palette.count - 1)
    let lo = min(Int(scaled), palette.count - 2)
    let frac = scaled - CGFloat(lo)
    let (h0, s0, b0) = palette[lo]
    let (h1, s1, b1) = palette[lo + 1]
    return (h0 + (h1 - h0) * frac, s0 + (s1 - s0) * frac, b0 + (b1 - b0) * frac)
}

// MARK: - Hourglass Frame (ImageRenderer用 — 決定的アニメーション)

struct HourglassFrame: View {
    var t: Double
    let speed: Double
    let colorHue: Double
    let form: Double
    let size: CGSize

    private var cycleDuration: Double { 30.0 + (1.0 - speed) * 330.0 }

    private var shapeFactors: (neck: Double, topX: Double, topY: Double, bulge: Double) {
        let slender = form < 0.5 ? (0.5 - form) * 2.0 : 0.0
        let barrel  = form > 0.5 ? (form - 0.5) * 2.0 : 0.0
        return (
            neck: 0.100 - slender * 0.008 - barrel * 0.003,
            topX: 0.88 * (1.0 - slender * 0.40),
            topY: 0.88 * (1.0 + slender * 0.50),
            bulge: 0.88 * barrel * 0.45
        )
    }

    var body: some View {
        Canvas { ctx, sz in
            ctx.fill(Path(CGRect(origin: .zero, size: sz)),
                     with: .color(Color(red: 0.14, green: 0.13, blue: 0.15)))

            let r  = min(sz.width, sz.height) * 0.32
            let cx = sz.width  / 2
            let cy = sz.height / 2

            let containerAngle = floor(t / (cycleDuration / 2)) * .pi

            drawGlass(&ctx, cx: cx, cy: cy, r: r, t: t, rotation: containerAngle)
            drawSand(&ctx, cx: cx, cy: cy, r: r, t: t, rotation: containerAngle)
        }
        .frame(width: size.width, height: size.height)
    }

    private func drawGlass(_ ctx: inout GraphicsContext,
                            cx: Double, cy: Double, r: Double, t: Double, rotation: Double) {
        let metalShadow = Color(red: 0.42, green: 0.43, blue: 0.46).opacity(0.70)
        let metalSilver = Color(red: 0.82, green: 0.84, blue: 0.88).opacity(0.82)
        let metalGlint  = Color.white.opacity(0.38)

        // hourglass outline (rotated)
        let glassPath = hourglassCGPath(cx: cx, cy: cy, r: r, rotation: rotation)
        ctx.stroke(glassPath, with: .color(metalShadow), lineWidth: 1.8)
        ctx.stroke(glassPath, with: .color(metalSilver), lineWidth: 0.9)
        ctx.stroke(glassPath, with: .color(metalGlint), lineWidth: 0.25)
        drawMetalGlint(&ctx, cx: cx, cy: cy, r: r, t: t, rotation: rotation)
    }

    private func drawMetalGlint(_ ctx: inout GraphicsContext,
                                 cx: Double, cy: Double, r: Double, t: Double, rotation: Double) {
        let glintCycle = 7.5
        let glintTime = t.truncatingRemainder(dividingBy: glintCycle)
        guard glintTime < 0.55 else { return }

        let pulse = sin((glintTime / 0.55) * .pi)
        let shape = shapeFactors
        let topX = r * shape.topX
        let topY = r * shape.topY
        let localX = topX * 0.64
        let localY = -topY

        func rotPt(_ x: Double, _ y: Double) -> CGPoint {
            let rx = x * cos(rotation) - y * sin(rotation)
            let ry = x * sin(rotation) + y * cos(rotation)
            return CGPoint(x: cx + rx, y: cy + ry)
        }

        let len = max(7.0, r * 0.035)
        let center = rotPt(localX, localY)
        var glint = Path()
        glint.move(to: CGPoint(x: center.x - len, y: center.y))
        glint.addLine(to: CGPoint(x: center.x + len, y: center.y))
        glint.move(to: CGPoint(x: center.x, y: center.y - len))
        glint.addLine(to: CGPoint(x: center.x, y: center.y + len))

        ctx.stroke(glint, with: .color(Color.white.opacity(0.28 * pulse)), lineWidth: 1.0)
    }

    private func hourglassCGPath(cx: Double, cy: Double, r: Double, rotation: Double) -> Path {
        let shape = shapeFactors
        let neck  = r * shape.neck
        let topX  = r * shape.topX
        let topY  = r * shape.topY
        let bulge = r * shape.bulge

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
        let (sh, ss, sb) = hourglassGrainHSB(at: CGFloat(colorHue))
        let sandColor = Color(hue: Double(sh), saturation: Double(ss), brightness: min(Double(sb) + 0.20, 1.0)).opacity(0.82)
        let phase = (t.truncatingRemainder(dividingBy: cycleDuration)) / cycleDuration
        let fillRatio = 1.0 - phase

        let shape = shapeFactors
        let neck  = r * shape.neck
        let topX  = r * shape.topX
        let topY  = r * shape.topY

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
            let grainR = max(1.7, r / 70.0)
            let streamLen = r * 0.26
            for i in 0..<8 {
                let seed = Double(i)
                let dropPhase = (phase * 48.0 + seed * 0.37).truncatingRemainder(dividingBy: 1.0)
                let wobble = sin((phase * 17.0 + seed) * .pi * 2.0) * grainR * 0.45
                let y = -neck + streamLen * dropPhase
                let p = rotPt(wobble, y)
                let rect = CGRect(x: p.x - grainR, y: p.y - grainR, width: grainR * 2, height: grainR * 2)
                ctx.fill(Path(ellipseIn: rect), with: .color(sandColor.opacity(0.42 + 0.26 * (1.0 - dropPhase))))
            }
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
    private weak var glintNode: SKNode?
    private var streamNodes: [SKSpriteNode] = []

    override func didMove(to view: SKView) {
        view.preferredFramesPerSecond = 30
        backgroundColor = UIColor(red: 0.14, green: 0.13, blue: 0.15, alpha: 1.0)
        physicsWorld.gravity = CGVector(dx: 0, dy: -9.8)
        setupContainer()
        spawnGrains()
        scheduleFlip()
    }

    private var containerRadius: CGFloat { min(size.width, size.height) * 0.32 }
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
        buildFallingStream(node: node, r: r)
    }

    private func shapeParams() -> (neck: CGFloat, topX: CGFloat, topY: CGFloat, bulge: CGFloat) {
        let r       = containerRadius
        let baseTop: CGFloat = r * 0.88
        let slender = form2 < 0.5 ? CGFloat((0.5 - form2) * 2.0) : 0.0
        let barrel  = form2 > 0.5 ? CGFloat((form2 - 0.5) * 2.0) : 0.0
        let neck: CGFloat = r * (0.100 - slender * 0.008 - barrel * 0.003)
        return (neck,
                baseTop * (1.0 - slender * 0.40),
                baseTop * (1.0 + slender * 0.50),
                baseTop * barrel * 0.45)
    }

    private func rebuildWalls() {
        guard let node = containerNode else { return }
        let oldWalls   = wallNodes
        let oldOutline = outlineNode
        let oldGlint   = glintNode
        let oldStream  = streamNodes
        wallNodes = []
        streamNodes = []
        buildGlassWalls(node: node, r: containerRadius)
        buildFallingStream(node: node, r: containerRadius)
        oldWalls.forEach   { $0.removeFromParent() }
        oldOutline?.removeFromParent()
        oldGlint?.removeFromParent()
        oldStream.forEach { $0.removeFromParent() }
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
        outline.fillColor   = UIColor(red: 0.52, green: 0.54, blue: 0.58, alpha: 0.14)
        outline.strokeColor = UIColor(red: 0.82, green: 0.84, blue: 0.88, alpha: 0.86)
        outline.lineWidth   = 1.2
        outline.glowWidth   = 0.7

        let innerLine = SKShapeNode()
        innerLine.path = outlinePath
        innerLine.fillColor = .clear
        innerLine.strokeColor = UIColor(white: 1.0, alpha: 0.28)
        innerLine.lineWidth = 0.35
        innerLine.glowWidth = 0.15
        outline.addChild(innerLine)

        node.addChild(outline)
        outlineNode = outline

        let glintPath = CGMutablePath()
        let glintSize = max(r * 0.035, 7.0)
        glintPath.move(to: CGPoint(x: -glintSize, y: 0))
        glintPath.addLine(to: CGPoint(x: glintSize, y: 0))
        glintPath.move(to: CGPoint(x: 0, y: -glintSize))
        glintPath.addLine(to: CGPoint(x: 0, y: glintSize))

        let glint = SKShapeNode(path: glintPath)
        glint.position = CGPoint(x: topX * 0.64, y: topY)
        glint.strokeColor = UIColor(white: 1.0, alpha: 0.0)
        glint.lineWidth = 1.0
        glint.glowWidth = 1.6
        glint.setScale(0.65)
        node.addChild(glint)
        glintNode = glint

        let flash = SKAction.sequence([
            .wait(forDuration: 3.2, withRange: 2.8),
            .group([
                .sequence([
                    .fadeAlpha(to: 0.30, duration: 0.16),
                    .fadeAlpha(to: 0.0, duration: 0.38)
                ]),
                .sequence([
                    .scale(to: 1.0, duration: 0.16),
                    .scale(to: 0.65, duration: 0.38)
                ])
            ])
        ])
        glint.run(.repeatForever(flash))
    }

    private func buildFallingStream(node: SKNode, r: CGFloat) {
        let (_, _, topY, _) = shapeParams()
        let grainRadius = r / 44.0 * 0.56
        let textures: [SKTexture] = (0..<3).map { i in
            let offset = CGFloat(i) * 0.04
            let (h, s, b) = grainHSB(at: CGFloat(colorHue), variantOffset: offset)
            return makeGrainTexture(radius: grainRadius * CGFloat(0.72 + Double(i) * 0.08),
                                    hue: h, saturation: s, brightness: b)
        }

        for i in 0..<10 {
            let grain = SKSpriteNode(texture: textures[i % textures.count],
                                     size: CGSize(width: grainRadius * 1.45, height: grainRadius * 1.45))
            grain.alpha = 0.0
            grain.zPosition = 4
            grain.position = CGPoint(x: 0, y: 0)
            node.addChild(grain)
            streamNodes.append(grain)

            let delay = Double(i) * 0.18
            let fall = SKAction.sequence([
                .wait(forDuration: delay),
                .repeatForever(.sequence([
                    .run { [weak grain] in
                        let x = CGFloat.random(in: -grainRadius * 0.35...grainRadius * 0.35)
                        grain?.position = CGPoint(x: x, y: topY * 0.03)
                        grain?.alpha = CGFloat.random(in: 0.45...0.72)
                    },
                    .group([
                        .moveBy(x: CGFloat.random(in: -grainRadius * 0.5...grainRadius * 0.5),
                                y: -r * 0.24,
                                duration: 0.85),
                        .sequence([
                            .fadeAlpha(to: 0.72, duration: 0.18),
                            .fadeAlpha(to: 0.0, duration: 0.67)
                        ])
                    ]),
                    .wait(forDuration: 0.18)
                ]))
            ])
            grain.run(fall)
        }
    }

    // MARK: - Grains

    private func makeGrainTexture(radius: CGFloat, hue: CGFloat, saturation: CGFloat, brightness: CGFloat) -> SKTexture {
        let diameter = Int(ceil(radius * 2))
        let size = CGSize(width: diameter, height: diameter)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 0.88).setFill()
            ctx.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
            UIColor(white: 1.0, alpha: 0.25).setFill()
            let inset: CGFloat = max(1, radius * 0.15)
            ctx.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset))
        }
        return SKTexture(image: image)
    }

    private func grainHSB(at t: CGFloat, variantOffset: CGFloat = 0) -> (h: CGFloat, s: CGFloat, b: CGFloat) {
        hourglassGrainHSB(at: t, variantOffset: variantOffset)
    }

    private func spawnGrains() {
        guard let node = containerNode else { return }
        let r = containerRadius
        let grainRadius: CGFloat = r / 44.0 * 0.56
        let mediumGrainRadius: CGFloat = grainRadius * 1.5
        let largeGrainRadius: CGFloat = grainRadius * 2.0
        let hue = CGFloat(colorHue)

        let textures = (0..<5).map { i -> SKTexture in
            let (h, s, b) = grainHSB(at: hue, variantOffset: CGFloat(i) * 0.04)
            return makeGrainTexture(radius: grainRadius, hue: h, saturation: s, brightness: b)
        }
        let mediumTextures = (0..<5).map { i -> SKTexture in
            let (h, s, b) = grainHSB(at: hue, variantOffset: CGFloat(i) * 0.04)
            return makeGrainTexture(radius: mediumGrainRadius, hue: h, saturation: s, brightness: b)
        }
        let largeTextures = (0..<5).map { i -> SKTexture in
            let (h, s, b) = grainHSB(at: hue, variantOffset: CGFloat(i) * 0.04)
            return makeGrainTexture(radius: largeGrainRadius, hue: h, saturation: s, brightness: b)
        }

        let (neck, topX, topY, _) = shapeParams()

        for i in 0..<346 {
            let radius: CGFloat
            let tex: SKTexture
            if i < 35 {          // 2x: ~10%
                radius = largeGrainRadius
                tex = largeTextures[i % 5]
            } else if i < 70 {   // 1.5x: ~10%
                radius = mediumGrainRadius
                tex = mediumTextures[i % 5]
            } else {             // 1x: ~80%
                radius = grainRadius
                tex = textures[i % 5]
            }
            let size = CGSize(width: radius * 2, height: radius * 2)
            let margin = radius * 2.5

            let grain = SKSpriteNode(texture: tex, size: size)
            let y = CGFloat.random(in: -(topY - margin) ... -(margin))
            let wallX = neck + (topX - neck) * (-y) / topY
            let maxX = wallX - margin
            guard maxX > 0 else { continue }
            let x = CGFloat.random(in: -maxX...maxX)
            grain.position = CGPoint(x: x, y: y)

            grain.physicsBody = SKPhysicsBody(circleOfRadius: radius)
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
        let t = CGFloat(colorHue)

        let grainRadius       = containerRadius / 44.0 * 0.56
        let mediumGrainRadius = grainRadius * 1.5
        let largeGrainRadius  = grainRadius * 2.0
        let textures = (0..<5).map { i -> SKTexture in
            let (h, s, b) = grainHSB(at: t, variantOffset: CGFloat(i) * 0.04)
            return makeGrainTexture(radius: grainRadius, hue: h, saturation: s, brightness: b)
        }
        let mediumTextures = (0..<5).map { i -> SKTexture in
            let (h, s, b) = grainHSB(at: t, variantOffset: CGFloat(i) * 0.04)
            return makeGrainTexture(radius: mediumGrainRadius, hue: h, saturation: s, brightness: b)
        }
        let largeTextures = (0..<5).map { i -> SKTexture in
            let (h, s, b) = grainHSB(at: t, variantOffset: CGFloat(i) * 0.04)
            return makeGrainTexture(radius: largeGrainRadius, hue: h, saturation: s, brightness: b)
        }
        for (i, grain) in grainNodes.enumerated() {
            let tex: SKTexture
            if i < 35 {
                tex = largeTextures[i % 5]
            } else if i < 70 {
                tex = mediumTextures[i % 5]
            } else {
                tex = textures[i % 5]
            }
            (grain as? SKSpriteNode)?.texture = tex
        }
        for (i, grain) in streamNodes.enumerated() {
            grain.texture = textures[i % 5]
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
    @State private var showUI:     Bool   = false
    @State private var autoColor:  Bool   = false

    @State private var isIdle:        Bool = false
    @State private var lastTouchDate: Date = .now

    private var uiColor: Color {
        let (h, s, b) = hourglassGrainHSB(at: CGFloat(colorHue))
        return Color(hue: Double(h), saturation: Double(s), brightness: max(Double(b) + 0.30, 0.55))
    }
    private let colorTimer      = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    private let idleCheckTimer  = Timer.publish(every: 5.0, on: .main, in: .common).autoconnect()
    private let speedRange: ClosedRange<Double> = 0...0.8

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
        .onChange(of: showUI)   { _ in store.scene?.view?.preferredFramesPerSecond = isIdle ? 15 : (showUI ? 30 : 20) }
        .onChange(of: isIdle)   { _ in store.scene?.view?.preferredFramesPerSecond = isIdle ? 15 : (showUI ? 30 : 20) }
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
        .onReceive(colorTimer) { _ in
            guard autoColor else { return }
            colorHue = (colorHue + 0.003).truncatingRemainder(dividingBy: 1.0)
        }
        .onAppear {
            speed    = Double.random(in: speedRange)
            form     = (Double.random(in: 0...1) + Double.random(in: 0...1)) / 2.0
            colorHue = Double.random(in: 0...1)
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
            Color(red: 0.14, green: 0.13, blue: 0.15).ignoresSafeArea()
            VStack(spacing: 20) {
                Spacer()
                Text(recorder.statusText)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                if case .rendering(let p) = recorder.state {
                    VStack(spacing: 8) {
                        ProgressView(value: p).tint(uiColor).padding(.horizontal, 40)
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

    // MARK: - Header

    @ViewBuilder
    private var headerView: some View {
        ZStack {
            VStack(spacing: 4) {
                Text("HOURGLASS")
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
            sliderRow("SPEED", speedLabel, value: $speed, in: speedRange)
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
                .foregroundColor(uiColor.opacity(0.5))
                .frame(width: 52, alignment: .leading)
            Slider(value: $colorHue, in: 0...1).tint(uiColor)
            Text(colorLabel)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(uiColor)
                .frame(width: 46, alignment: .trailing)
            Button { autoColor.toggle() } label: {
                Text("AUTO")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(autoColor ? .black : uiColor.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(autoColor ? uiColor : uiColor.opacity(0.15))
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
                    LinearGradient(colors: [uiColor, uiColor.opacity(0.75)],
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
    private func sliderRow(
        _ label: String,
        _ val: String,
        value: Binding<Double>,
        in range: ClosedRange<Double> = 0...1
    ) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(uiColor.opacity(0.5))
                .frame(width: 52, alignment: .leading)
            Slider(value: value, in: range).tint(uiColor)
            Text(val)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(uiColor)
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
        case ..<0.17: "UMBER"; case 0.17..<0.33: "FLINT"
        case 0.33..<0.50: "GRAY"; case 0.50..<0.67: "DUSK"
        case 0.67..<0.83: "SHADOW"; default: "ONYX"
        }
    }
}

#Preview { HourglassView(onPickerTap: {}) }
#endif
