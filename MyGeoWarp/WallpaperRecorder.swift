import AVFoundation
import Combine
import CoreMedia
import Photos
import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - WallpaperFrame (ImageRenderer用ラッパー)

struct WallpaperFrame: View {
    var t: Double  // ImageRenderer から直接変更するため var
    let warp: Double
    let chaos: Double
    let tempo: Double
    let colorStyle: Double
    let pools: ParticlePools
    let size: CGSize

    var body: some View {
        GeoWarpCanvas(t: t, warp: warp, chaos: chaos,
                      tempo: tempo, colorStyle: colorStyle, pools: pools)
            .frame(width: size.width, height: size.height)
    }
}

// MARK: - WallpaperRecorder

final class WallpaperRecorder: ObservableObject {

    enum State: Equatable {
        case idle
        case rendering(Double)
        case saving
        case done
        case failed(String)

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.saving, .saving), (.done, .done): true
            case (.rendering(let a), .rendering(let b)): a == b
            case (.failed(let a), .failed(let b)): a == b
            default: false
            }
        }
    }

    @Published var state: State = .idle

    var isActive: Bool {
        switch state {
        case .idle, .done, .failed: false
        default: true
        }
    }

    var statusText: String {
        switch state {
        case .idle:               ""
        case .rendering(let p):   "Rendering... \(Int(p * 100))%\n~\(remainingSeconds)s remaining"
        case .saving:             "Saving to Camera Roll..."
        case .done:               "Saved\nSet as wallpaper in Photos"
        case .failed(let msg):    "Save failed:\n\(msg)"
        }
    }

    private let duration: Double = 30.0
    private let fps: Int = 24
    private var estimatedTotalSec: Double = 120
    private var startTime: Date = Date()

    private var remainingSeconds: Int {
        if case .rendering(let p) = state, p > 0 {
            let elapsed = Date().timeIntervalSince(startTime)
            let total = elapsed / p
            return max(0, Int(total * (1 - p)))
        }
        return 0
    }

    // MARK: - Start (COSMOS)

    func start(warp: Double, chaos: Double, tempo: Double,
               colorStyle: Double, pools: ParticlePools) async {
        let screenSize = windowSize()

        // 録画前に写真ライブラリの権限を確認
        let authStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        print("[GeoWarp] Auth status: \(authStatus.rawValue)")
        guard authStatus == .authorized || authStatus == .limited else {
            state = .failed("Photos access denied\nGo to Settings > Privacy > Photos to allow access\n(status: \(authStatus.rawValue))")
            try? await Task.sleep(for: .seconds(10))
            state = .idle
            return
        }

        startTime = Date()
        state = .rendering(0)

        do {
            let (videoURL, stillImage, contentID) = try await renderVideo(
                warp: warp, chaos: chaos, tempo: tempo,
                colorStyle: colorStyle, pools: pools, screenSize: screenSize
            )

            state = .saving
            try await saveLivePhoto(videoURL: videoURL, stillImage: stillImage, contentIdentifier: contentID)
            state = .done

            if let photosURL = URL(string: "photos-redirect://") {
                await UIApplication.shared.open(photosURL)
            }

            try? await Task.sleep(for: .seconds(3))
            state = .idle

        } catch {
            state = .failed(error.localizedDescription)
            try? await Task.sleep(for: .seconds(15))
            state = .idle
        }
    }

    // MARK: - Start (AURORA)

    func startAurora(speed: Double, spread: Double, colorParam: Double, startT: Double = 0) async {
        let screenSize = windowSize()

        let authStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard authStatus == .authorized || authStatus == .limited else {
            state = .failed("Photos access denied\nGo to Settings > Privacy > Photos to allow access\n(status: \(authStatus.rawValue))")
            try? await Task.sleep(for: .seconds(10))
            state = .idle
            return
        }

        startTime = Date()
        state = .rendering(0)

        do {
            let (videoURL, stillImage, contentID) = try await renderAuroraVideo(
                speed: speed, spread: spread, colorParam: colorParam, screenSize: screenSize, startT: startT
            )
            state = .saving
            try await saveLivePhoto(videoURL: videoURL, stillImage: stillImage, contentIdentifier: contentID)
            state = .done

            if let photosURL = URL(string: "photos-redirect://") {
                await UIApplication.shared.open(photosURL)
            }
            try? await Task.sleep(for: .seconds(3))
            state = .idle
        } catch {
            state = .failed(error.localizedDescription)
            try? await Task.sleep(for: .seconds(15))
            state = .idle
        }
    }

    // MARK: - Start (CRYSTAL)

    func startCrystal(spin: Double, gravity: Double, stillSnapshot: CGImage? = nil) async {
        let screenSize = windowSize()

        let authStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard authStatus == .authorized || authStatus == .limited else {
            state = .failed("Photos access denied\nGo to Settings > Privacy > Photos to allow access\n(status: \(authStatus.rawValue))")
            try? await Task.sleep(for: .seconds(10))
            state = .idle
            return
        }

        startTime = Date()
        state = .rendering(0)

        do {
            let (videoURL, stillImage, contentID) = try await renderCrystalVideo(
                spin: spin, gravity: gravity, screenSize: screenSize, stillSnapshot: stillSnapshot
            )
            state = .saving
            try await saveLivePhoto(videoURL: videoURL, stillImage: stillImage, contentIdentifier: contentID)
            state = .done

            if let photosURL = URL(string: "photos-redirect://") {
                await UIApplication.shared.open(photosURL)
            }
            try? await Task.sleep(for: .seconds(3))
            state = .idle
        } catch {
            state = .failed(error.localizedDescription)
            try? await Task.sleep(for: .seconds(15))
            state = .idle
        }
    }

    // MARK: - Render Video (CRYSTAL)

    private func renderCrystalVideo(
        spin: Double, gravity: Double, screenSize: CGSize, stillSnapshot: CGImage? = nil
    ) async throws -> (URL, CGImage, String) {
        let totalFrames = Int(duration) * fps
        let renderScale: CGFloat = 2.0
        let videoSize = CGSize(width: screenSize.width * renderScale,
                               height: screenSize.height * renderScale)

        let videoURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("crystal_\(UUID().uuidString).mov")

        let writer = try AVAssetWriter(outputURL: videoURL, fileType: .mov)

        let videoInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey:  AVVideoCodecType.h264,
                AVVideoWidthKey:  Int(videoSize.width),
                AVVideoHeightKey: Int(videoSize.height),
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 8_000_000,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                ] as [String: Any],
            ]
        )
        videoInput.expectsMediaDataInRealTime = false

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey  as String: Int(videoSize.width),
                kCVPixelBufferHeightKey as String: Int(videoSize.height),
            ]
        )

        let contentIdentifier = UUID().uuidString
        let idItem = AVMutableMetadataItem()
        idItem.identifier = AVMetadataIdentifier(rawValue: "mdta/com.apple.quicktime.content.identifier")
        idItem.value      = contentIdentifier as NSString
        idItem.dataType   = "com.apple.metadata.datatype.UTF-8"
        writer.metadata   = [idItem]

        let stillItem = AVMutableMetadataItem()
        stillItem.identifier = AVMetadataIdentifier(rawValue: "mdta/com.apple.quicktime.still-image-time")
        stillItem.value      = NSNumber(value: 0)
        stillItem.dataType   = "com.apple.metadata.datatype.int8"

        let specs: [[String: Any]] = [[
            kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier as String:
                "mdta/com.apple.quicktime.still-image-time",
            kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType as String:
                "com.apple.metadata.datatype.int8",
        ]]
        var metaDesc: CMFormatDescription?
        CMMetadataFormatDescriptionCreateWithMetadataSpecifications(
            allocator: kCFAllocatorDefault,
            metadataType: kCMMetadataFormatType_Boxed,
            metadataSpecifications: specs as CFArray,
            formatDescriptionOut: &metaDesc
        )
        let metaInput   = AVAssetWriterInput(mediaType: .metadata, outputSettings: nil, sourceFormatHint: metaDesc)
        let metaAdaptor = AVAssetWriterInputMetadataAdaptor(assetWriterInput: metaInput)

        writer.add(videoInput)
        writer.add(metaInput)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        metaAdaptor.append(AVTimedMetadataGroup(
            items: [stillItem],
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 1, timescale: CMTimeScale(fps)))
        ))

        let initialFrame = CrystalFrame(t: 0, spin: spin, gravity: gravity, size: screenSize)
        let renderer = ImageRenderer(content: initialFrame)
        renderer.scale = renderScale

        var firstFrame: CGImage? = stillSnapshot

        for i in 0..<totalFrames {
            renderer.content.t = Double(i) / Double(fps)

            guard let cgImage = renderer.cgImage,
                  let buffer  = makePixelBuffer(from: cgImage, size: videoSize) else { continue }

            if i == 0 && firstFrame == nil { firstFrame = cgImage }

            let pts = CMTime(value: CMTimeValue(i), timescale: CMTimeScale(fps))
            while !adaptor.assetWriterInput.isReadyForMoreMediaData { await Task.yield() }
            adaptor.append(buffer, withPresentationTime: pts)

            if i % 12 == 0 {
                state = .rendering(Double(i) / Double(totalFrames))
                await Task.yield()
            }
        }

        state = .rendering(1.0)
        videoInput.markAsFinished()
        metaInput.markAsFinished()

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            writer.finishWriting { cont.resume() }
        }

        guard writer.status == .completed else {
            throw WallpaperError.renderFailed(writer.error?.localizedDescription ?? "Unknown error")
        }
        guard let still = firstFrame else {
            throw WallpaperError.renderFailed("Failed to capture first frame")
        }
        return (videoURL, still, contentIdentifier)
    }

    // MARK: - Render Video (AURORA)

    private func renderAuroraVideo(
        speed: Double, spread: Double, colorParam: Double, screenSize: CGSize, startT: Double = 0
    ) async throws -> (URL, CGImage, String) {
        let totalFrames = Int(duration) * fps
        let renderScale: CGFloat = 2.0
        let videoSize = CGSize(
            width:  screenSize.width  * renderScale,
            height: screenSize.height * renderScale
        )

        let videoURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("aurora_\(UUID().uuidString).mov")

        let writer = try AVAssetWriter(outputURL: videoURL, fileType: .mov)

        let videoInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey:  AVVideoCodecType.h264,
                AVVideoWidthKey:  Int(videoSize.width),
                AVVideoHeightKey: Int(videoSize.height),
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 8_000_000,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                ] as [String: Any],
            ]
        )
        videoInput.expectsMediaDataInRealTime = false

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey  as String: Int(videoSize.width),
                kCVPixelBufferHeightKey as String: Int(videoSize.height),
            ]
        )

        let contentIdentifier = UUID().uuidString
        let idItem = AVMutableMetadataItem()
        idItem.identifier = AVMetadataIdentifier(rawValue: "mdta/com.apple.quicktime.content.identifier")
        idItem.value      = contentIdentifier as NSString
        idItem.dataType   = "com.apple.metadata.datatype.UTF-8"
        writer.metadata = [idItem]

        let stillItem = AVMutableMetadataItem()
        stillItem.identifier = AVMetadataIdentifier(rawValue: "mdta/com.apple.quicktime.still-image-time")
        stillItem.value      = NSNumber(value: 0)
        stillItem.dataType   = "com.apple.metadata.datatype.int8"

        let specs: [[String: Any]] = [[
            kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier as String:
                "mdta/com.apple.quicktime.still-image-time",
            kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType as String:
                "com.apple.metadata.datatype.int8",
        ]]
        var metaDesc: CMFormatDescription?
        CMMetadataFormatDescriptionCreateWithMetadataSpecifications(
            allocator: kCFAllocatorDefault,
            metadataType: kCMMetadataFormatType_Boxed,
            metadataSpecifications: specs as CFArray,
            formatDescriptionOut: &metaDesc
        )
        let metaInput   = AVAssetWriterInput(mediaType: .metadata, outputSettings: nil, sourceFormatHint: metaDesc)
        let metaAdaptor = AVAssetWriterInputMetadataAdaptor(assetWriterInput: metaInput)

        writer.add(videoInput)
        writer.add(metaInput)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        metaAdaptor.append(AVTimedMetadataGroup(
            items: [stillItem],
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 1, timescale: CMTimeScale(fps)))
        ))

        let initialFrame = AuroraFrame(
            t: startT, speed: speed, spread: spread, colorParam: colorParam, size: screenSize
        )
        let renderer = ImageRenderer(content: initialFrame)
        renderer.scale = renderScale

        var firstFrame: CGImage?

        for i in 0..<totalFrames {
            renderer.content.t = startT + Double(i) / Double(fps)

            guard let cgImage = renderer.cgImage,
                  let buffer  = makePixelBuffer(from: cgImage, size: videoSize) else { continue }

            if i == 0 { firstFrame = cgImage }

            let pts = CMTime(value: CMTimeValue(i), timescale: CMTimeScale(fps))
            while !adaptor.assetWriterInput.isReadyForMoreMediaData {
                await Task.yield()
            }
            adaptor.append(buffer, withPresentationTime: pts)

            if i % 12 == 0 {
                state = .rendering(Double(i) / Double(totalFrames))
                await Task.yield()
            }
        }

        state = .rendering(1.0)
        videoInput.markAsFinished()
        metaInput.markAsFinished()

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            writer.finishWriting { cont.resume() }
        }

        guard writer.status == .completed else {
            throw WallpaperError.renderFailed(writer.error?.localizedDescription ?? "Unknown error")
        }
        guard let still = firstFrame else {
            throw WallpaperError.renderFailed("Failed to capture first frame")
        }
        return (videoURL, still, contentIdentifier)
    }

    // MARK: - Render Video (COSMOS)

    private func renderVideo(
        warp: Double, chaos: Double, tempo: Double, colorStyle: Double,
        pools: ParticlePools, screenSize: CGSize
    ) async throws -> (URL, CGImage, String) {

        let totalFrames = Int(duration) * fps
        let renderScale: CGFloat = 2.0
        let videoSize = CGSize(
            width:  screenSize.width  * renderScale,
            height: screenSize.height * renderScale
        )

        let videoURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("geowarp_\(UUID().uuidString).mov")

        let writer = try AVAssetWriter(outputURL: videoURL, fileType: .mov)

        let videoInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey:  AVVideoCodecType.h264,
                AVVideoWidthKey:  Int(videoSize.width),
                AVVideoHeightKey: Int(videoSize.height),
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 8_000_000,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                ] as [String: Any],
            ]
        )
        videoInput.expectsMediaDataInRealTime = false

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey  as String: Int(videoSize.width),
                kCVPixelBufferHeightKey as String: Int(videoSize.height),
            ]
        )

        let contentIdentifier = UUID().uuidString

        // content.identifier はコンテナレベルに埋め込む
        let idItem = AVMutableMetadataItem()
        idItem.identifier = AVMetadataIdentifier(rawValue: "mdta/com.apple.quicktime.content.identifier")
        idItem.value      = contentIdentifier as NSString
        idItem.dataType   = "com.apple.metadata.datatype.UTF-8"
        writer.metadata = [idItem]

        // still-image-time はタイミングメタデータトラックに埋め込む（iOS が必須とする形式）
        let stillItem = AVMutableMetadataItem()
        stillItem.identifier = AVMetadataIdentifier(rawValue: "mdta/com.apple.quicktime.still-image-time")
        stillItem.value      = NSNumber(value: 0)
        stillItem.dataType   = "com.apple.metadata.datatype.int8"

        let specs: [[String: Any]] = [[
            kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier as String:
                "mdta/com.apple.quicktime.still-image-time",
            kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType as String:
                "com.apple.metadata.datatype.int8",
        ]]
        var metaDesc: CMFormatDescription?
        CMMetadataFormatDescriptionCreateWithMetadataSpecifications(
            allocator: kCFAllocatorDefault,
            metadataType: kCMMetadataFormatType_Boxed,
            metadataSpecifications: specs as CFArray,
            formatDescriptionOut: &metaDesc
        )
        let metaInput   = AVAssetWriterInput(mediaType: .metadata, outputSettings: nil, sourceFormatHint: metaDesc)
        let metaAdaptor = AVAssetWriterInputMetadataAdaptor(assetWriterInput: metaInput)

        writer.add(videoInput)
        writer.add(metaInput)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        // 先頭 1 フレームの区間に still-image-time を書き込む
        metaAdaptor.append(AVTimedMetadataGroup(
            items: [stillItem],
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 1, timescale: CMTimeScale(fps)))
        ))

        // フレームをレンダリング
        let initialFrame = WallpaperFrame(
            t: 0, warp: warp, chaos: chaos, tempo: tempo,
            colorStyle: colorStyle, pools: pools, size: screenSize
        )
        let renderer = ImageRenderer(content: initialFrame)
        renderer.scale = renderScale

        var firstFrame: CGImage?

        for i in 0..<totalFrames {
            renderer.content.t = Double(i) / Double(fps)

            guard let cgImage = renderer.cgImage,
                  let buffer  = makePixelBuffer(from: cgImage, size: videoSize) else { continue }

            if i == 0 { firstFrame = cgImage }

            let pts = CMTime(value: CMTimeValue(i), timescale: CMTimeScale(fps))
            while !adaptor.assetWriterInput.isReadyForMoreMediaData {
                await Task.yield()
            }
            adaptor.append(buffer, withPresentationTime: pts)

            if i % 12 == 0 {
                state = .rendering(Double(i) / Double(totalFrames))
                await Task.yield()
            }
        }

        state = .rendering(1.0)
        videoInput.markAsFinished()
        metaInput.markAsFinished()

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            writer.finishWriting { cont.resume() }
        }

        guard writer.status == .completed else {
            throw WallpaperError.renderFailed(writer.error?.localizedDescription ?? "不明なエラー")
        }
        guard let still = firstFrame else {
            throw WallpaperError.renderFailed("最初のフレームを取得できません")
        }
        return (videoURL, still, contentIdentifier)
    }

    // MARK: - PixelBuffer 変換

    private func makePixelBuffer(from image: CGImage, size: CGSize) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width), Int(size.height),
            kCVPixelFormatType_32BGRA,
            [
                kCVPixelBufferCGImageCompatibilityKey:         true,
                kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            ] as CFDictionary,
            &buffer
        )
        guard status == kCVReturnSuccess, let buffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let ctx = CGContext(
            data:             CVPixelBufferGetBaseAddress(buffer),
            width:            Int(size.width),
            height:           Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow:      CVPixelBufferGetBytesPerRow(buffer),
            space:            CGColorSpaceCreateDeviceRGB(),
            bitmapInfo:       CGImageAlphaInfo.noneSkipFirst.rawValue
                            | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }

        ctx.draw(image, in: CGRect(origin: .zero, size: size))
        return buffer
    }

    // MARK: - Live Photo 保存

    private func saveLivePhoto(videoURL: URL, stillImage: CGImage, contentIdentifier: String) async throws {
        let authStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        print("[GeoWarp] Auth status: \(authStatus.rawValue)")
        guard authStatus == .authorized || authStatus == .limited else {
            throw WallpaperError.noPermission
        }

        let stillURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("geowarp_still_\(UUID().uuidString).jpg")

        guard let dest = CGImageDestinationCreateWithURL(
            stillURL as CFURL, UTType.jpeg.identifier as CFString, 1, nil
        ) else { throw WallpaperError.saveFailed }

        // Live Photo ペアリングに必要: 動画と同じ識別子を JPEG に埋め込む
        let jpegProperties: [String: Any] = [
            kCGImagePropertyMakerAppleDictionary as String: ["17": contentIdentifier]
        ]
        CGImageDestinationAddImage(dest, stillImage, jpegProperties as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { throw WallpaperError.saveFailed }

        let jpegExists = FileManager.default.fileExists(atPath: stillURL.path)
        let videoExists = FileManager.default.fileExists(atPath: videoURL.path)
        print("[GeoWarp] JPEG exists: \(jpegExists), size: \((try? FileManager.default.attributesOfItem(atPath: stillURL.path)[.size] as? Int) ?? 0)")
        print("[GeoWarp] Video exists: \(videoExists), size: \((try? FileManager.default.attributesOfItem(atPath: videoURL.path)[.size] as? Int) ?? 0)")
        print("[GeoWarp] Content ID: \(contentIdentifier)")

        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()

                let photoOpts = PHAssetResourceCreationOptions()
                photoOpts.shouldMoveFile = false
                request.addResource(with: .photo, fileURL: stillURL, options: photoOpts)

                let videoOpts = PHAssetResourceCreationOptions()
                videoOpts.shouldMoveFile = false
                request.addResource(with: .pairedVideo, fileURL: videoURL, options: videoOpts)
            }
        } catch {
            let nsErr = error as NSError
            throw WallpaperError.saveFailedDetail("LivePhoto保存失敗 domain=\(nsErr.domain) code=\(nsErr.code)\n\(nsErr.localizedDescription)")
        }
    }

    // MARK: - Helpers

    private func windowSize() -> CGSize {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.keyWindow?.bounds.size
            ?? CGSize(width: 393, height: 852)
    }

    // MARK: - Error

    enum WallpaperError: LocalizedError {
        case renderFailed(String)
        case noPermission
        case saveFailed
        case saveFailedDetail(String)

        var errorDescription: String? {
            switch self {
            case .renderFailed(let detail):     "Render failed: \(detail)"
            case .noPermission:                 "Photos access denied"
            case .saveFailed:                   "JPEG export failed"
            case .saveFailedDetail(let detail): detail
            }
        }
    }
}
