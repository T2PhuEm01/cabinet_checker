package com.phuem.cabinet_checker

import android.app.Activity
import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ClipData
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "camera_chooser"
        private const val EXPORT_NOTIFICATION_CHANNEL = "cabinet_checker/export_notification"
        private const val REQUEST_CAMERA_CHOOSER = 1001
        private const val REQUEST_CAMERA_PERMISSION = 1002
        private const val TAG = "CabinetCameraChooser"
        private const val EXPORT_NOTIFICATION_CHANNEL_ID = "cabcheck_export_channel"
        private const val EXPORT_NOTIFICATION_ID = 3101
    }

    private var pendingResult: MethodChannel.Result? = null
    private var pendingCaptureAfterPermission: MethodChannel.Result? = null
    private var photoUri: Uri? = null
    private var photoPath: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "captureWithChooser" -> {
                        captureWithChooser(result)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, EXPORT_NOTIFICATION_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "showExportNotification", "updateExportNotification" -> {
                        val title = call.argument<String>("title") ?: "CabCheck"
                        val text = call.argument<String>("text") ?: "Đang xuất dữ liệu..."
                        val progress = call.argument<Int>("progress")
                        val indeterminate = call.argument<Boolean>("indeterminate") ?: false
                        val shown = showOrUpdateExportNotification(
                            title = title,
                            text = text,
                            progress = progress,
                            indeterminate = indeterminate
                        )
                        result.success(shown)
                    }

                    "cancelExportNotification" -> {
                        cancelExportNotification()
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun showOrUpdateExportNotification(
        title: String,
        text: String,
        progress: Int?,
        indeterminate: Boolean,
    ): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val granted = ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
            if (!granted) {
                Log.w(TAG, "POST_NOTIFICATIONS not granted, skip export notification")
                return false
            }
        }

        ensureExportNotificationChannel()

        val safeProgress = progress?.coerceIn(0, 100)
        val builder = NotificationCompat.Builder(this, EXPORT_NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_upload)
            .setContentTitle(title)
            .setContentText(text)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOnlyAlertOnce(true)
            .setOngoing(true)
            .setAutoCancel(false)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .setSilent(true)

        if (indeterminate) {
            builder.setProgress(100, 0, true)
        } else if (safeProgress != null) {
            builder.setProgress(100, safeProgress, false)
        } else {
            builder.setProgress(0, 0, false)
        }

        NotificationManagerCompat.from(this).notify(EXPORT_NOTIFICATION_ID, builder.build())
        return true
    }

    private fun cancelExportNotification() {
        NotificationManagerCompat.from(this).cancel(EXPORT_NOTIFICATION_ID)
    }

    private fun ensureExportNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager = getSystemService(NotificationManager::class.java) ?: return
        val existing = manager.getNotificationChannel(EXPORT_NOTIFICATION_CHANNEL_ID)
        if (existing != null) return

        val channel = NotificationChannel(
            EXPORT_NOTIFICATION_CHANNEL_ID,
            "CabCheck Export",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Thông báo tiến trình xuất dữ liệu nền"
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    private fun captureWithChooser(result: MethodChannel.Result) {
        if (!hasCameraPermission()) {
            Log.w(TAG, "camera permission missing, requesting runtime permission")
            pendingCaptureAfterPermission = result
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.CAMERA),
                REQUEST_CAMERA_PERMISSION
            )
            return
        }

        openCameraWithChooser(result)
    }

    private fun hasCameraPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun openCameraWithChooser(result: MethodChannel.Result) {
        Log.i(TAG, "captureWithChooser called")
        // Tạo file ảnh tạm thời
        val timeStamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
        val storageDir = getExternalFilesDir(Environment.DIRECTORY_PICTURES)
            ?: cacheDir
        val imageFile = File(storageDir, "cabinet_${timeStamp}.jpg")
        imageFile.parentFile?.mkdirs()
        Log.i(TAG, "temp image path=${imageFile.absolutePath}")

        val uri = FileProvider.getUriForFile(
            this,
            "${applicationContext.packageName}.fileprovider",
            imageFile
        )
        photoUri = uri
        photoPath = imageFile.absolutePath
        Log.i(TAG, "file provider uri=$uri")

        // Intent chụp ảnh với output URI
        val cameraIntent = Intent(MediaStore.ACTION_IMAGE_CAPTURE).apply {
            putExtra(MediaStore.EXTRA_OUTPUT, uri)
            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            clipData = ClipData.newUri(contentResolver, "cabinet_image", uri)
        }

        // Cấp quyền URI cho toàn bộ camera app resolve được (quan trọng với một số ROM).
        val resolved = packageManager.queryIntentActivities(cameraIntent, 0)
        Log.i(TAG, "resolved camera apps count=${resolved.size}")
        for (resInfo in resolved) {
            val packageName = resInfo.activityInfo.packageName
            Log.i(TAG, "grant uri permission to package=$packageName")
            grantUriPermission(
                packageName,
                uri,
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_READ_URI_PERMISSION
            )
        }

        if (resolved.isNotEmpty()) {
            pendingResult = result
            try {
                @Suppress("DEPRECATION")
                if (resolved.size == 1) {
                    // Một số ROM (ví dụ OPPO) hoạt động ổn định hơn khi mở trực tiếp camera app.
                    val only = resolved.first().activityInfo
                    val directIntent = Intent(cameraIntent).apply {
                        setClassName(only.packageName, only.name)
                    }
                    Log.i(TAG, "start direct camera activity package=${only.packageName} class=${only.name}")
                    startActivityForResult(directIntent, REQUEST_CAMERA_CHOOSER)
                } else {
                    val chooser = Intent.createChooser(cameraIntent, "Chọn ứng dụng camera")
                    Log.i(TAG, "start chooser activity")
                    startActivityForResult(chooser, REQUEST_CAMERA_CHOOSER)
                }
            } catch (e: Exception) {
                pendingResult = null
                Log.e(TAG, "start chooser failed", e)
                result.error("OPEN_CHOOSER_FAILED", e.message, null)
            }
        } else {
            Log.e(TAG, "no camera app resolved")
            result.error("NO_CAMERA_APP", "Không tìm thấy ứng dụng camera", null)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_CAMERA_PERMISSION) {
            val result = pendingCaptureAfterPermission
            pendingCaptureAfterPermission = null
            if (result == null) return

            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            if (granted) {
                Log.i(TAG, "camera permission granted, retry opening camera")
                openCameraWithChooser(result)
            } else {
                Log.e(TAG, "camera permission denied by user")
                result.error(
                    "CAMERA_PERMISSION_DENIED",
                    "Ứng dụng chưa được cấp quyền camera.",
                    null
                )
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == REQUEST_CAMERA_CHOOSER) {
            Log.i(TAG, "onActivityResult resultCode=$resultCode data=$data")
            val currentResult = pendingResult
            pendingResult = null

            val path = photoPath
            val file = if (path != null) File(path) else null
            val fileExists = file != null && file.exists() && file.length() > 0

            // Ưu tiên kiểm tra file thực tế: một số camera trả RESULT_CANCELED nhưng vẫn lưu ảnh.
            if (fileExists) {
                Log.i(TAG, "capture success path=$path size=${file!!.length()} (resultCode=$resultCode)")
                currentResult?.success(path)
            } else if (resultCode == Activity.RESULT_OK) {
                Log.e(TAG, "result OK nhưng file rỗng path=$path")
                currentResult?.error("EMPTY_FILE", "Ảnh không được lưu", null)
            } else {
                Log.w(TAG, "capture cancelled or blocked by external camera app")
                currentResult?.error(
                    "CAPTURE_CANCELED",
                    "Không nhận được ảnh từ camera (đã hủy hoặc app camera không trả kết quả).",
                    null
                )
            }
            photoUri = null
            photoPath = null
        }
    }
}
