package com.retrolab.retrolab

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.Typeface
import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.EGLContext
import android.opengl.EGLDisplay
import android.opengl.EGLSurface
import android.opengl.GLES20
import android.opengl.GLUtils
import android.util.Log
import androidx.exifinterface.media.ExifInterface
import io.flutter.FlutterInjector
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.max
import kotlin.math.roundToInt

class RetrolabNativeImageProcessor(context: Context) {
    private val renderer = StillImageGlRenderer(context.applicationContext)

    fun process(
        imageBytes: ByteArray,
        request: Map<String, Any?>,
        scratchBytes: ByteArray?,
        leakBytes: ByteArray?,
        dustBytes: ByteArray?,
    ): ByteArray {
        val sw = System.currentTimeMillis()
        var bitmap = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size)
            ?: error("Could not decode image.")
        bitmap = rotateForExif(bitmap, imageBytes)
        if (bitmap.width > 2400) {
            val height = (bitmap.height * (2400f / bitmap.width)).toInt()
            bitmap = Bitmap.createScaledBitmap(bitmap, 2400, height, true)
        }
        if (bitmap.config != Bitmap.Config.ARGB_8888) {
            bitmap = bitmap.copy(Bitmap.Config.ARGB_8888, false)
        }

        val rendered = renderer.render(bitmap, request, scratchBytes, leakBytes, dustBytes)
        val stamped = drawDateStamp(rendered, request)
        val out = ByteArrayOutputStream()
        stamped.compress(Bitmap.CompressFormat.JPEG, 92, out)
        Log.d("RetroLabNative", "image processing ${System.currentTimeMillis() - sw}ms")
        return out.toByteArray()
    }

    fun close() {
        renderer.release()
    }

    private fun rotateForExif(bitmap: Bitmap, bytes: ByteArray): Bitmap {
        val orientation = try {
            ExifInterface(ByteArrayInputStream(bytes)).getAttributeInt(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL,
            )
        } catch (_: Throwable) {
            ExifInterface.ORIENTATION_NORMAL
        }
        val matrix = Matrix()
        when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
            ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
            ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.postScale(-1f, 1f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.postScale(1f, -1f)
            else -> return bitmap
        }
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    }

    private fun drawDateStamp(bitmap: Bitmap, request: Map<String, Any?>): Bitmap {
        if (request["dateStampEnabled"] != true) return bitmap

        val mutable = bitmap.copy(Bitmap.Config.ARGB_8888, true)
        val canvas = Canvas(mutable)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        paint.color = when (request["dateStampStyle"] as? String) {
            "handwritten", "polaroid" -> Color.WHITE
            else -> Color.rgb(255, 214, 0)
        }
        paint.textSize = max(28f, bitmap.width * 0.035f)
        paint.typeface = Typeface.MONOSPACE
        paint.setShadowLayer(2f, 1f, 1f, Color.argb(120, 255, 120, 0))

        val millis = (request["captureTimestampMillis"] as Number).toLong()
        val text = SimpleDateFormat("MM  dd  ''yy", Locale.US).format(Date(millis))
        val bounds = Rect()
        paint.getTextBounds(text, 0, text.length, bounds)

        val margin = bitmap.width * 0.045f
        val x = when (request["dateStampPosition"] as? String) {
            "bottomLeft" -> margin
            "bottomCenter" -> (bitmap.width - bounds.width()) / 2f
            else -> bitmap.width - bounds.width() - margin
        }
        canvas.drawText(text, x, bitmap.height - margin, paint)
        return mutable
    }
}

private class StillImageGlRenderer(private val context: Context) {
    private var display: EGLDisplay = EGL14.EGL_NO_DISPLAY
    private var eglContext: EGLContext = EGL14.EGL_NO_CONTEXT
    private var surface: EGLSurface = EGL14.EGL_NO_SURFACE
    private var eglConfig: EGLConfig? = null
    private var surfaceWidth = 0
    private var surfaceHeight = 0
    private var program = 0
    private var sourceTex = 0
    private var transparentTex = 0
    private var filmLutTexture: TextureEntry? = null
    private val overlayTextures = mutableMapOf<String, TextureEntry>()
    private val vertices: FloatBuffer = ByteBuffer.allocateDirect(8 * 4)
        .order(ByteOrder.nativeOrder())
        .asFloatBuffer()
        .apply {
            put(floatArrayOf(-1f, -1f, 1f, -1f, -1f, 1f, 1f, 1f))
            position(0)
        }

    fun render(
        source: Bitmap,
        request: Map<String, Any?>,
        scratchBytes: ByteArray?,
        leakBytes: ByteArray?,
        dustBytes: ByteArray?,
    ): Bitmap {
        ensureReady(source.width, source.height)
        GLES20.glViewport(0, 0, source.width, source.height)
        GLES20.glUseProgram(program)

        uploadTexture(sourceTex, source)
        val scratchTex = overlayTexture("scratch", scratchBytes, request["scratchAsset"] as? String)
        val leakTex = overlayTexture("leak", leakBytes, request["leakAsset"] as? String)
        val dustTex = overlayTexture("dust", dustBytes, request["dustAsset"] as? String)
        val lutTex = lutTexture(request["filmStockId"] as? String ?: "default")

        bindTexture("uTexSampler", sourceTex, 0)
        bindTexture("uScratchTexture", scratchTex, 1)
        bindTexture("uLeakTexture", leakTex, 2)
        bindTexture("uDustTexture", dustTex, 3)
        bindTexture("uLutTexture", lutTex, 4)
        setUniforms(request, source.width, source.height)
        bindVertices()

        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        checkGl("draw")

        val buffer = ByteBuffer.allocateDirect(source.width * source.height * 4)
            .order(ByteOrder.nativeOrder())
        GLES20.glReadPixels(
            0,
            0,
            source.width,
            source.height,
            GLES20.GL_RGBA,
            GLES20.GL_UNSIGNED_BYTE,
            buffer,
        )
        checkGl("readPixels")
        return rgbaToBitmap(buffer, source.width, source.height)
    }

    private fun ensureReady(width: Int, height: Int) {
        if (display == EGL14.EGL_NO_DISPLAY) {
            createEgl()
        }
        if (surface == EGL14.EGL_NO_SURFACE || width != surfaceWidth || height != surfaceHeight) {
            createSurface(width, height)
        }
        if (program == 0) {
            program = createProgram(
                context.resources.openRawResource(R.raw.retrolab_vertex_shader)
                    .bufferedReader()
                    .use { it.readText() },
                context.resources.openRawResource(R.raw.retrolab_film_video_shader)
                    .bufferedReader()
                    .use { it.readText() },
            )
        }
        if (sourceTex == 0) {
            sourceTex = newTexture()
        }
        if (transparentTex == 0) {
            transparentTex = newTexture()
            val transparent = Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_8888)
            transparent.eraseColor(Color.TRANSPARENT)
            uploadTexture(transparentTex, transparent)
            transparent.recycle()
        }
    }

    private fun createEgl() {
        display = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        check(display != EGL14.EGL_NO_DISPLAY) { "No EGL display." }
        val version = IntArray(2)
        check(EGL14.eglInitialize(display, version, 0, version, 1)) { "EGL init failed." }
        val attribs = intArrayOf(
            EGL14.EGL_RENDERABLE_TYPE,
            EGL14.EGL_OPENGL_ES2_BIT,
            EGL14.EGL_RED_SIZE,
            8,
            EGL14.EGL_GREEN_SIZE,
            8,
            EGL14.EGL_BLUE_SIZE,
            8,
            EGL14.EGL_ALPHA_SIZE,
            8,
            EGL14.EGL_NONE,
        )
        val configs = arrayOfNulls<EGLConfig>(1)
        val count = IntArray(1)
        check(EGL14.eglChooseConfig(display, attribs, 0, configs, 0, 1, count, 0)) {
            "No EGL config."
        }
        eglConfig = configs[0] ?: error("No EGL config.")
        eglContext = EGL14.eglCreateContext(
            display,
            eglConfig,
            EGL14.EGL_NO_CONTEXT,
            intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE),
            0,
        )
        check(eglContext != EGL14.EGL_NO_CONTEXT) { "Could not create EGL context." }
    }

    private fun createSurface(width: Int, height: Int) {
        if (surface != EGL14.EGL_NO_SURFACE) {
            EGL14.eglDestroySurface(display, surface)
        }
        surface = EGL14.eglCreatePbufferSurface(
            display,
            eglConfig,
            intArrayOf(EGL14.EGL_WIDTH, width, EGL14.EGL_HEIGHT, height, EGL14.EGL_NONE),
            0,
        )
        surfaceWidth = width
        surfaceHeight = height
        check(EGL14.eglMakeCurrent(display, surface, surface, eglContext)) {
            "Could not bind EGL context."
        }
    }

    private fun createProgram(vertex: String, fragment: String): Int {
        val vertexShader = compile(GLES20.GL_VERTEX_SHADER, vertex)
        val fragmentShader = compile(GLES20.GL_FRAGMENT_SHADER, fragment)
        val id = GLES20.glCreateProgram()
        GLES20.glAttachShader(id, vertexShader)
        GLES20.glAttachShader(id, fragmentShader)
        GLES20.glLinkProgram(id)
        val ok = IntArray(1)
        GLES20.glGetProgramiv(id, GLES20.GL_LINK_STATUS, ok, 0)
        check(ok[0] == GLES20.GL_TRUE) { GLES20.glGetProgramInfoLog(id) }
        GLES20.glDeleteShader(vertexShader)
        GLES20.glDeleteShader(fragmentShader)
        return id
    }

    private fun compile(type: Int, source: String): Int {
        val shader = GLES20.glCreateShader(type)
        GLES20.glShaderSource(shader, source)
        GLES20.glCompileShader(shader)
        val ok = IntArray(1)
        GLES20.glGetShaderiv(shader, GLES20.GL_COMPILE_STATUS, ok, 0)
        check(ok[0] == GLES20.GL_TRUE) { GLES20.glGetShaderInfoLog(shader) }
        return shader
    }

    private fun overlayTexture(slot: String, bytes: ByteArray?, assetPath: String?): Int {
        val key = when {
            bytes != null -> "bytes:${bytes.size}:${bytes.contentHashCode()}"
            assetPath != null -> "asset:$assetPath"
            else -> return transparentTex
        }
        overlayTextures[slot]?.let {
            if (it.key == key) return it.texture
            GLES20.glDeleteTextures(1, intArrayOf(it.texture), 0)
        }
        val bitmap = if (bytes != null) {
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
        } else {
            decodeAsset(assetPath!!)
        } ?: return transparentTex
        val texture = newTexture()
        uploadTexture(texture, bitmap)
        bitmap.recycle()
        overlayTextures[slot] = TextureEntry(key, texture)
        return texture
    }

    private fun lutTexture(filmStockId: String): Int {
        filmLutTexture?.let {
            if (it.key == filmStockId) return it.texture
            GLES20.glDeleteTextures(1, intArrayOf(it.texture), 0)
        }
        val texture = newTexture()
        val bitmap = buildLutBitmap(filmStockId)
        uploadTexture(texture, bitmap)
        bitmap.recycle()
        filmLutTexture = TextureEntry(filmStockId, texture)
        return texture
    }

    private fun buildLutBitmap(filmStockId: String): Bitmap {
        val size = 16
        val width = size * size
        val pixels = IntArray(width * size)
        for (b in 0 until size) {
            for (g in 0 until size) {
                for (r in 0 until size) {
                    val color = gradeLutColor(
                        filmStockId,
                        r / (size - 1f),
                        g / (size - 1f),
                        b / (size - 1f),
                    )
                    pixels[g * width + b * size + r] = Color.rgb(
                        (clamp01(color[0]) * 255f).roundToInt(),
                        (clamp01(color[1]) * 255f).roundToInt(),
                        (clamp01(color[2]) * 255f).roundToInt(),
                    )
                }
            }
        }
        return Bitmap.createBitmap(pixels, width, size, Bitmap.Config.ARGB_8888)
    }

    private fun gradeLutColor(filmStockId: String, red: Float, green: Float, blue: Float): FloatArray {
        val id = filmStockId.lowercase(Locale.US)
        var r = red
        var g = green
        var b = blue
        var saturation = 1.04f
        var contrast = 0.03f
        var lift = 0.0f

        when {
            "portra" in id -> {
                r += 0.018f
                g += 0.006f
                b -= 0.012f
                saturation = 0.98f
                contrast = -0.015f
                lift = 0.01f
            }
            "gold" in id || "ultramax" in id || "kodak" in id -> {
                r += 0.028f
                g += 0.01f
                b -= 0.025f
                saturation = 1.08f
                contrast = 0.045f
            }
            "cinestill" in id || "800t" in id -> {
                r += smooth01(red) * 0.035f
                g -= 0.006f
                b += (1f - smooth01(red)) * 0.026f
                saturation = 1.06f
                contrast = 0.035f
            }
            "fuji" in id || "superia" in id || "provia" in id -> {
                r -= 0.012f
                g += 0.02f
                b += 0.014f
                saturation = 1.09f
                contrast = 0.04f
            }
            "velvia" in id -> {
                r += 0.006f
                g += 0.024f
                b += 0.006f
                saturation = 1.18f
                contrast = 0.07f
            }
            "ilford" in id || "delta" in id || "tri" in id || "bw" in id -> {
                val luma = red * 0.299f + green * 0.587f + blue * 0.114f
                r = luma * 1.02f
                g = luma
                b = luma * 0.96f
                saturation = 0f
                contrast = 0.08f
            }
            "expired" in id -> {
                r += 0.026f
                g -= 0.012f
                b += 0.02f
                saturation = 0.82f
                contrast = -0.035f
                lift = 0.03f
            }
            "lomo" in id || "cross" in id -> {
                r += 0.03f
                g += 0.018f
                b -= 0.018f
                saturation = 1.2f
                contrast = 0.09f
            }
            "polaroid" in id -> {
                r += 0.022f
                g += 0.01f
                b -= 0.006f
                saturation = 0.9f
                contrast = -0.02f
                lift = 0.025f
            }
        }

        r = tone(r, contrast, lift)
        g = tone(g, contrast, lift)
        b = tone(b, contrast, lift)
        return saturate(r, g, b, saturation)
    }

    private fun tone(value: Float, contrast: Float, lift: Float): Float {
        return clamp01((value - 0.5f) * (1f + contrast) + 0.5f + lift * (1f - value))
    }

    private fun saturate(red: Float, green: Float, blue: Float, amount: Float): FloatArray {
        val luma = red * 0.299f + green * 0.587f + blue * 0.114f
        return floatArrayOf(
            luma + (red - luma) * amount,
            luma + (green - luma) * amount,
            luma + (blue - luma) * amount,
        )
    }

    private fun smooth01(value: Float): Float {
        val x = clamp01(value)
        return x * x * (3f - 2f * x)
    }

    private fun clamp01(value: Float): Float = value.coerceIn(0f, 1f)

    private fun decodeAsset(assetPath: String): Bitmap? {
        val key = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(assetPath)
        return context.assets.open(key).use { BitmapFactory.decodeStream(it) }
    }

    private fun newTexture(): Int {
        val ids = IntArray(1)
        GLES20.glGenTextures(1, ids, 0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, ids[0])
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
        return ids[0]
    }

    private fun uploadTexture(texture: Int, bitmap: Bitmap) {
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texture)
        GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, bitmap, 0)
    }

    private fun bindTexture(name: String, texture: Int, unit: Int) {
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0 + unit)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texture)
        GLES20.glUniform1i(GLES20.glGetUniformLocation(program, name), unit)
    }

    private fun setUniforms(request: Map<String, Any?>, width: Int, height: Int) {
        fun f(name: String) = (request[name] as Number).toFloat()
        fun color(name: String): FloatArray {
            val argb = (request[name] as Number).toInt()
            return floatArrayOf(
                ((argb shr 16) and 255) / 255f,
                ((argb shr 8) and 255) / 255f,
                (argb and 255) / 255f,
            )
        }
        @Suppress("UNCHECKED_CAST")
        val matrix = request["colorMatrix"] as List<Number>
        val identity = floatArrayOf(
            1f, 0f, 0f, 0f,
            0f, 1f, 0f, 0f,
            0f, 0f, 1f, 0f,
            0f, 0f, 0f, 1f,
        )
        GLES20.glUniformMatrix4fv(GLES20.glGetUniformLocation(program, "uTransformationMatrix"), 1, false, identity, 0)
        GLES20.glUniformMatrix4fv(GLES20.glGetUniformLocation(program, "uTexTransformationMatrix"), 1, false, identity, 0)
        GLES20.glUniform2f(GLES20.glGetUniformLocation(program, "uSize"), width.toFloat(), height.toFloat())
        GLES20.glUniform1f(GLES20.glGetUniformLocation(program, "uTemperature"), f("temperature"))
        GLES20.glUniform1f(GLES20.glGetUniformLocation(program, "uSaturation"), f("saturation"))
        GLES20.glUniform1f(GLES20.glGetUniformLocation(program, "uContrast"), f("contrast"))
        GLES20.glUniform1f(GLES20.glGetUniformLocation(program, "uBrightness"), f("brightness"))
        GLES20.glUniform1f(GLES20.glGetUniformLocation(program, "uShadowLift"), f("shadowLift"))
        GLES20.glUniform1f(GLES20.glGetUniformLocation(program, "uTintStrength"), f("tintStrength"))
        GLES20.glUniform1f(GLES20.glGetUniformLocation(program, "uRedGamma"), f("redGamma"))
        GLES20.glUniform1f(GLES20.glGetUniformLocation(program, "uGreenGamma"), f("greenGamma"))
        GLES20.glUniform1f(GLES20.glGetUniformLocation(program, "uBlueGamma"), f("blueGamma"))
        GLES20.glUniform3fv(GLES20.glGetUniformLocation(program, "uHighlightTint"), 1, color("highlightTintArgb"), 0)
        GLES20.glUniform3fv(GLES20.glGetUniformLocation(program, "uShadowTint"), 1, color("shadowTintArgb"), 0)
        GLES20.glUniform1f(GLES20.glGetUniformLocation(program, "uGrain"), f("grain"))
        GLES20.glUniform1f(GLES20.glGetUniformLocation(program, "uGrainSize"), f("grainSize"))
        GLES20.glUniform1f(GLES20.glGetUniformLocation(program, "uGrainColored"), if (request["coloredGrain"] == true) 1f else 0f)
        GLES20.glUniform1f(GLES20.glGetUniformLocation(program, "uVignette"), f("vignette"))
        GLES20.glUniform1f(GLES20.glGetUniformLocation(program, "uScratch"), f("scratchLevel"))
        GLES20.glUniform1f(GLES20.glGetUniformLocation(program, "uLeak"), f("leakStrength"))
        GLES20.glUniform1f(GLES20.glGetUniformLocation(program, "uDust"), f("dustStrength"))
        GLES20.glUniform1f(GLES20.glGetUniformLocation(program, "uHalation"), f("halation"))
        GLES20.glUniform1f(GLES20.glGetUniformLocation(program, "uArtifactSeed"), f("artifactSeed"))
        GLES20.glUniform1f(GLES20.glGetUniformLocation(program, "uLutStrength"), 0.42f)
        GLES20.glUniform3f(GLES20.glGetUniformLocation(program, "uColorMatrixRow0"), matrix[0].toFloat(), matrix[1].toFloat(), matrix[2].toFloat())
        GLES20.glUniform3f(GLES20.glGetUniformLocation(program, "uColorMatrixRow1"), matrix[3].toFloat(), matrix[4].toFloat(), matrix[5].toFloat())
        GLES20.glUniform3f(GLES20.glGetUniformLocation(program, "uColorMatrixRow2"), matrix[6].toFloat(), matrix[7].toFloat(), matrix[8].toFloat())
        GLES20.glUniform3fv(GLES20.glGetUniformLocation(program, "uGlareTint"), 1, color("glareTintArgb"), 0)
        GLES20.glUniform1f(GLES20.glGetUniformLocation(program, "uBorderGlare"), f("borderGlare"))
        GLES20.glUniform1f(GLES20.glGetUniformLocation(program, "uGlareWidth"), f("glareWidth"))
        GLES20.glUniform1f(GLES20.glGetUniformLocation(program, "uGlareAngle"), f("glareAngle"))
        GLES20.glUniform2f(
            GLES20.glGetUniformLocation(program, "uCaOffset"),
            f("chromaticAberrationX"),
            f("chromaticAberrationY"),
        )
    }

    private fun bindVertices() {
        vertices.position(0)
        val location = GLES20.glGetAttribLocation(program, "aFramePosition")
        GLES20.glEnableVertexAttribArray(location)
        GLES20.glVertexAttribPointer(location, 2, GLES20.GL_FLOAT, false, 0, vertices)
    }

    private fun rgbaToBitmap(buffer: ByteBuffer, width: Int, height: Int): Bitmap {
        buffer.rewind()
        val rgba = ByteArray(width * height * 4)
        buffer.get(rgba)
        val pixels = IntArray(width * height)
        for (y in 0 until height) {
            val srcRow = y * width * 4
            val dstRow = y * width
            for (x in 0 until width) {
                val i = srcRow + x * 4
                pixels[dstRow + x] = Color.argb(
                    rgba[i + 3].toInt() and 255,
                    rgba[i].toInt() and 255,
                    rgba[i + 1].toInt() and 255,
                    rgba[i + 2].toInt() and 255,
                )
            }
        }
        val output = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        output.setPixels(pixels, 0, width, 0, 0, width, height)
        return output
    }

    private fun checkGl(label: String) {
        val error = GLES20.glGetError()
        check(error == GLES20.GL_NO_ERROR) { "$label GL error: $error" }
    }

    fun release() {
        if (display == EGL14.EGL_NO_DISPLAY) return
        if (sourceTex != 0) GLES20.glDeleteTextures(1, intArrayOf(sourceTex), 0)
        if (transparentTex != 0) GLES20.glDeleteTextures(1, intArrayOf(transparentTex), 0)
        filmLutTexture?.let { GLES20.glDeleteTextures(1, intArrayOf(it.texture), 0) }
        overlayTextures.values.forEach { GLES20.glDeleteTextures(1, intArrayOf(it.texture), 0) }
        if (program != 0) GLES20.glDeleteProgram(program)
        EGL14.eglMakeCurrent(
            display,
            EGL14.EGL_NO_SURFACE,
            EGL14.EGL_NO_SURFACE,
            EGL14.EGL_NO_CONTEXT,
        )
        if (surface != EGL14.EGL_NO_SURFACE) EGL14.eglDestroySurface(display, surface)
        if (eglContext != EGL14.EGL_NO_CONTEXT) EGL14.eglDestroyContext(display, eglContext)
        EGL14.eglTerminate(display)
        display = EGL14.EGL_NO_DISPLAY
        eglContext = EGL14.EGL_NO_CONTEXT
        surface = EGL14.EGL_NO_SURFACE
        program = 0
        sourceTex = 0
        transparentTex = 0
        filmLutTexture = null
        overlayTextures.clear()
    }

    private data class TextureEntry(val key: String, val texture: Int)
}
