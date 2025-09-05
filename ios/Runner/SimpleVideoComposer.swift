import Foundation
import AVFoundation
import UIKit

class SimpleVideoComposer: NSObject {
    
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
        print("SimpleVideoComposer: Starting composition")
        print("Reaction video: \(reactionVideoPath)")
        print("Game frames count: \(gameFramePaths.count)")
        print("PiP dimensions: \(pipWidth)x\(pipHeight) at (\(pipX), \(pipY))")
        
        // First, create a video from the game frames
        createVideoFromFrames(
            framePaths: gameFramePaths,
            fps: fps,
            outputSize: CGSize(width: pipWidth, height: pipHeight)
        ) { frameVideoPath in
            guard let frameVideoPath = frameVideoPath else {
                completion(false, "Failed to create frame video")
                return
            }
            
            print("Created frame video at: \(frameVideoPath)")
            
            // Now overlay the frame video on the reaction video
            overlayVideos(
                mainVideoPath: reactionVideoPath,
                overlayVideoPath: frameVideoPath,
                outputPath: outputPath,
                pipRect: CGRect(x: pipX, y: pipY, width: pipWidth, height: pipHeight),
                progressHandler: progressHandler,
                completion: completion
            )
        }
    }
    
    private static func createVideoFromFrames(
        framePaths: [String],
        fps: Int,
        outputSize: CGSize,
        completion: @escaping (String?) -> Void
    ) {
        let tempPath = NSTemporaryDirectory() + "frames_\(UUID().uuidString).mp4"
        let outputURL = URL(fileURLWithPath: tempPath)
        
        // Remove any existing file
        try? FileManager.default.removeItem(at: outputURL)
        
        // Create AVAssetWriter
        guard let writer = try? AVAssetWriter(outputURL: outputURL, fileType: .mp4) else {
            print("Failed to create AVAssetWriter")
            completion(nil)
            return
        }
        
        // Configure video settings
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: outputSize.width,
            AVVideoHeightKey: outputSize.height
        ]
        
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        writerInput.expectsMediaDataInRealTime = false
        
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: outputSize.width,
            kCVPixelBufferHeightKey as String: outputSize.height
        ]
        
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: pixelBufferAttributes
        )
        
        writer.add(writerInput)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        
        // Process frames
        let frameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
        var frameCount = 0
        
        let queue = DispatchQueue(label: "framewriter")
        writerInput.requestMediaDataWhenReady(on: queue) {
            while writerInput.isReadyForMoreMediaData && frameCount < framePaths.count {
                let framePath = framePaths[frameCount]
                
                autoreleasepool {
                    if let image = UIImage(contentsOfFile: framePath),
                       let pixelBuffer = self.pixelBuffer(from: image, size: outputSize) {
                        let presentationTime = CMTime(value: Int64(frameCount), timescale: CMTimeScale(fps))
                        adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                        print("Added frame \(frameCount) at time \(presentationTime.seconds)s")
                    } else {
                        print("Failed to process frame \(frameCount): \(framePath)")
                    }
                }
                
                frameCount += 1
            }
            
            if frameCount >= framePaths.count {
                writerInput.markAsFinished()
                writer.finishWriting {
                    if writer.status == .completed {
                        print("Frame video created successfully")
                        completion(tempPath)
                    } else {
                        print("Failed to create frame video: \(writer.error?.localizedDescription ?? "Unknown error")")
                        completion(nil)
                    }
                }
            }
        }
    }
    
    private static func pixelBuffer(from image: UIImage, size: CGSize) -> CVPixelBuffer? {
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!
        ] as CFDictionary
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32BGRA,
            attrs,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        let pixelData = CVPixelBufferGetBaseAddress(buffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(
            data: pixelData,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else {
            return nil
        }
        
        // Fill with black background
        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        // Draw the image correctly oriented
        // Core Graphics has inverted Y axis, so we need to flip it
        context.saveGState()
        
        // Move to bottom-left corner and flip vertically
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        
        if let cgImage = image.cgImage {
            context.draw(cgImage, in: CGRect(origin: .zero, size: size))
        }
        
        context.restoreGState()
        
        return buffer
    }
    
    private static func overlayVideos(
        mainVideoPath: String,
        overlayVideoPath: String,
        outputPath: String,
        pipRect: CGRect,
        progressHandler: @escaping (Double) -> Void,
        completion: @escaping (Bool, String?) -> Void
    ) {
        let mainURL = URL(fileURLWithPath: mainVideoPath)
        let overlayURL = URL(fileURLWithPath: overlayVideoPath)
        let outputURL = URL(fileURLWithPath: outputPath)
        
        // Load assets
        let mainAsset = AVAsset(url: mainURL)
        let overlayAsset = AVAsset(url: overlayURL)
        
        // Create composition
        let composition = AVMutableComposition()
        
        guard let mainVideoTrack = mainAsset.tracks(withMediaType: .video).first,
              let overlayVideoTrack = overlayAsset.tracks(withMediaType: .video).first else {
            completion(false, "Failed to load video tracks")
            return
        }
        
        // Add main video track
        guard let compositionMainTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            completion(false, "Failed to create main track")
            return
        }
        
        // Add overlay video track
        guard let compositionOverlayTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            completion(false, "Failed to create overlay track")
            return
        }
        
        // Add audio track if available
        var compositionAudioTrack: AVMutableCompositionTrack?
        if let mainAudioTrack = mainAsset.tracks(withMediaType: .audio).first {
            compositionAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
        }
        
        // Insert tracks
        let duration = mainAsset.duration
        do {
            try compositionMainTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: duration),
                of: mainVideoTrack,
                at: .zero
            )
            
            // Loop overlay video if needed
            var currentTime = CMTime.zero
            while currentTime < duration {
                let remainingTime = duration - currentTime
                let insertDuration = min(overlayAsset.duration, remainingTime)
                
                try compositionOverlayTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: insertDuration),
                    of: overlayVideoTrack,
                    at: currentTime
                )
                
                currentTime = currentTime + insertDuration
            }
            
            if let audioTrack = compositionAudioTrack,
               let mainAudioTrack = mainAsset.tracks(withMediaType: .audio).first {
                try audioTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: duration),
                    of: mainAudioTrack,
                    at: .zero
                )
            }
        } catch {
            completion(false, "Failed to insert tracks: \(error)")
            return
        }
        
        // Get video size
        let videoSize = mainVideoTrack.naturalSize.applying(mainVideoTrack.preferredTransform)
        let actualVideoSize = CGSize(width: abs(videoSize.width), height: abs(videoSize.height))
        
        // Create video composition
        let videoComposition = AVMutableVideoComposition()
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.renderSize = actualVideoSize
        
        // Create layer instructions
        let mainInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionMainTrack)
        
        let overlayInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionOverlayTrack)
        
        // Calculate PiP position (from bottom-right)
        let pipX = actualVideoSize.width - pipRect.width - pipRect.origin.x
        let pipY = actualVideoSize.height - pipRect.height - pipRect.origin.y
        
        // Scale and position overlay
        var transform = CGAffineTransform.identity
        transform = transform.translatedBy(x: pipX, y: pipY)
        transform = transform.scaledBy(
            x: pipRect.width / overlayVideoTrack.naturalSize.width,
            y: pipRect.height / overlayVideoTrack.naturalSize.height
        )
        overlayInstruction.setTransform(transform, at: .zero)
        
        // Create main instruction
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: duration)
        instruction.layerInstructions = [overlayInstruction, mainInstruction]
        
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
            
            // Clean up temp frame video
            try? FileManager.default.removeItem(atPath: overlayVideoPath)
            
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
