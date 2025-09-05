import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    
    // Video composer channel
    let videoComposerChannel = FlutterMethodChannel(
      name: "com.headsup.video_composer",
      binaryMessenger: controller.binaryMessenger
    )
    
    // Progress event channel
    let progressChannel = FlutterEventChannel(
      name: "com.headsup.video_composer/progress",
      binaryMessenger: controller.binaryMessenger
    )
    
    var progressSink: FlutterEventSink?
    
    progressChannel.setStreamHandler(ProgressStreamHandler { sink in
      progressSink = sink
    })
    
    videoComposerChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      if call.method == "composeVideo" {
        guard let args = call.arguments as? [String: Any],
              let reactionVideoPath = args["reactionVideoPath"] as? String,
              let gameFramePaths = args["gameFramePaths"] as? [String],
              let outputPath = args["outputPath"] as? String,
              let pipWidth = args["pipWidth"] as? Int,
              let pipHeight = args["pipHeight"] as? Int,
              let pipX = args["pipX"] as? Int,
              let pipY = args["pipY"] as? Int,
              let fps = args["fps"] as? Int,
              let duration = args["duration"] as? Int else {
          result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing required arguments", details: nil))
          return
        }
        
        SimpleVideoComposer.composeVideo(
          reactionVideoPath: reactionVideoPath,
          gameFramePaths: gameFramePaths,
          outputPath: outputPath,
          pipWidth: pipWidth,
          pipHeight: pipHeight,
          pipX: pipX,
          pipY: pipY,
          fps: fps,
          duration: duration,
          progressHandler: { progress in
            progressSink?(progress)
          },
          completion: { success, path in
            if success {
              result(path)
            } else {
              result(FlutterError(code: "COMPOSITION_FAILED", message: path ?? "Unknown error", details: nil))
            }
          }
        )
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

class ProgressStreamHandler: NSObject, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?
  private let onListenCallback: (@escaping FlutterEventSink) -> Void
  
  init(onListen: @escaping (@escaping FlutterEventSink) -> Void) {
    self.onListenCallback = onListen
  }
  
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = events
    onListenCallback(events)
    return nil
  }
  
  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
}
