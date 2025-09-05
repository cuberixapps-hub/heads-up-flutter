import Foundation
import AVFoundation
import UIKit

class VideoComposer: NSObject {
    
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
        let reactionURL = URL(fileURLWithPath: reactionVideoPath)
        let outputURL = URL(fileURLWithPath: outputPath)
        
        // Load reaction video asset
        let reactionAsset = AVAsset(url: reactionURL)
        
        guard let reactionVideoTrack = reactionAsset.tracks(withMediaType: .video).first,
              let reactionAudioTrack = reactionAsset.tracks(withMediaType: .audio).first else {
            completion(false, "Failed to load video tracks")
            return
        }
        
        // Create composition
        let composition = AVMutableComposition()
        let videoComposition = AVMutableVideoComposition()
        
        // Add reaction video track
        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            completion(false, "Failed to create video track")
            return
        }
        
        // Add reaction audio track
        guard let compositionAudioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            completion(false, "Failed to create audio track")
            return
        }
        
        do {
            let timeRange = CMTimeRange(start: .zero, duration: reactionAsset.duration)
            try compositionVideoTrack.insertTimeRange(timeRange, of: reactionVideoTrack, at: .zero)
            try compositionAudioTrack.insertTimeRange(timeRange, of: reactionAudioTrack, at: .zero)
        } catch {
            completion(false, "Failed to insert tracks: \(error)")
            return
        }
        
        // Get video size
        let videoSize = reactionVideoTrack.naturalSize
        
        // Create video composition instruction
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)
        
        // Create layer instruction for reaction video
        let reactionLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)
        instruction.layerInstructions = [reactionLayerInstruction]
        
        // Set up video composition
        videoComposition.instructions = [instruction]
        videoComposition.frameDuration = CMTime(value: 1, timescale: Int32(fps))
        videoComposition.renderSize = videoSize
        
        // Create PiP overlay animation
        videoComposition.animationTool = createPiPAnimationTool(
            videoSize: videoSize,
            gameFramePaths: gameFramePaths,
            pipRect: CGRect(x: Int(videoSize.width) - pipWidth - pipX,
                          y: Int(videoSize.height) - pipHeight - pipY,
                          width: pipWidth,
                          height: pipHeight),
            fps: fps
        )
        
        // Export
        guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
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
                completion(true, outputPath)
            case .failed:
                completion(false, export.error?.localizedDescription ?? "Unknown error")
            case .cancelled:
                completion(false, "Export cancelled")
            default:
                completion(false, "Export failed with status: \(export.status)")
            }
        }
    }
    
    private static func createPiPAnimationTool(
        videoSize: CGSize,
        gameFramePaths: [String],
        pipRect: CGRect,
        fps: Int
    ) -> AVVideoCompositionCoreAnimationTool {
        print("Creating PiP animation with \(gameFramePaths.count) frames")
        print("PiP rect: \(pipRect)")
        print("FPS: \(fps)")
        
        // Create parent layer
        let parentLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: videoSize)
        
        // Create video layer
        let videoLayer = CALayer()
        videoLayer.frame = CGRect(origin: .zero, size: videoSize)
        parentLayer.addSublayer(videoLayer)
        
        // Create PiP container layer with border for debugging
        let pipContainer = CALayer()
        pipContainer.frame = pipRect
        pipContainer.backgroundColor = UIColor.black.cgColor
        pipContainer.cornerRadius = 12
        pipContainer.masksToBounds = true
        pipContainer.borderColor = UIColor.white.cgColor
        pipContainer.borderWidth = 2
        
        // Add shadow
        let shadowLayer = CALayer()
        shadowLayer.frame = pipRect
        shadowLayer.backgroundColor = UIColor.black.cgColor
        shadowLayer.cornerRadius = 12
        shadowLayer.shadowColor = UIColor.black.cgColor
        shadowLayer.shadowOpacity = 0.5
        shadowLayer.shadowOffset = CGSize(width: 0, height: 4)
        shadowLayer.shadowRadius = 10
        parentLayer.addSublayer(shadowLayer)
        
        // Load all frame images first
        var frameImages: [CGImage] = []
        for (index, path) in gameFramePaths.enumerated() {
            if let image = UIImage(contentsOfFile: path) {
                if let cgImage = image.cgImage {
                    frameImages.append(cgImage)
                    print("Loaded frame \(index): \(path)")
                } else {
                    print("Failed to get CGImage for frame \(index): \(path)")
                }
            } else {
                print("Failed to load image at path: \(path)")
            }
        }
        
        print("Successfully loaded \(frameImages.count) frames")
        
        // Create animated layer for game frames
        let gameLayer = CALayer()
        gameLayer.frame = pipContainer.bounds
        gameLayer.contentsGravity = .resizeAspectFill
        gameLayer.backgroundColor = UIColor.darkGray.cgColor // Debug background
        
        // Set initial frame
        if !frameImages.isEmpty {
            gameLayer.contents = frameImages[0]
            
            // Create frame animation
            let animation = CAKeyframeAnimation(keyPath: "contents")
            animation.values = frameImages
            animation.duration = Double(gameFramePaths.count) / Double(fps)
            animation.repeatCount = .infinity
            animation.calculationMode = .discrete
            animation.isRemovedOnCompletion = false
            animation.fillMode = .both
            animation.beginTime = AVCoreAnimationBeginTimeAtZero
            
            gameLayer.add(animation, forKey: "frameAnimation")
            print("Added animation with duration: \(animation.duration)s")
        } else {
            print("No frames loaded - PiP will be empty")
        }
        
        pipContainer.addSublayer(gameLayer)
        parentLayer.addSublayer(pipContainer)
        
        return AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: parentLayer
        )
    }
}
