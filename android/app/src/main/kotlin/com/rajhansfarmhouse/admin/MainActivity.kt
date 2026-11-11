package com.rajhansfarmhouse.admin

import android.Manifest
import android.app.Activity
import android.content.ClipData
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.graphics.pdf.PdfDocument
import android.os.Handler
import android.os.Looper
import android.provider.CallLog
import android.provider.ContactsContract
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.text.NumberFormat
import java.util.Locale
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var callResult: MethodChannel.Result? = null
    private var contactResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "com.rajhansfarmhouse.admin/device").setMethodCallHandler { call, result ->
            when (call.method) {
                "getTheme" -> result.success(getSharedPreferences("rajhans", MODE_PRIVATE).getString("theme", "dark"))
                "setTheme" -> {
                    val value = call.argument<String>("value")
                    if (value !in listOf("dark", "light", "system")) result.error("invalid-theme", "Choose a valid theme.", null)
                    else executor.execute {
                        val saved = getSharedPreferences("rajhans", MODE_PRIVATE).edit().putString("theme", value).commit()
                        main.post { if (saved) result.success(null) else result.error("save-failed", "Unable to save the theme.", null) }
                    }
                }
                "recentCalls" -> {
                    if (callResult != null) result.error("busy", "The call picker is already open.", null)
                    else if (checkSelfPermission(Manifest.permission.READ_CALL_LOG) == PackageManager.PERMISSION_GRANTED) readCalls(result)
                    else { callResult = result; requestPermissions(arrayOf(Manifest.permission.READ_CALL_LOG), 702) }
                }
                "callLogAllowed" -> result.success(checkSelfPermission(Manifest.permission.READ_CALL_LOG) == PackageManager.PERMISSION_GRANTED)
                "pickContact" -> {
                    if (contactResult != null) result.error("busy", "The contact picker is already open.", null)
                    else {
                        contactResult = result
                        try { startActivityForResult(Intent(Intent.ACTION_PICK, ContactsContract.CommonDataKinds.Phone.CONTENT_URI), 703) }
                        catch (_: Exception) { contactResult = null; result.error("contacts-unavailable", "No contact picker is available. Please type the number.", null) }
                    }
                }
                "receipt" -> {
                    val arguments = call.arguments as? Map<*, *>
                    if (arguments == null) result.error("invalid-bill", "Booking details are missing.", null)
                    else executor.execute {
                        try { val file = buildReceipt(arguments); main.post { shareReceipt(file, arguments, result) } }
                        catch (_: Exception) { main.post { result.error("pdf-failed", "The receipt could not be generated. Please try again.", null) } }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 702) {
            val result = callResult ?: return
            callResult = null
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) readCalls(result)
            else result.error("permission-denied", "Call-log access is not allowed on this phone. Choose Contacts or enter the number manually.", null)
        }
    }
    private fun readCalls(result: MethodChannel.Result) {
        executor.execute {
            try {
                val records = mutableListOf<Map<String, Any>>()
                val seen = mutableSetOf<String>()
                contentResolver.query(CallLog.Calls.CONTENT_URI, arrayOf(CallLog.Calls.NUMBER, CallLog.Calls.CACHED_NAME, CallLog.Calls.DATE), null, null, "${CallLog.Calls.DATE} DESC")?.use { cursor ->
                    while (cursor.moveToNext() && records.size < 100) {
                        val number = cursor.getString(0)?.trim().orEmpty()
                        if (number.count { it.isDigit() } >= 8 && seen.add(number.filter { it.isDigit() })) {
                            records.add(mapOf("number" to number.take(20), "name" to cursor.getString(1).orEmpty().take(120), "date" to cursor.getLong(2)))
                        }
                    }
                }
                main.post { result.success(records) }
            } catch (_: SecurityException) {
                main.post { result.error("permission-denied", "Android blocked call-log access. Choose Contacts or enter the number manually.", null) }
            } catch (_: Exception) { main.post { result.error("calls-unavailable", "Recent calls could not be loaded. Choose Contacts instead.", null) } }
        }
    }
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 703) {
            val result = contactResult ?: return
            contactResult = null
            val uri = data?.data
            if (resultCode != Activity.RESULT_OK || uri == null) { result.success(null); return }
            executor.execute {
                try {
                    var contact: Map<String, String>? = null
                    contentResolver.query(uri, arrayOf(ContactsContract.CommonDataKinds.Phone.NUMBER, ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME), null, null, null)?.use { cursor ->
                        if (cursor.moveToFirst()) contact = mapOf("number" to cursor.getString(0).orEmpty().take(20), "name" to cursor.getString(1).orEmpty().take(120))
                    }
                    main.post { result.success(contact) }
                } catch (_: Exception) { main.post { result.error("contacts-unavailable", "The selected contact could not be read. Please type the number.", null) } }
            }
        }
    }
    private fun buildReceipt(data: Map<*, *>): File {
        val directory = File(cacheDir, "receipts").apply { mkdirs() }
        val safeId = data["id"].toString().replace(Regex("[^A-Za-z0-9]"), "").take(24)
        require(safeId.isNotEmpty())
        val file = File(directory, "Rajhans-$safeId-${System.currentTimeMillis()}.pdf")
        val pdf = PdfDocument()
        try {
            val page = pdf.startPage(PdfDocument.PageInfo.Builder(595, 842, 1).create())
            val canvas = page.canvas
            val paint = Paint(Paint.ANTI_ALIAS_FLAG)
            paint.color = Color.rgb(16, 21, 37); canvas.drawRect(0f, 0f, 595f, 148f, paint)
            fun line(text: String, x: Float, y: Float, size: Float = 12f, bold: Boolean = false, color: Int = Color.rgb(35, 42, 60)) {
                paint.color = color; paint.textSize = size; paint.typeface = if (bold) Typeface.create("sans-serif", Typeface.BOLD) else Typeface.create("sans-serif", Typeface.NORMAL)
                canvas.drawText(text, x, y, paint)
            }
            line("RAJHANS FARMHOUSE", 36f, 60f, 25f, true, Color.WHITE)
            line("BOOKING RECEIPT / BILL", 36f, 94f, 13f, true, Color.rgb(183, 167, 255))
            line("Booking: $safeId", 36f, 122f, 10f, false, Color.WHITE)
            var y = 190f
            fun row(label: String, value: String) {
                line(label, 36f, y, 11f, false, Color.GRAY)
                paint.textSize = 13f; paint.typeface = Typeface.DEFAULT_BOLD
                var remaining = value
                var cursorY = y
                while (remaining.isNotEmpty()) {
                    val length = paint.breakText(remaining, true, 330f, null).coerceAtLeast(1)
                    line(remaining.take(length), 220f, cursorY, 13f, true)
                    remaining = remaining.drop(length); cursorY += 19f
                }
                y = maxOf(y + 35f, cursorY + 16f)
            }
            row("Customer", data["guestName"].toString())
            row("Phone", data["phone"].toString())
            row("Status", data["status"].toString())
            row("Check-in", "${data["checkIn"]} · 11:00 AM")
            row("Check-out", "${data["checkOut"]} · 11:00 AM")
            row("Stay / guests", "${data["nights"]} nights / ${data["guestCount"]} guests")
            val total = (data["totalPaise"] as Number).toLong()
            val paid = (data["paidPaise"] as? Number)?.toLong() ?: 0L
            val format = NumberFormat.getCurrencyInstance(Locale.forLanguageTag("en-IN"))
            fun currency(value: Long) = format.format(java.math.BigDecimal.valueOf(value, 2))
            paint.color = Color.rgb(239, 236, 255); canvas.drawRoundRect(32f, y - 6f, 563f, y + 126f, 12f, 12f, paint)
            y += 20f
            row("Booking amount", currency(total)); row("Payments recorded", currency(paid)); row("Balance due", currency(total - paid))
            line("All dates and times use Asia/Kolkata.", 36f, 733f, 10f)
            line("This bill confirms a booking, not receipt of payment.", 36f, 754f, 10f)
            line("Thank you for choosing Rajhans Farmhouse.", 36f, 791f, 12f, true)
            pdf.finishPage(page)
            file.outputStream().use { pdf.writeTo(it) }
        } finally { pdf.close() }
        directory.listFiles()?.filter { it.extension == "pdf" && it != file }?.sortedByDescending { it.lastModified() }?.drop(29)?.forEach { it.delete() }
        return file
    }
    private fun shareReceipt(file: File, data: Map<*, *>, result: MethodChannel.Result) {
        val uri = FileProvider.getUriForFile(this, "$packageName.receipts", file)
        val action = data["action"].toString()
        try {
            if (action == "view") {
                val view = Intent(Intent.ACTION_VIEW).setDataAndType(uri, "application/pdf").addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                if (view.resolveActivity(packageManager) != null) { startActivity(view); result.success(null); return }
            }
            val share = Intent(Intent.ACTION_SEND).setType("application/pdf").putExtra(Intent.EXTRA_STREAM, uri)
                .putExtra(Intent.EXTRA_TEXT, "Rajhans Farmhouse booking bill for ${data["guestName"]} (${data["phone"]}). Booking ${data["id"]}.")
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            share.clipData = ClipData.newRawUri("Booking receipt", uri)
            if (action == "whatsapp") {
                val installed = listOf("com.whatsapp", "com.whatsapp.w4b").firstOrNull { packageManager.getLaunchIntentForPackage(it) != null }
                if (installed == null) { result.error("whatsapp-missing", "WhatsApp is not installed. Use Share PDF to send the receipt another way.", null); return }
                share.setPackage(installed)
                var number = data["phone"].toString().filter { it in '0'..'9' }
                if (number.length == 11 && number.startsWith("0")) number = number.drop(1)
                if (number.length == 10) number = "91$number"
                // WhatsApp may honor a chat hint; the recipient selector remains
                // the supported fallback. The user always confirms Send there.
                if (number.length in 8..15) share.putExtra("jid", "$number@s.whatsapp.net")
                startActivity(share)
            } else startActivity(Intent.createChooser(share, "Share booking receipt"))
            result.success(null)
        } catch (_: Exception) { result.error("share-failed", "The receipt is ready, but no compatible app could open it. Try Share PDF.", null) }
    }
    override fun onDestroy() { executor.shutdown(); super.onDestroy() }
}
