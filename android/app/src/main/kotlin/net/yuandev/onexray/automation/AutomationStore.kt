package net.yuandev.onexray.automation

import android.content.Context
import android.util.Base64
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import net.yuandev.onexray.pigeon.JsonTool
import java.io.File
import java.io.FileOutputStream
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.security.MessageDigest
import java.security.SecureRandom

@Serializable
data class AutomationSettings(val enabled: Boolean = false, val token: String? = null)

/** One main-process writer; every native request reads the atomically published file. */
class AutomationStore(private val directory: File) {
    constructor(context: Context) : this(context.noBackupFilesDir)

    private val settingsFile get() = File(directory, "vpn-automation.json")
    private val blockedFile get() = File(directory, "vpn-automation.blocked")

    fun read(): AutomationSettings = try {
        if (!settingsFile.isFile || settingsFile.length() > 1024) AutomationSettings()
        else JsonTool.json.decodeFromString<AutomationSettings>(settingsFile.readText()).let {
            if (it.token != null && tokenPattern.matches(it.token)) it else AutomationSettings()
        }
    } catch (_: Exception) {
        // Never include the serialized settings (or its token) in diagnostics.
        AutomationSettings()
    }

    fun authorized(token: Any?): Boolean {
        if (token !is String || token.length != 46) return false
        val settings = read()
        return settings.enabled && settings.token != null && MessageDigest.isEqual(
            settings.token.toByteArray(Charsets.US_ASCII), token.toByteArray(Charsets.US_ASCII),
        )
    }

    fun setEnabled(enabled: Boolean): AutomationSettings = synchronized(writer) {
        check(!startBlocked) { "App data is being cleared or restored. Try again when it finishes." }
        val current = read()
        publish(current.copy(enabled = enabled, token = current.token ?: if (enabled) newToken() else null))
    }

    fun resetToken(): AutomationSettings = synchronized(writer) {
        check(!startBlocked) { "App data is being cleared or restored. Try again when it finishes." }
        publish(read().copy(token = newToken()))
    }

    val startBlocked: Boolean get() = blockedFile.exists()

    fun setStartBlocked(blocked: Boolean) = synchronized(writer) {
        if (blocked) writeAtomically(blockedFile, "blocked")
        else check(!blockedFile.exists() || blockedFile.delete()) { "Unable to resume VPN automation." }
    }

    fun clear() = synchronized(writer) {
        check(!settingsFile.exists() || settingsFile.delete()) { "Unable to clear VPN automation authorization." }
    }

    private fun publish(settings: AutomationSettings): AutomationSettings {
        writeAtomically(settingsFile, JsonTool.json.encodeToString(settings))
        return settings
    }

    private fun writeAtomically(file: File, text: String) {
        check(directory.isDirectory || directory.mkdirs()) { "Unable to open VPN automation settings." }
        val pending = File(directory, "${file.name}.new")
        try {
            FileOutputStream(pending).use { output ->
                output.write(text.toByteArray(Charsets.UTF_8))
                output.fd.sync()
            }
            // Readers open only the published file, never AtomicFile recovery or a partial write.
            Files.move(pending.toPath(), file.toPath(), StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING)
        } finally {
            pending.delete()
        }
    }

    private fun newToken(): String = "ox_" + Base64.encodeToString(
        ByteArray(32).also { SecureRandom().nextBytes(it) },
        Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING,
    )

    companion object {
        private val writer = Any()
        private val tokenPattern = Regex("ox_[A-Za-z0-9_-]{43}")
    }
}
