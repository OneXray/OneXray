package net.yuandev.onexray.pigeon

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import androidx.activity.result.contract.ActivityResultContracts
import androidx.fragment.app.FragmentActivity
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** One user-selected document, with durable read AND write access. */
class BackupApi(private val activity: FragmentActivity) : BackupHostApi {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val resolver get() = activity.contentResolver
    private var selection: ((Result<BackupLocation?>) -> Unit)? = null
    private val access = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
    private val picker = activity.registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
        val callback = selection ?: return@registerForActivityResult
        selection = null
        if (result.resultCode != Activity.RESULT_OK) {
            callback(Result.success(null))
        } else {
            execute(callback) {
                val intent = result.data ?: error("No backup document was selected")
                val uri = intent.data ?: error("No backup document was selected")
                require(uri.scheme == "content") { "A SAF document is required" }
                require(intent.flags and access == access) { "The provider must allow reading and writing" }
                resolver.takePersistableUriPermission(uri, access)
                requireAccess(uri)
                val name = resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use {
                    if (it.moveToFirst()) it.getString(0) else null
                } ?: "OneXray-backup.json"
                BackupLocation(uri.toString(), name)
            }
        }
    }

    override fun selectBackupFile(create: Boolean, callback: (Result<BackupLocation?>) -> Unit) {
        if (selection != null) {
            callback(Result.failure(IllegalStateException("A document picker is already open")))
            return
        }
        selection = callback
        try {
            picker.launch(Intent(if (create) Intent.ACTION_CREATE_DOCUMENT else Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "application/json"
                addFlags(access or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                if (create) putExtra(Intent.EXTRA_TITLE, "OneXray-backup.json")
            })
        } catch (error: Exception) {
            selection = null
            callback(Result.failure(error))
        }
    }

    private fun requireAccess(uri: Uri) {
        require(uri.scheme == "content" && resolver.persistedUriPermissions.any {
            it.uri == uri && it.isReadPermission && it.isWritePermission
        }) { "Backup file access expired. Select the document again." }
    }

    override fun requireBackupAccess(identifier: String, callback: (Result<Unit>) -> Unit) = execute(callback) {
        requireAccess(Uri.parse(identifier))
    }

    override fun releaseBackupFile(identifier: String, callback: (Result<Unit>) -> Unit) = execute(callback) {
        val uri = Uri.parse(identifier)
        val grant = resolver.persistedUriPermissions.firstOrNull { it.uri == uri }
        if (grant != null) {
            val flags = (if (grant.isReadPermission) Intent.FLAG_GRANT_READ_URI_PERMISSION else 0) or
                (if (grant.isWritePermission) Intent.FLAG_GRANT_WRITE_URI_PERMISSION else 0)
            resolver.releasePersistableUriPermission(uri, flags)
        }
    }

    private fun <T> execute(callback: (Result<T>) -> Unit, action: () -> T) {
        scope.launch {
            val result = withContext(Dispatchers.IO) { runCatching(action) }
            callback(result)
        }
    }

    fun dispose() {
        selection?.invoke(Result.failure(IllegalStateException("Activity was closed")))
        selection = null
        scope.cancel()
    }

}
