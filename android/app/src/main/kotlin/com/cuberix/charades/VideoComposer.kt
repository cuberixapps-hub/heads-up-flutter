package com.cuberix.charades

import android.graphics.*
import android.media.*
import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.EGLContext
import android.opengl.EGLSurface
import android.opengl.GLES20
import android.os.Build
import android.view.Surface
import kotlinx.coroutines.*
import java.io.File
import java.nio.ByteBuffer
import kotlin.math.max

class VideoComposer {
    companion object {
        suspend fun composeVideo(
            reactionVideoPath: String,
            gameFramePaths: List<String>,
            outputPath: String,
            pipWidth: Int,
            pipHeight: Int,
            pipX: Int,
            pipY: Int,
            fps: Int,
            duration: Long,
            deckColorHex: String,
            progressCallback: (Double) -> Unit
        ): Result<String> = withContext(Dispatchers.IO) {
            try {
                // Extract video info
                val extractor = MediaExtractor()
                extractor.setDataSource(reactionVideoPath)
                
                var videoTrackIndex = -1
                var audioTrackIndex = -1
                var videoFormat: MediaFormat? = null
                var audioFormat: MediaFormat? = null
                
                for (i in 0 until extractor.trackCount) {
                    val format = extractor.getTrackFormat(i)
                    val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
                    
                    when {
                        mime.startsWith("video/") && videoTrackIndex == -1 -> {
                            videoTrackIndex = i
                            videoFormat = format
                        }
                        mime.startsWith("audio/") && audioTrackIndex == -1 -> {
                            audioTrackIndex = i
                            audioFormat = format
                        }
                    }
                }
                
                if (videoFormat == null) {
                    return@withContext Result.failure(Exception("No video track found"))
                }
                
                val width = videoFormat.getInteger(MediaFormat.KEY_WIDTH)
                val height = videoFormat.getInteger(MediaFormat.KEY_HEIGHT)
                
                // Create encoder
                val outputFormat = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, width, height)
                outputFormat.setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
                outputFormat.setInteger(MediaFormat.KEY_BIT_RATE, 10_000_000)
                outputFormat.setInteger(MediaFormat.KEY_FRAME_RATE, fps)
                outputFormat.setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
                
                val encoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
                encoder.configure(outputFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
                
                val inputSurface = encoder.createInputSurface()
                encoder.start()
                
                // Create muxer
                val muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
                
                // Process video with overlay
                val success = processVideoWithOverlay(
                    extractor = extractor,
                    videoTrackIndex = videoTrackIndex,
                    audioTrackIndex = audioTrackIndex,
                    audioFormat = audioFormat,
                    encoder = encoder,
                    inputSurface = inputSurface,
                    muxer = muxer,
                    gameFramePaths = gameFramePaths,
                    pipRect = Rect(width - pipWidth - pipX, height - pipHeight - pipY, 
                                  width - pipX, height - pipY),
                    fps = fps,
                    progressCallback = progressCallback
                )
                
                // Cleanup
                encoder.stop()
                encoder.release()
                extractor.release()
                muxer.stop()
                muxer.release()
                inputSurface.release()
                
                if (success) {
                    Result.success(outputPath)
                } else {
                    Result.failure(Exception("Video processing failed"))
                }
            } catch (e: Exception) {
                Result.failure(e)
            }
        }
        
        private suspend fun processVideoWithOverlay(
            extractor: MediaExtractor,
            videoTrackIndex: Int,
            audioTrackIndex: Int,
            audioFormat: MediaFormat?,
            encoder: MediaCodec,
            inputSurface: Surface,
            muxer: MediaMuxer,
            gameFramePaths: List<String>,
            pipRect: Rect,
            fps: Int,
            progressCallback: (Double) -> Unit
        ): Boolean = withContext(Dispatchers.IO) {
            try {
                var videoOutputTrack = -1
                var audioOutputTrack = -1
                val bufferInfo = MediaCodec.BufferInfo()
                
                // Set up decoder
                extractor.selectTrack(videoTrackIndex)
                val videoFormat = extractor.getTrackFormat(videoTrackIndex)
                val decoder = MediaCodec.createDecoderByType(videoFormat.getString(MediaFormat.KEY_MIME)!!)
                
                val outputSurface = CodecOutputSurface(inputSurface, gameFramePaths, pipRect, fps)
                decoder.configure(videoFormat, outputSurface.surface, null, 0)
                decoder.start()
                
                // Add audio track if present
                if (audioTrackIndex >= 0 && audioFormat != null) {
                    audioOutputTrack = muxer.addTrack(audioFormat)
                }
                
                var muxerStarted = false
                var frameCount = 0
                val totalDuration = videoFormat.getLong(MediaFormat.KEY_DURATION)
                
                // Process video frames
                while (true) {
                    // Feed decoder
                    val inputBufferIndex = decoder.dequeueInputBuffer(1000)
                    if (inputBufferIndex >= 0) {
                        val inputBuffer = decoder.getInputBuffer(inputBufferIndex)!!
                        val sampleSize = extractor.readSampleData(inputBuffer, 0)
                        
                        if (sampleSize < 0) {
                            decoder.queueInputBuffer(inputBufferIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                        } else {
                            val presentationTimeUs = extractor.sampleTime
                            decoder.queueInputBuffer(inputBufferIndex, 0, sampleSize, presentationTimeUs, 0)
                            extractor.advance()
                        }
                    }
                    
                    // Get decoded frame
                    val outputBufferIndex = decoder.dequeueOutputBuffer(bufferInfo, 1000)
                    when {
                        outputBufferIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                            // Handle format change
                        }
                        outputBufferIndex >= 0 -> {
                            val doRender = bufferInfo.size != 0
                            decoder.releaseOutputBuffer(outputBufferIndex, doRender)
                            
                            if (doRender) {
                                outputSurface.awaitNewImage()
                                outputSurface.drawImage(frameCount)
                                frameCount++
                                
                                // Update progress
                                val progress = bufferInfo.presentationTimeUs.toDouble() / totalDuration
                                progressCallback(progress)
                            }
                            
                            if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                                break
                            }
                        }
                    }
                    
                    // Get encoded frame
                    drainEncoder(encoder, muxer, bufferInfo, false) { format ->
                        if (!muxerStarted) {
                            videoOutputTrack = muxer.addTrack(format)
                            muxer.start()
                            muxerStarted = true
                        }
                        videoOutputTrack
                    }
                }
                
                // Finish encoding
                encoder.signalEndOfInputStream()
                drainEncoder(encoder, muxer, bufferInfo, true) { videoOutputTrack }
                
                // Copy audio if present
                if (audioTrackIndex >= 0 && muxerStarted) {
                    copyAudioTrack(extractor, audioTrackIndex, muxer, audioOutputTrack)
                }
                
                decoder.stop()
                decoder.release()
                outputSurface.release()
                
                true
            } catch (e: Exception) {
                e.printStackTrace()
                false
            }
        }
        
        private fun drainEncoder(
            encoder: MediaCodec,
            muxer: MediaMuxer,
            bufferInfo: MediaCodec.BufferInfo,
            endOfStream: Boolean,
            getTrackIndex: (MediaFormat) -> Int
        ) {
            while (true) {
                val encoderStatus = encoder.dequeueOutputBuffer(bufferInfo, 1000)
                
                when {
                    encoderStatus == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                        if (!endOfStream) return
                    }
                    encoderStatus == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        val newFormat = encoder.outputFormat
                        getTrackIndex(newFormat)
                    }
                    encoderStatus >= 0 -> {
                        val encodedData = encoder.getOutputBuffer(encoderStatus)
                            ?: throw RuntimeException("Encoder output buffer was null")
                        
                        if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) {
                            bufferInfo.size = 0
                        }
                        
                        if (bufferInfo.size != 0) {
                            encodedData.position(bufferInfo.offset)
                            encodedData.limit(bufferInfo.offset + bufferInfo.size)
                            muxer.writeSampleData(getTrackIndex(encoder.outputFormat), encodedData, bufferInfo)
                        }
                        
                        encoder.releaseOutputBuffer(encoderStatus, false)
                        
                        if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                            return
                        }
                    }
                }
            }
        }
        
        private fun copyAudioTrack(
            extractor: MediaExtractor,
            audioTrackIndex: Int,
            muxer: MediaMuxer,
            outputTrackIndex: Int
        ) {
            extractor.selectTrack(audioTrackIndex)
            extractor.seekTo(0, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)
            
            val buffer = ByteBuffer.allocate(1024 * 1024)
            val bufferInfo = MediaCodec.BufferInfo()
            
            while (true) {
                bufferInfo.size = extractor.readSampleData(buffer, 0)
                if (bufferInfo.size < 0) break
                
                bufferInfo.presentationTimeUs = extractor.sampleTime
                bufferInfo.flags = extractor.sampleFlags
                bufferInfo.offset = 0
                
                muxer.writeSampleData(outputTrackIndex, buffer, bufferInfo)
                extractor.advance()
            }
        }
    }
    
    private class CodecOutputSurface(
        private val outputSurface: Surface,
        private val gameFrames: List<String>,
        private val pipRect: Rect,
        private val fps: Int
    ) {
        private val egl = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        private val config: EGLConfig
        private val context: EGLContext
        private val eglSurface: EGLSurface
        
        val surface: Surface get() = outputSurface
        
        init {
            // Initialize EGL
            val version = IntArray(2)
            EGL14.eglInitialize(egl, version, 0, version, 1)
            
            val attribList = intArrayOf(
                EGL14.EGL_RED_SIZE, 8,
                EGL14.EGL_GREEN_SIZE, 8,
                EGL14.EGL_BLUE_SIZE, 8,
                EGL14.EGL_ALPHA_SIZE, 8,
                EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
                EGL14.EGL_NONE
            )
            
            val configs = arrayOfNulls<EGLConfig>(1)
            val numConfigs = IntArray(1)
            EGL14.eglChooseConfig(egl, attribList, 0, configs, 0, configs.size, numConfigs, 0)
            config = configs[0]!!
            
            val contextAttribs = intArrayOf(
                EGL14.EGL_CONTEXT_CLIENT_VERSION, 2,
                EGL14.EGL_NONE
            )
            context = EGL14.eglCreateContext(egl, config, EGL14.EGL_NO_CONTEXT, contextAttribs, 0)
            
            val surfaceAttribs = intArrayOf(EGL14.EGL_NONE)
            eglSurface = EGL14.eglCreateWindowSurface(egl, config, outputSurface, surfaceAttribs, 0)
            
            EGL14.eglMakeCurrent(egl, eglSurface, eglSurface, context)
        }
        
        fun awaitNewImage() {
            // Wait for new frame
            Thread.sleep(10)
        }
        
        fun drawImage(frameIndex: Int) {
            // Draw current frame with overlay
            GLES20.glClearColor(0f, 0f, 0f, 1f)
            GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
            
            // Draw PiP overlay
            if (gameFrames.isNotEmpty()) {
                val gameFrameIndex = (frameIndex * gameFrames.size / (fps * 60)).coerceIn(0, gameFrames.size - 1)
                // Draw game frame at pipRect position
                // This would require OpenGL texture loading and rendering
            }
            
            EGL14.eglSwapBuffers(egl, eglSurface)
        }
        
        fun release() {
            EGL14.eglMakeCurrent(egl, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT)
            EGL14.eglDestroySurface(egl, eglSurface)
            EGL14.eglDestroyContext(egl, context)
            EGL14.eglTerminate(egl)
        }
    }
}
