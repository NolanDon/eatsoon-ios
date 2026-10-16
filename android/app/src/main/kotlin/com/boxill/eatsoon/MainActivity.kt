package com.boxill.eatsoon

import android.Manifest
import android.app.*
import android.content.*
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.os.SystemClock
import android.util.Base64
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.StandardIntegrityManager.PrepareIntegrityTokenRequest
import com.google.android.play.core.integrity.StandardIntegrityManager.StandardIntegrityTokenProvider
import com.google.android.play.core.integrity.StandardIntegrityManager.StandardIntegrityTokenRequest
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.segmentation.subject.SubjectSegmentation
import com.google.mlkit.vision.segmentation.subject.SubjectSegmenterOptions
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.security.SecureRandom
import java.util.Calendar
import java.util.UUID
import java.util.concurrent.Executors

class MainActivity : FlutterFragmentActivity() {
    private var permissionResult: MethodChannel.Result? = null
    private val worker = Executors.newSingleThreadExecutor()
    private val playIntegrityManager by lazy { IntegrityManagerFactory.createStandard(applicationContext) }
    private var playIntegrityProvider: StandardIntegrityTokenProvider? = null
    private var playIntegrityProviderExpiresAt = 0L
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.boxill/android_media").setMethodCallHandler { call, result ->
            when(call.method) {
                "reminderPermission" -> {
                    if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                        if (permissionResult != null) { result.error("busy", "Permission request already open.", null) }
                        else { permissionResult = result; requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 918) }
                    } else result.success(true)
                }
                "clearReminder", "setReminder" -> {
                    val id = call.argument<String>("id") ?: ""
                    val intent = Intent(this, ReminderReceiver::class.java).apply {
                        putExtra("title", call.argument<String>("title")); putExtra("body", call.argument<String>("body")); putExtra("id", id.hashCode())
                    }
                    val pending = PendingIntent.getBroadcast(this, id.hashCode(), intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                    val alarm = getSystemService(ALARM_SERVICE) as AlarmManager
                    alarm.cancel(pending)
                    if (call.method == "clearReminder") result.success(true)
                    else {
                        try {
                            val parts = call.argument<String>("date")!!.split("-").map { it.toInt() }
                            val at = Calendar.getInstance().apply { set(parts[0], parts[1]-1, parts[2], 9, 0, 0); set(Calendar.MILLISECOND, 0) }.timeInMillis
                            if (at > System.currentTimeMillis()) alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
                            result.success(at > System.currentTimeMillis())
                        } catch (_: Exception) { result.error("date", "Check the reminder date.", null) }
                    }
                }
                "cutout" -> {
                    val name = call.argument<String>("file") ?: ""
                    val box = call.argument<List<Number>>("box") ?: emptyList()
                    if (!Regex("^[A-Za-z0-9-]+\\.(jpg|png)$").matches(name) || box.size != 4) result.error("crop", "Check the garment crop.", null)
                    else worker.execute {
                        try {
                            val folder = File(filesDir.parentFile, "app_flutter/V3Media")
                            val source = BitmapFactory.decodeFile(File(folder, name).path) ?: error("Missing photo")
                            val left = (box[1].toDouble()/1000*source.width).toInt().coerceIn(0, source.width-1)
                            val top = (box[0].toDouble()/1000*source.height).toInt().coerceIn(0, source.height-1)
                            val right = (box[3].toDouble()/1000*source.width).toInt().coerceIn(left+1, source.width)
                            val bottom = (box[2].toDouble()/1000*source.height).toInt().coerceIn(top+1, source.height)
                            val crop = Bitmap.createBitmap(source, left, top, right-left, bottom-top)
                            val options = SubjectSegmenterOptions.Builder().enableMultipleSubjects(SubjectSegmenterOptions.SubjectResultOptions.Builder().enableSubjectBitmap().build()).build()
                            val segmenter = SubjectSegmentation.getClient(options)
                            segmenter.process(InputImage.fromBitmap(crop, 0))
                                .addOnSuccessListener { output ->
                                    try {
                                        val selected = output.subjects.minByOrNull { subject ->
                                            val dx = (subject.startX + subject.width/2.0)/crop.width - 0.5
                                            val dy = (subject.startY + subject.height/2.0)/crop.height - 0.5
                                            dx*dx + dy*dy
                                        }?.bitmap ?: error("No foreground garment found")
                                        val out = UUID.randomUUID().toString()+".png"
                                        File(folder, out).outputStream().use { selected.compress(Bitmap.CompressFormat.PNG, 100, it) }
                                        result.success(out)
                                    } catch (_: Exception) { result.error("cutout", "Could not isolate this garment. Try a plain background.", null) }
                                    finally { segmenter.close() }
                                }.addOnFailureListener { segmenter.close(); result.error("cutout", "Background removal needs Google Play services and its downloaded model. Try again when online.", null) }
                        } catch (_: Exception) { runOnUiThread { result.error("crop", "Check the garment photo.", null) } }
                    }
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.boxill/companion").setMethodCallHandler { call, result ->
            when (call.method) {
                "attestKey" -> result.success(playIntegrityKeyId())
                "forgetAttestKey" -> {
                    getSharedPreferences("play_integrity", MODE_PRIVATE).edit().remove("key_id").apply()
                    result.success(null)
                }
                "assert" -> {
                    val data = call.argument<String>("data")
                    val projectNumber = BuildConfig.PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER
                    if (data == null || projectNumber <= 0L) {
                        result.error("play_integrity_config", "Android device verification is not configured.", null)
                    } else {
                        val requestHash = Base64.encodeToString(
                            MessageDigest.getInstance("SHA-256").digest(data.toByteArray(Charsets.UTF_8)),
                            Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING
                        )
                        requestPlayIntegrityToken(projectNumber, requestHash, result)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun playIntegrityKeyId(): String {
        val preferences = getSharedPreferences("play_integrity", MODE_PRIVATE)
        val existing = preferences.getString("key_id", null)
        if (existing != null && Regex("^[A-Za-z0-9+/]{43}=$").matches(existing)) return existing
        val bytes = ByteArray(32)
        SecureRandom().nextBytes(bytes)
        val keyId = Base64.encodeToString(bytes, Base64.NO_WRAP)
        preferences.edit().putString("key_id", keyId).apply()
        return keyId
    }

    private fun requestPlayIntegrityToken(
        projectNumber: Long,
        requestHash: String,
        result: MethodChannel.Result,
    ) {
        val provider = playIntegrityProvider
        if (provider != null && SystemClock.elapsedRealtime() < playIntegrityProviderExpiresAt) {
            requestPlayIntegrityToken(provider, requestHash, result)
            return
        }
        playIntegrityProvider = null
        playIntegrityManager.prepareIntegrityToken(
            PrepareIntegrityTokenRequest.builder().setCloudProjectNumber(projectNumber).build()
        ).addOnSuccessListener { preparedProvider ->
            playIntegrityProvider = preparedProvider
            playIntegrityProviderExpiresAt = SystemClock.elapsedRealtime() + 50 * 60_000L
            requestPlayIntegrityToken(preparedProvider, requestHash, result)
        }.addOnFailureListener {
            result.error("play_integrity", "Could not prepare Android device verification. Try again later.", null)
        }
    }

    private fun requestPlayIntegrityToken(
        provider: StandardIntegrityTokenProvider,
        requestHash: String,
        result: MethodChannel.Result,
    ) {
        provider.request(
            StandardIntegrityTokenRequest.builder().setRequestHash(requestHash).build()
        ).addOnSuccessListener { response ->
            result.success(response.token())
        }.addOnFailureListener {
            if (playIntegrityProvider === provider) {
                playIntegrityProvider = null
                playIntegrityProviderExpiresAt = 0L
            }
            result.error("play_integrity", "Could not verify this Android device. Try again later.", null)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 918) { permissionResult?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED); permissionResult = null }
    }
}

class ReminderReceiver : android.content.BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val notifications = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = "collection_dates"
        notifications.createNotificationChannel(NotificationChannel(channel, "Saved date reminders", NotificationManager.IMPORTANCE_DEFAULT))
        if (Build.VERSION.SDK_INT >= 33 && context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return
        val open = PendingIntent.getActivity(context, 0, context.packageManager.getLaunchIntentForPackage(context.packageName), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val notification = Notification.Builder(context, channel).setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(intent.getStringExtra("title")).setContentText(intent.getStringExtra("body"))
            .setContentIntent(open).setAutoCancel(true).build()
        notifications.notify(intent.getIntExtra("id", 0), notification)
    }
}
