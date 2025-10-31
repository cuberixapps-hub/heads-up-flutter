package com.cuberix.charades

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import kotlinx.coroutines.*
import com.headsup.VideoComposer

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.headsup.video_composer"
    private val PROGRESS_CHANNEL = "com.headsup.video_composer/progress"
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        var progressSink: EventChannel.EventSink? = null
        
        // Progress event channel
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, PROGRESS_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    progressSink = events
                }
                
                override fun onCancel(arguments: Any?) {
                    progressSink = null
                }
            }
        )
        
        // Method channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "composeVideo" -> {
                    val args = call.arguments as? Map<String, Any>
                    if (args == null) {
                        result.error("INVALID_ARGUMENTS", "Arguments must be a map", null)
                        return@setMethodCallHandler
                    }
                    
                    val reactionVideoPath = args["reactionVideoPath"] as? String
                    val gameFramePaths = args["gameFramePaths"] as? List<String>
                    val outputPath = args["outputPath"] as? String
                    val pipWidth = args["pipWidth"] as? Int
                    val pipHeight = args["pipHeight"] as? Int
                    val pipX = args["pipX"] as? Int
                    val pipY = args["pipY"] as? Int
                    val fps = args["fps"] as? Int
                    val duration = args["duration"] as? Long
                    val deckColorHex = args["deckColorHex"] as? String
                    
                    if (reactionVideoPath == null || gameFramePaths == null || outputPath == null ||
                        pipWidth == null || pipHeight == null || pipX == null || pipY == null ||
                        fps == null || duration == null || deckColorHex == null) {
                        result.error("INVALID_ARGUMENTS", "Missing required arguments", null)
                        return@setMethodCallHandler
                    }
                    
                    scope.launch {
                        try {
                            val compositionResult = VideoComposer.composeVideo(
                                reactionVideoPath = reactionVideoPath,
                                gameFramePaths = gameFramePaths,
                                outputPath = outputPath,
                                pipWidth = pipWidth,
                                pipHeight = pipHeight,
                                pipX = pipX,
                                pipY = pipY,
                                fps = fps,
                                duration = duration,
                                deckColorHex = deckColorHex,
                                progressCallback = { progress ->
                                    progressSink?.success(progress)
                                }
                            )
                            
                            compositionResult.fold(
                                onSuccess = { path ->
                                    result.success(path)
                                },
                                onFailure = { error ->
                                    result.error("COMPOSITION_FAILED", error.message, null)
                                }
                            )
                        } catch (e: Exception) {
                            result.error("COMPOSITION_FAILED", e.message, null)
                        }
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        scope.cancel()
    }
}
