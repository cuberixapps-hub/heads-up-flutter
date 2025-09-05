import Foundation
import AVFoundation
import UIKit
import CoreImage

class VideoComposerV2: NSObject {
    
    static func composeVideo(
        reactionVideoPath: String,
        gameFramePaths: [String],
        outputPath: String,
        pipWidth: Int,
        pipHeight: Int,
        pipX: Int,
        pipY: Int,
        fps: Int,
        duration: Int,
        progressHandler: @escaping (Double) -> Void,
        completion: @escaping (Bool, String?) -> Void
    ) {
        print("VideoComposerV2: Starting composition")
        print("Reaction video: \(reactionVideoPath)")
        print("Game frames: \(gameFramePaths.count)")
        print("Output: \(outputPath)")
        
        let reactionURL = URL(fileURLWithPath: reactionVideoPath)
        let outputURL = URL(fileURLWithPath: outputPath)
        
        // Load reaction video asset
        let reactionAsset = AVAsset(url: reactionURL)
        
        guard let reactionVideoTrack = reactionAsset.tracks(withMediaType: .video).first else {
            completion(false, "Failed to load video track")
            return
        }
        
        // Create composition
        let composition = AVMutableComposition()
        
        // Add reaction video track
        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            completion(false, "Failed to create video track")
            return
        }
        
        // Add reaction audio track if available
        var compositionAudioTrack: AVMutableCompositionTrack?
        if let reactionAudioTrack = reactionAsset.tracks(withMediaType: .audio).first {
            compositionAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
        }
        
        // Insert tracks
        let videoDuration = reactionAsset.duration
        do {
            try compositionVideoTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: videoDuration),
                of: reactionVideoTrack,
                at: .zero
            )
            
            if let audioTrack = compositionAudioTrack,
               let reactionAudioTrack = reactionAsset.tracks(withMediaType: .audio).first {
                try audioTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: videoDuration),
                    of: reactionAudioTrack,
                    at: .zero
                )
            }
        } catch {
            completion(false, "Failed to insert tracks: \(error)")
            return
        }
        
        // Get video size
        let videoSize = reactionVideoTrack.naturalSize.applying(reactionVideoTrack.preferredTransform)
        let actualVideoSize = CGSize(
            width: abs(videoSize.width),
            height: abs(videoSize.height)
        )
        
        print("Video size: \(actualVideoSize)")
        
        // Create video composition with custom compositor
        let videoComposition = AVMutableVideoComposition()
        videoComposition.frameDuration = CMTime(value: 1, timescale: Int32(fps))
        videoComposition.renderSize = actualVideoSize
        
        // Create custom compositor class
        videoComposition.customVideoCompositorClass = PiPCompositor.self
        
        // Store frame data in user info
        videoComposition.sourceTrackIDForFrameTiming = compositionVideoTrack.trackID
        
        // Create instruction
        let instruction = PiPCompositionInstruction(
            gameFramePaths: gameFramePaths,
            pipRect: CGRect(
                x: Int(actualVideoSize.width) - pipWidth - pipX,
                y: Int(actualVideoSize.height) - pipHeight - pipY,
                width: pipWidth,
                height: pipHeight
            ),
            fps: fps,
            timeRange: CMTimeRange(start: .zero, duration: videoDuration),
            trackID: compositionVideoTrack.trackID
        )
        
        videoComposition.instructions = [instruction]
        
        // Export
        guard let export = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            completion(false, "Failed to create export session")
            return
        }
        
        export.outputURL = outputURL
        export.outputFileType = .mp4
        export.videoComposition = videoComposition
        
        // Progress monitoring
        let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            progressHandler(Double(export.progress))
        }
        
        export.exportAsynchronously {
            progressTimer.invalidate()
            
            switch export.status {
            case .completed:
                print("Export completed successfully")
                completion(true, outputPath)
            case .failed:
                print("Export failed: \(export.error?.localizedDescription ?? "Unknown error")")
                completion(false, export.error?.localizedDescription ?? "Unknown error")
            case .cancelled:
                completion(false, "Export cancelled")
            default:
                completion(false, "Export failed with status: \(export.status)")
            }
        }
    }
}

// Custom instruction class
class PiPCompositionInstruction: AVMutableVideoCompositionInstruction {
    let gameFramePaths: [String]
    let pipRect: CGRect
    let fps: Int
    private let _passthroughTrackID: CMPersistentTrackID
    private let _requiredSourceTrackIDs: [NSValue]
    
    override var passthroughTrackID: CMPersistentTrackID {
        get { return _passthroughTrackID }
        set { }
    }
    
    override var requiredSourceTrackIDs: [NSValue] {
        get { return _requiredSourceTrackIDs }
        set { }
    }
    
    override var containsTweening: Bool {
        return true
    }
    
    init(gameFramePaths: [String], pipRect: CGRect, fps: Int, timeRange: CMTimeRange, trackID: CMPersistentTrackID) {
        self.gameFramePaths = gameFramePaths
        self.pipRect = pipRect
        self.fps = fps
        self._passthroughTrackID = trackID
        self._requiredSourceTrackIDs = [NSNumber(value: trackID)]
        super.init()
        self.timeRange = timeRange
        self.enablePostProcessing = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// Custom compositor class
class PiPCompositor: NSObject, AVVideoCompositing {
    private var renderContext: AVVideoCompositionRenderContext?
    private var gameFrameCache: [Int: UIImage] = [:]
    private let ciContext = CIContext()
    
    var sourcePixelBufferAttributes: [String : Any]? {
        return [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferOpenGLESCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
    }
    
    var requiredPixelBufferAttributesForRenderContext: [String : Any] {
        return [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferOpenGLESCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
    }
    
    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {
        renderContext = newRenderContext
    }
    
    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        guard let instruction = request.videoCompositionInstruction as? PiPCompositionInstruction else {
            request.finish(with: NSError(domain: "PiPCompositor", code: 1, userInfo: nil))
            return
        }
        
        // Get source frame
        guard let sourceFrame = request.sourceFrame(byTrackID: request.sourceTrackIDs[0].int32Value) else {
            request.finish(with: NSError(domain: "PiPCompositor", code: 2, userInfo: nil))
            return
        }
        
        // Create output pixel buffer
        guard let pixelBuffer = renderContext?.newPixelBuffer() else {
            request.finish(with: NSError(domain: "PiPCompositor", code: 3, userInfo: nil))
            return
        }
        
        // Calculate current frame index
        let currentTime = request.compositionTime
        let frameIndex = Int(currentTime.seconds * Double(instruction.fps)) % instruction.gameFramePaths.count
        
        // Get or load game frame
        let gameImage: UIImage
        if let cachedImage = gameFrameCache[frameIndex] {
            gameImage = cachedImage
        } else if frameIndex < instruction.gameFramePaths.count {
            let framePath = instruction.gameFramePaths[frameIndex]
            if let loadedImage = UIImage(contentsOfFile: framePath) {
                gameImage = loadedImage
                gameFrameCache[frameIndex] = loadedImage
            } else {
                print("Failed to load frame at index \(frameIndex): \(framePath)")
                // Use placeholder
                gameImage = createPlaceholderImage(size: CGSize(width: instruction.pipRect.width, height: instruction.pipRect.height))
            }
        } else {
            gameImage = createPlaceholderImage(size: CGSize(width: instruction.pipRect.width, height: instruction.pipRect.height))
        }
        
        // Convert source frame to CIImage
        let sourceImage = CIImage(cvPixelBuffer: sourceFrame)
        
        // Create PiP overlay
        guard let pipOverlay = createPiPOverlay(gameImage: gameImage, pipRect: instruction.pipRect) else {
            request.finish(with: NSError(domain: "PiPCompositor", code: 4, userInfo: nil))
            return
        }
        
        // Composite images
        let compositeImage = pipOverlay.composited(over: sourceImage)
        
        // Render to pixel buffer
        ciContext.render(compositeImage, to: pixelBuffer)
        
        // Finish request
        request.finish(withComposedVideoFrame: pixelBuffer)
    }
    
    private func createPiPOverlay(gameImage: UIImage, pipRect: CGRect) -> CIImage? {
        // Create a graphics context for the PiP
        UIGraphicsBeginImageContextWithOptions(pipRect.size, false, 0)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        // Draw rounded rect background
        context.setFillColor(UIColor.black.cgColor)
        let path = UIBezierPath(roundedRect: CGRect(origin: .zero, size: pipRect.size), cornerRadius: 12)
        path.fill()
        
        // Draw the game image
        gameImage.draw(in: CGRect(origin: .zero, size: pipRect.size))
        
        // Add border
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(2)
        path.stroke()
        
        // Get the resulting image
        guard let pipImage = UIGraphicsGetImageFromCurrentImageContext(),
              let cgImage = pipImage.cgImage else { return nil }
        
        // Convert to CIImage and position it
        var ciImage = CIImage(cgImage: cgImage)
        ciImage = ciImage.transformed(by: CGAffineTransform(translationX: pipRect.origin.x, y: pipRect.origin.y))
        
        return ciImage
    }
    
    private func createPlaceholderImage(size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        
        UIColor.darkGray.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }
    
    func cancelAllPendingVideoCompositionRequests() {
        // Clean up
        gameFrameCache.removeAll()
    }
}
