package com.example.xiangji.camera

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.camera2.CameraCaptureSession
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraDevice
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CaptureRequest
import android.hardware.camera2.params.StreamConfigurationMap
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.media.MediaRecorder
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.HandlerThread
import android.util.Size
import android.view.Surface
import com.example.xiangji.bridge.CameraBridgeEventBus
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.atomic.AtomicBoolean

class Camera2SegmentRecorder(
    private val context: Context,
) {
    private val cameraManager =
        context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
    private val running = AtomicBoolean(false)
    private val dateFormat = SimpleDateFormat(
        "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
        Locale.US,
    ).apply {
        timeZone = TimeZone.getTimeZone("UTC")
    }

    private var config: RecorderConfig? = null
    private var cameraThread: HandlerThread? = null
    private var cameraHandler: Handler? = null
    private var drainThread: Thread? = null
    private var cameraDevice: CameraDevice? = null
    private var captureSession: CameraCaptureSession? = null
    private var encoder: MediaCodec? = null
    private var inputSurface: Surface? = null

    private var trackFormat: MediaFormat? = null
    private var muxer: MediaMuxer? = null
    private var currentSegmentFile: File? = null
    private var currentSegmentCapturedAt: Date? = null
    private var currentSegmentSequence = 0
    private var currentSegmentLastPtsUs = 0L
    private var muxerTrackIndex = -1
    private var muxerStarted = false
    private var segmentStartPtsUs = 0L
    private var pendingRotate = false
    private var segmentSequence = 0

    fun start(config: RecorderConfig) {
        if (!running.compareAndSet(false, true)) {
            CameraBridgeEventBus.log("warning", "录制器已经在运行。")
            return
        }

        this.config = config
        try {
            if (!hasCameraPermission()) {
                CameraBridgeEventBus.error(
                    message = "缺少 Android 相机权限。",
                    details = "授予 CAMERA 权限后才能开始 Camera2 录制。",
                )
                running.set(false)
                return
            }

            val selectedCamera = selectCamera()
            if (selectedCamera == null) {
                CameraBridgeEventBus.error(
                    message = "没有可用于录制的 Camera2 摄像头。",
                    details = "如果 USB 摄像头只显示为 /dev/video*，这个板子仍然需要 libuvc 后端。",
                )
                running.set(false)
                return
            }

            val cameraId = selectedCamera.cameraId
            val size = chooseVideoSize(selectedCamera.map)
            val cameraThread = HandlerThread("XiangjiCamera2").also { it.start() }
            this.cameraThread = cameraThread
            cameraHandler = Handler(cameraThread.looper)

            CameraBridgeEventBus.log(
                level = "info",
                message = "正在使用 Camera2 摄像头 $cameraId，分辨率 ${size.width}x${size.height}。",
            )

            prepareEncoder(size)
            startDrainThread()
            openCamera(cameraId)
        } catch (error: Throwable) {
            CameraBridgeEventBus.error(
                message = "启动 Camera2 录制器失败。",
                details = error.message ?: error.toString(),
            )
            stop()
        }
    }

    fun stop() {
        if (!running.getAndSet(false)) {
            return
        }

        runCatching {
            captureSession?.stopRepeating()
        }
        runCatching {
            captureSession?.abortCaptures()
        }
        runCatching {
            captureSession?.close()
        }
        captureSession = null

        runCatching {
            cameraDevice?.close()
        }
        cameraDevice = null

        runCatching {
            encoder?.signalEndOfInputStream()
        }

        runCatching {
            drainThread?.join(3000)
        }
        drainThread = null

        releaseEncoder()

        runCatching {
            cameraThread?.quitSafely()
        }
        cameraThread = null
        cameraHandler = null
        trackFormat = null
        pendingRotate = false
    }

    private fun selectCamera(): SelectedCamera? {
        val ids = cameraManager.cameraIdList
        val cameras = ids.mapNotNull { cameraId ->
            runCatching {
                val characteristics = cameraManager.getCameraCharacteristics(cameraId)
                val map = characteristics.get(
                    CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP,
                )
                val lensFacing = characteristics.get(CameraCharacteristics.LENS_FACING)
                CameraBridgeEventBus.log(
                    level = "debug",
                    message = "Camera2 摄像头 $cameraId，镜头方向=${lensFacingLabel(lensFacing)}。",
                )
                if (map == null) {
                    null
                } else {
                    SelectedCamera(cameraId, characteristics, map)
                }
            }.getOrNull()
        }

        if (cameras.isEmpty()) {
            return null
        }

        val external = cameras.firstOrNull { camera ->
            camera.characteristics.get(CameraCharacteristics.LENS_FACING) ==
                CameraCharacteristics.LENS_FACING_EXTERNAL
        }
        if (external != null) {
            return external
        }

        CameraBridgeEventBus.log(
            level = "warning",
            message = "没有找到 LENS_FACING_EXTERNAL 摄像头，回退到第一个 Camera2 摄像头。",
        )
        return cameras.first()
    }

    private fun chooseVideoSize(map: StreamConfigurationMap): Size {
        val sizes = outputSizes(map, MediaCodec::class.java)
            .ifEmpty { outputSizes(map, MediaRecorder::class.java) }
            .ifEmpty { outputSizes(map, Surface::class.java) }
        if (sizes.isEmpty()) {
            return Size(DEFAULT_WIDTH, DEFAULT_HEIGHT)
        }

        val exact720p = sizes.firstOrNull { size ->
            size.width == DEFAULT_WIDTH && size.height == DEFAULT_HEIGHT
        }
        if (exact720p != null) {
            return exact720p
        }

        return sizes
            .filter { size -> size.width <= 1920 && size.height <= 1080 }
            .maxByOrNull { size -> size.width * size.height }
            ?: sizes.maxBy { size -> size.width * size.height }
    }

    private fun prepareEncoder(size: Size) {
        val mediaFormat = MediaFormat.createVideoFormat(
            MIME_TYPE,
            size.width,
            size.height,
        ).apply {
            setInteger(
                MediaFormat.KEY_COLOR_FORMAT,
                MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface,
            )
            setInteger(MediaFormat.KEY_BIT_RATE, DEFAULT_BIT_RATE)
            setInteger(MediaFormat.KEY_FRAME_RATE, DEFAULT_FRAME_RATE)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, DEFAULT_I_FRAME_INTERVAL)
        }

        val mediaCodec = MediaCodec.createEncoderByType(MIME_TYPE)
        mediaCodec.configure(
            mediaFormat,
            null,
            null,
            MediaCodec.CONFIGURE_FLAG_ENCODE,
        )
        inputSurface = mediaCodec.createInputSurface()
        mediaCodec.start()
        encoder = mediaCodec
    }

    private fun startDrainThread() {
        val thread = Thread(
            {
                drainEncoder()
            },
            "XiangjiEncoderDrain",
        )
        drainThread = thread
        thread.start()
    }

    @SuppressLint("MissingPermission")
    private fun openCamera(cameraId: String) {
        val handler = cameraHandler
        if (handler == null) {
            CameraBridgeEventBus.error("相机处理线程尚未就绪。")
            return
        }

        cameraManager.openCamera(
            cameraId,
            object : CameraDevice.StateCallback() {
                override fun onOpened(camera: CameraDevice) {
                    cameraDevice = camera
                    createCaptureSession(camera)
                }

                override fun onDisconnected(camera: CameraDevice) {
                    CameraBridgeEventBus.error("摄像头已断开。", cameraId)
                    camera.close()
                    stop()
                }

                override fun onError(camera: CameraDevice, error: Int) {
                    CameraBridgeEventBus.error(
                        message = "打开摄像头失败。",
                        details = "camera=$cameraId error=$error",
                    )
                    camera.close()
                    stop()
                }
            },
            handler,
        )
    }

    private fun createCaptureSession(camera: CameraDevice) {
        val surface = inputSurface
        val handler = cameraHandler
        if (surface == null || handler == null) {
            CameraBridgeEventBus.error("编码器 Surface 尚未就绪。")
            stop()
            return
        }

        camera.createCaptureSession(
            listOf(surface),
            object : CameraCaptureSession.StateCallback() {
                override fun onConfigured(session: CameraCaptureSession) {
                    if (!running.get()) {
                        session.close()
                        return
                    }

                    captureSession = session
                    val request = camera.createCaptureRequest(
                        CameraDevice.TEMPLATE_RECORD,
                    ).apply {
                        addTarget(surface)
                        set(
                            CaptureRequest.CONTROL_MODE,
                            CaptureRequest.CONTROL_MODE_AUTO,
                        )
                    }.build()

                    runCatching {
                        session.setRepeatingRequest(request, null, handler)
                        CameraBridgeEventBus.status(
                            phase = "streaming",
                            message = "Camera2 录制已开始。",
                        )
                    }.onFailure { error ->
                        CameraBridgeEventBus.error(
                            message = "启动摄像头采集失败。",
                            details = error.message ?: error.toString(),
                        )
                        stop()
                    }
                }

                override fun onConfigureFailed(session: CameraCaptureSession) {
                    CameraBridgeEventBus.error("摄像头采集会话配置失败。")
                    stop()
                }
            },
            handler,
        )
    }

    private fun drainEncoder() {
        val mediaCodec = encoder ?: return
        val bufferInfo = MediaCodec.BufferInfo()
        var encoderDone = false

        while (!encoderDone) {
            val outputIndex = mediaCodec.dequeueOutputBuffer(
                bufferInfo,
                DEQUEUE_TIMEOUT_US,
            )

            when {
                outputIndex == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                    if (!running.get()) {
                        runCatching {
                            mediaCodec.signalEndOfInputStream()
                        }
                    }
                }

                outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    trackFormat = mediaCodec.outputFormat
                }

                outputIndex >= 0 -> {
                    val outputBuffer = mediaCodec.getOutputBuffer(outputIndex)
                    val isConfig =
                        bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0

                    if (outputBuffer != null && bufferInfo.size > 0 && !isConfig) {
                        writeSample(outputBuffer, bufferInfo)
                    }

                    encoderDone =
                        bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
                    mediaCodec.releaseOutputBuffer(outputIndex, false)
                }
            }
        }

        finishCurrentSegment()
    }

    private fun writeSample(
        outputBuffer: java.nio.ByteBuffer,
        bufferInfo: MediaCodec.BufferInfo,
    ) {
        val format = trackFormat ?: return
        val config = config ?: return
        val samplePtsUs = bufferInfo.presentationTimeUs
        val keyFrame = bufferInfo.flags and MediaCodec.BUFFER_FLAG_KEY_FRAME != 0

        if (!muxerStarted) {
            startSegment(format, samplePtsUs)
        } else if (pendingRotate && keyFrame) {
            finishCurrentSegment()
            startSegment(format, samplePtsUs)
            pendingRotate = false
        }

        val mediaMuxer = muxer ?: return
        val sampleInfo = MediaCodec.BufferInfo().apply {
            set(
                0,
                bufferInfo.size,
                (samplePtsUs - segmentStartPtsUs).coerceAtLeast(0L),
                bufferInfo.flags,
            )
        }

        outputBuffer.position(bufferInfo.offset)
        outputBuffer.limit(bufferInfo.offset + bufferInfo.size)
        mediaMuxer.writeSampleData(muxerTrackIndex, outputBuffer, sampleInfo)
        currentSegmentLastPtsUs = samplePtsUs

        val elapsedUs = samplePtsUs - segmentStartPtsUs
        if (
            running.get() &&
            elapsedUs >= config.fragmentDurationMs * 1000L &&
            !pendingRotate
        ) {
            pendingRotate = true
            requestKeyFrame()
            CameraBridgeEventBus.log(
                level = "debug",
                message = "已请求下一段 ${config.fragmentDurationMs}ms 分片的关键帧。",
            )
        }
    }

    private fun startSegment(format: MediaFormat, startPtsUs: Long) {
        val config = config ?: return
        val outputDir = File(context.filesDir, "segments/${config.streamId}").apply {
            mkdirs()
        }
        val sequence = ++segmentSequence
        val capturedAt = Date()
        val segmentFile = File(
            outputDir,
            "${config.streamId}_${sequence.toString().padStart(6, '0')}_${capturedAt.time}.mp4",
        )

        val mediaMuxer = MediaMuxer(
            segmentFile.absolutePath,
            MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4,
        )
        muxerTrackIndex = mediaMuxer.addTrack(format)
        mediaMuxer.start()

        muxer = mediaMuxer
        muxerStarted = true
        currentSegmentFile = segmentFile
        currentSegmentCapturedAt = capturedAt
        currentSegmentSequence = sequence
        segmentStartPtsUs = startPtsUs
        currentSegmentLastPtsUs = startPtsUs

        CameraBridgeEventBus.log(
            level = "info",
            message = "已开始分片 ${segmentFile.name}。",
        )
    }

    private fun finishCurrentSegment() {
        val mediaMuxer = muxer
        val segmentFile = currentSegmentFile
        val capturedAt = currentSegmentCapturedAt
        val config = config
        val sequence = currentSegmentSequence
        val durationMs = ((currentSegmentLastPtsUs - segmentStartPtsUs) / 1000L)
            .coerceAtLeast(0L)
            .toInt()

        muxer = null
        currentSegmentFile = null
        currentSegmentCapturedAt = null
        currentSegmentSequence = 0
        currentSegmentLastPtsUs = 0L
        muxerStarted = false
        muxerTrackIndex = -1

        if (mediaMuxer == null || segmentFile == null || capturedAt == null || config == null) {
            return
        }

        val muxerStopped = runCatching {
            mediaMuxer.stop()
        }.onFailure { error ->
            CameraBridgeEventBus.log(
                level = "warning",
                message = "停止 MediaMuxer 失败：${segmentFile.name}，${error.message}",
            )
        }.isSuccess
        runCatching {
            mediaMuxer.release()
        }

        if (!muxerStopped) {
            runCatching {
                segmentFile.delete()
            }
            CameraBridgeEventBus.log(
                level = "warning",
                message = "跳过不完整分片 ${segmentFile.name}。",
            )
            return
        }

        val byteLength = segmentFile.length()
        if (byteLength <= 0L) {
            CameraBridgeEventBus.log(
                level = "warning",
                message = "跳过空分片 ${segmentFile.name}。",
            )
            return
        }

        CameraBridgeEventBus.segment(
            mapOf(
                "segmentId" to segmentFile.nameWithoutExtension,
                "deviceId" to config.deviceId,
                "streamId" to config.streamId,
                "filePath" to segmentFile.absolutePath,
                "sequence" to sequence,
                "durationMs" to durationMs,
                "byteLength" to byteLength,
                "capturedAt" to dateFormat.format(capturedAt),
            ),
        )
        CameraBridgeEventBus.log(
            level = "info",
            message = "分片 ${segmentFile.name} 已完成（${byteLength} 字节）。",
        )
    }

    private fun requestKeyFrame() {
        runCatching {
            val params = Bundle().apply {
                putInt(MediaCodec.PARAMETER_KEY_REQUEST_SYNC_FRAME, 0)
            }
            encoder?.setParameters(params)
        }
    }

    private fun releaseEncoder() {
        runCatching {
            inputSurface?.release()
        }
        inputSurface = null

        runCatching {
            encoder?.stop()
        }
        runCatching {
            encoder?.release()
        }
        encoder = null
        finishCurrentSegment()
    }

    private fun lensFacingLabel(value: Int?): String {
        return when (value) {
            CameraCharacteristics.LENS_FACING_EXTERNAL -> "外置"
            CameraCharacteristics.LENS_FACING_FRONT -> "前置"
            CameraCharacteristics.LENS_FACING_BACK -> "后置"
            else -> "未知"
        }
    }

    private fun hasCameraPermission(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            context.checkSelfPermission(Manifest.permission.CAMERA) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun outputSizes(
        map: StreamConfigurationMap,
        surfaceClass: Class<*>,
    ): List<Size> {
        return runCatching {
            map.getOutputSizes(surfaceClass)?.toList().orEmpty()
        }.getOrElse { emptyList() }
    }

    data class RecorderConfig(
        val deviceId: String,
        val streamId: String,
        val fragmentDurationMs: Int,
    )

    private data class SelectedCamera(
        val cameraId: String,
        val characteristics: CameraCharacteristics,
        val map: StreamConfigurationMap,
    )

    private companion object {
        const val MIME_TYPE = "video/avc"
        const val DEFAULT_WIDTH = 1280
        const val DEFAULT_HEIGHT = 720
        const val DEFAULT_FRAME_RATE = 30
        const val DEFAULT_BIT_RATE = 4_000_000
        const val DEFAULT_I_FRAME_INTERVAL = 1
        const val DEQUEUE_TIMEOUT_US = 10_000L
    }
}
