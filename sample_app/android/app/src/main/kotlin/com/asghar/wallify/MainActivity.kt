package com.asghar.wallify

import android.app.WallpaperManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.DisplayMetrics
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "wallify/platform")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setWallpaper" -> {
                        val path = call.argument<String>("path")
                        val target = call.argument<String>("target") ?: "both"
                        if (path == null) {
                            result.error("bad_args", "Missing 'path'", null)
                        } else {
                            setWallpaper(path, target, result)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun setWallpaper(path: String, target: String, result: MethodChannel.Result) {
        // Capture on the main thread; window calls are not thread-safe.
        val (screenW, screenH) = screenSize()
        executor.execute {
            try {
                val file = File(path)
                if (!file.exists()) {
                    mainHandler.post { result.error("not_found", "File does not exist: $path", null) }
                    return@execute
                }
                val bitmap = decodeFittedToScreen(path, screenW, screenH)
                    ?: throw IllegalArgumentException("Could not decode image at $path")
                val manager = WallpaperManager.getInstance(applicationContext)
                val flags = when (target) {
                    "home" -> WallpaperManager.FLAG_SYSTEM
                    "lock" -> WallpaperManager.FLAG_LOCK
                    else -> WallpaperManager.FLAG_SYSTEM or WallpaperManager.FLAG_LOCK
                }
                manager.setBitmap(bitmap, null, true, flags)
                bitmap.recycle()
                mainHandler.post { result.success(true) }
            } catch (e: Exception) {
                mainHandler.post { result.error("set_failed", e.message, null) }
            }
        }
    }

    private fun screenSize(): Pair<Int, Int> {
        val wm = getSystemService(WINDOW_SERVICE) as WindowManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val bounds = wm.currentWindowMetrics.bounds
            bounds.width() to bounds.height()
        } else {
            val metrics = DisplayMetrics()
            @Suppress("DEPRECATION")
            wm.defaultDisplay.getRealMetrics(metrics)
            metrics.widthPixels to metrics.heightPixels
        }
    }

    /// Decodes the image already subsampled near screen size (keeps memory
    /// bounded on 40MP photos), then center-crops to the screen's aspect
    /// ratio and scales to exactly screen resolution so the wallpaper fills
    /// the display without stretching.
    private fun decodeFittedToScreen(path: String, screenW: Int, screenH: Int): Bitmap? {
        if (screenW <= 0 || screenH <= 0) return BitmapFactory.decodeFile(path)

        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null

        var sampleSize = 1
        while (bounds.outWidth / (sampleSize * 2) >= screenW &&
            bounds.outHeight / (sampleSize * 2) >= screenH
        ) {
            sampleSize *= 2
        }
        val source = BitmapFactory.decodeFile(
            path,
            BitmapFactory.Options().apply { inSampleSize = sampleSize },
        ) ?: return null

        val screenRatio = screenW.toFloat() / screenH
        val sourceRatio = source.width.toFloat() / source.height
        val cropW: Int
        val cropH: Int
        if (sourceRatio > screenRatio) {
            // Wider than the screen: crop the sides.
            cropH = source.height
            cropW = (source.height * screenRatio).toInt().coerceAtLeast(1)
        } else {
            // Taller than the screen: crop top/bottom.
            cropW = source.width
            cropH = (source.width / screenRatio).toInt().coerceAtLeast(1)
        }
        val x = (source.width - cropW) / 2
        val y = (source.height - cropH) / 2

        val cropped = Bitmap.createBitmap(source, x, y, cropW, cropH)
        if (cropped !== source) source.recycle()

        if (cropped.width == screenW && cropped.height == screenH) return cropped
        val scaled = Bitmap.createScaledBitmap(cropped, screenW, screenH, true)
        if (scaled !== cropped) cropped.recycle()
        return scaled
    }
}
