package com.retrolab.retrolab

import android.content.Context
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.opengl.GLES20
import android.opengl.GLUtils
import androidx.media3.common.Effect
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.VideoFrameProcessingException
import androidx.media3.common.util.GlProgram
import androidx.media3.common.util.GlUtil
import androidx.media3.common.util.Size
import androidx.media3.effect.BaseGlShaderProgram
import androidx.media3.effect.GlEffect
import androidx.media3.effect.Presentation
import androidx.media3.transformer.Composition
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Effects
import androidx.media3.transformer.Transformer
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val imageExecutor = Executors.newSingleThreadExecutor()
    private lateinit var imageProcessor: RetrolabNativeImageProcessor

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        imageProcessor = RetrolabNativeImageProcessor(this)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "retrolab/video",
        ).setMethodCallHandler { call, result ->
            if (call.method != "processVideo") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            try {
                val inputPath = call.argument<String>("inputPath")!!
                val outputPath = call.argument<String>("outputPath")!!
                val thumbnailPath = call.argument<String>("thumbnailPath")!!
                @Suppress("UNCHECKED_CAST")
                val settings = call.argument<Map<String, Any?>>("settings")!!
                RetroVideoProcessor(this, RetroFilterSettings.fromMap(settings)).processVideo(
                    inputPath,
                    outputPath,
                    thumbnailPath,
                    result,
                )
            } catch (error: Throwable) {
                result.error("video_args", error.message, null)
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "retrolab/native_image_processor",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> result.success(null)
                "processImage" -> {
                    val imageBytes = call.argument<ByteArray>("imageBytes")
                    @Suppress("UNCHECKED_CAST")
                    val request = call.argument<Map<String, Any?>>("request")
                    if (imageBytes == null || request == null) {
                        result.error("image_args", "Missing imageBytes or request.", null)
                        return@setMethodCallHandler
                    }
                    val scratchBytes = call.argument<ByteArray>("scratchBytes")
                    val leakBytes = call.argument<ByteArray>("leakBytes")
                    val dustBytes = call.argument<ByteArray>("dustBytes")
                    imageExecutor.execute {
                        try {
                            val bytes = imageProcessor.process(
                                imageBytes,
                                request,
                                scratchBytes,
                                leakBytes,
                                dustBytes,
                            )
                            runOnUiThread { result.success(bytes) }
                        } catch (error: Throwable) {
                            android.util.Log.e("RetroLabNative", "processImage failed", error)
                            runOnUiThread {
                                result.error("image_process", error.message, null)
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        imageExecutor.execute {
            imageProcessor.close()
        }
        imageExecutor.shutdown()
        super.onDestroy()
    }
}

private class RetroVideoProcessor(
    private val context: Context,
    private val settings: RetroFilterSettings,
) {
    fun processVideo(
        inputPath: String,
        outputPath: String,
        thumbnailPath: String,
        result: MethodChannel.Result,
    ) {
        File(outputPath).delete()
        File(thumbnailPath).delete()

        val effects = listOf<Effect>(
            Presentation.createForWidthAndHeight(1080, 1920, Presentation.LAYOUT_SCALE_TO_FIT),
            RetroFilterEffect(context, settings),
        )

        val editedMediaItem =
            EditedMediaItem.Builder(MediaItem.fromUri(Uri.fromFile(File(inputPath))))
                .setEffects(Effects(emptyList(), effects))
                .build()

        val transformer =
            Transformer.Builder(context)
                .setVideoMimeType(MimeTypes.VIDEO_H264)
                .setAudioMimeType(MimeTypes.AUDIO_AAC)
                .addListener(
                    object : Transformer.Listener {
                        override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                            try {
                                writeThumbnail(outputPath, thumbnailPath)
                                result.success(
                                    mapOf(
                                        "outputPath" to outputPath,
                                        "thumbnailPath" to thumbnailPath,
                                        "durationMs" to exportResult.durationMs,
                                    ),
                                )
                            } catch (error: Throwable) {
                                result.error("video_thumbnail", error.message, null)
                            }
                        }

                        override fun onError(
                            composition: Composition,
                            exportResult: ExportResult,
                            exportException: ExportException,
                        ) {
                            result.error("video_process", exportException.message, null)
                        }
                    },
                )
                .build()

        transformer.start(editedMediaItem, outputPath)
    }

    private fun writeThumbnail(videoPath: String, thumbnailPath: String) {
        val retriever = MediaMetadataRetriever()
        retriever.setDataSource(videoPath)
        val bitmap = retriever.getFrameAtTime(0) ?: error("No thumbnail frame.")
        FileOutputStream(thumbnailPath).use { stream ->
            bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG, 92, stream)
        }
        retriever.release()
    }
}

private data class RetroFilterSettings(
    val temperature: Float,
    val saturation: Float,
    val contrast: Float,
    val brightness: Float,
    val shadowLift: Float,
    val tintStrength: Float,
    val redGamma: Float,
    val greenGamma: Float,
    val blueGamma: Float,
    val highlightTint: FloatArray,
    val shadowTint: FloatArray,
    val grain: Float,
    val grainSize: Float,
    val grainColored: Float,
    val vignette: Float,
    val scratchLevel: Float,
    val leakStrength: Float,
    val dustStrength: Float,
    val halation: Float,
    val colorMatrixRow0: FloatArray,
    val colorMatrixRow1: FloatArray,
    val colorMatrixRow2: FloatArray,
    val glareTint: FloatArray,
    val borderGlare: Float,
    val glareWidth: Float,
    val glareAngle: Float,
    val caOffset: FloatArray,
    val leakAsset: String,
    val dustAsset: String,
    val scratchAsset: String,
) {
    companion object {
        fun fromMap(map: Map<String, Any?>): RetroFilterSettings {
            fun value(name: String) = (map[name] as Number).toFloat()
            fun tint(name: String): FloatArray {
                @Suppress("UNCHECKED_CAST")
                val list = map[name] as List<Number>
                return floatArrayOf(list[0].toFloat(), list[1].toFloat(), list[2].toFloat())
            }
            fun vec2(name: String): FloatArray {
                @Suppress("UNCHECKED_CAST")
                val list = map[name] as List<Number>
                return floatArrayOf(list[0].toFloat(), list[1].toFloat())
            }
            return RetroFilterSettings(
                temperature = value("temperature"),
                saturation = value("saturation"),
                contrast = value("contrast"),
                brightness = value("brightness"),
                shadowLift = value("shadowLift"),
                tintStrength = value("tintStrength"),
                redGamma = value("redGamma"),
                greenGamma = value("greenGamma"),
                blueGamma = value("blueGamma"),
                highlightTint = tint("highlightTint"),
                shadowTint = tint("shadowTint"),
                grain = value("grain"),
                grainSize = value("grainSize"),
                grainColored = if (map["grainColored"] as Boolean) 1f else 0f,
                vignette = value("vignette"),
                scratchLevel = value("scratchLevel"),
                leakStrength = value("leakStrength"),
                dustStrength = value("dustStrength"),
                halation = value("halation"),
                colorMatrixRow0 = tint("colorMatrixRow0"),
                colorMatrixRow1 = tint("colorMatrixRow1"),
                colorMatrixRow2 = tint("colorMatrixRow2"),
                glareTint = tint("glareTint"),
                borderGlare = value("borderGlare"),
                glareWidth = value("glareWidth"),
                glareAngle = value("glareAngle"),
                caOffset = vec2("caOffset"),
                leakAsset = map["leakAsset"] as String,
                dustAsset = map["dustAsset"] as String,
                scratchAsset = map["scratchAsset"] as String,
            )
        }
    }
}

private class RetroFilterEffect(
    private val appContext: Context,
    private val settings: RetroFilterSettings,
) : GlEffect {
    override fun toGlShaderProgram(context: Context, useHdr: Boolean): BaseGlShaderProgram {
        return RetroFilterShaderProgram(appContext, useHdr, settings)
    }

    override fun isNoOp(inputWidth: Int, inputHeight: Int): Boolean = false
}

private class RetroFilterShaderProgram(
    context: Context,
    useHdr: Boolean,
    private val settings: RetroFilterSettings,
) : BaseGlShaderProgram(useHdr, 1) {
    private val glProgram: GlProgram
    private val scratchTextureId: Int
    private val leakTextureId: Int
    private val dustTextureId: Int
    private var width = 1
    private var height = 1

    init {
        try {
            glProgram =
                GlProgram(
                    context.resources.openRawResource(R.raw.retrolab_vertex_shader)
                        .bufferedReader()
                        .use { it.readText() },
                    context.resources.openRawResource(R.raw.retrolab_film_video_shader)
                        .bufferedReader()
                        .use { it.readText() },
                )
            glProgram.setBufferAttribute(
                "aFramePosition",
                GlUtil.getNormalizedCoordinateBounds(),
                GlUtil.HOMOGENEOUS_COORDINATE_VECTOR_SIZE,
            )
            val identity = GlUtil.create4x4IdentityMatrix()
            glProgram.setFloatsUniform("uTransformationMatrix", identity)
            glProgram.setFloatsUniform("uTexTransformationMatrix", identity)
            scratchTextureId = loadTexture(context, settings.scratchAsset)
            leakTextureId = loadTexture(context, settings.leakAsset)
            dustTextureId = loadTexture(context, settings.dustAsset)
        } catch (error: IOException) {
            throw VideoFrameProcessingException(error)
        } catch (error: GlUtil.GlException) {
            throw VideoFrameProcessingException(error)
        }
    }

    override fun configure(inputWidth: Int, inputHeight: Int): Size {
        width = inputWidth
        height = inputHeight
        return Size(inputWidth, inputHeight)
    }

    override fun drawFrame(inputTexId: Int, presentationTimeUs: Long) {
        try {
            glProgram.use()
            glProgram.setSamplerTexIdUniform("uTexSampler", inputTexId, 0)
            glProgram.setSamplerTexIdUniform("uScratchTexture", scratchTextureId, 1)
            glProgram.setSamplerTexIdUniform("uLeakTexture", leakTextureId, 2)
            glProgram.setSamplerTexIdUniform("uDustTexture", dustTextureId, 3)
            glProgram.setSamplerTexIdUniform("uLutTexture", inputTexId, 4)
            glProgram.setFloatsUniform("uSize", floatArrayOf(width.toFloat(), height.toFloat()))
            glProgram.setFloatUniform("uTemperature", settings.temperature)
            glProgram.setFloatUniform("uSaturation", settings.saturation)
            glProgram.setFloatUniform("uContrast", settings.contrast)
            glProgram.setFloatUniform("uBrightness", settings.brightness)
            glProgram.setFloatUniform("uShadowLift", settings.shadowLift)
            glProgram.setFloatUniform("uTintStrength", settings.tintStrength)
            glProgram.setFloatUniform("uRedGamma", settings.redGamma)
            glProgram.setFloatUniform("uGreenGamma", settings.greenGamma)
            glProgram.setFloatUniform("uBlueGamma", settings.blueGamma)
            glProgram.setFloatsUniform("uHighlightTint", settings.highlightTint)
            glProgram.setFloatsUniform("uShadowTint", settings.shadowTint)
            glProgram.setFloatUniform("uGrain", settings.grain)
            glProgram.setFloatUniform("uGrainSize", settings.grainSize)
            glProgram.setFloatUniform("uGrainColored", settings.grainColored)
            glProgram.setFloatUniform("uVignette", settings.vignette)
            glProgram.setFloatUniform("uScratch", settings.scratchLevel)
            glProgram.setFloatUniform("uLeak", settings.leakStrength)
            glProgram.setFloatUniform("uDust", settings.dustStrength)
            glProgram.setFloatUniform("uHalation", settings.halation)
            glProgram.setFloatUniform("uArtifactSeed", 0f)
            glProgram.setFloatUniform("uLutStrength", 0f)
            glProgram.setFloatsUniform("uColorMatrixRow0", settings.colorMatrixRow0)
            glProgram.setFloatsUniform("uColorMatrixRow1", settings.colorMatrixRow1)
            glProgram.setFloatsUniform("uColorMatrixRow2", settings.colorMatrixRow2)
            glProgram.setFloatsUniform("uGlareTint", settings.glareTint)
            glProgram.setFloatUniform("uBorderGlare", settings.borderGlare)
            glProgram.setFloatUniform("uGlareWidth", settings.glareWidth)
            glProgram.setFloatUniform("uGlareAngle", settings.glareAngle)
            glProgram.setFloatsUniform("uCaOffset", settings.caOffset)
            glProgram.bindAttributesAndUniforms()
            GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        } catch (error: GlUtil.GlException) {
            throw VideoFrameProcessingException(error, presentationTimeUs)
        }
    }

    override fun release() {
        super.release()
        glProgram.delete()
        GLES20.glDeleteTextures(3, intArrayOf(scratchTextureId, leakTextureId, dustTextureId), 0)
    }

    private fun loadTexture(context: Context, assetPath: String): Int {
        val assetKey = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(assetPath)
        val bitmap =
            context.assets.open(assetKey).use { stream ->
                BitmapFactory.decodeStream(stream)
            } ?: error("Missing asset: $assetPath")
        val textureIds = IntArray(1)
        GLES20.glGenTextures(1, textureIds, 0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, textureIds[0])
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(
            GLES20.GL_TEXTURE_2D,
            GLES20.GL_TEXTURE_WRAP_S,
            GLES20.GL_CLAMP_TO_EDGE,
        )
        GLES20.glTexParameteri(
            GLES20.GL_TEXTURE_2D,
            GLES20.GL_TEXTURE_WRAP_T,
            GLES20.GL_CLAMP_TO_EDGE,
        )
        GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, bitmap, 0)
        bitmap.recycle()
        return textureIds[0]
    }
}
