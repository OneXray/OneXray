package net.yuandev.onexray.vpn

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.IBinder
import android.os.Parcel
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import net.yuandev.onexray.pigeon.VpnStatus

/** Reads the service itself and observes :native death. No last-known VPN state. */
class VpnStatusConnection(
    private val context: Context,
    private val notify: (VpnStatus) -> Unit,
) {
    companion object {
        const val ACTION_BIND = "net.yuandev.onexray.VPN_STATUS_BIND"
        const val DESCRIPTOR = "net.yuandev.onexray.VpnStatus"
        const val READ_STATUS = IBinder.FIRST_CALL_TRANSACTION
        const val BEGIN_SAVED_VPN_CHANGE = IBinder.FIRST_CALL_TRANSACTION + 1
        const val COMPLETE_SAVED_VPN_CHANGE = IBinder.FIRST_CALL_TRANSACTION + 2
    }

    private var binding: ServiceConnection? = null
    private var service: CompletableDeferred<IBinder>? = null
    private var pending: CompletableDeferred<Unit>? = null
    private var target: VpnStatus? = null
    private var eventGeneration = 0
    private var savedVpnChangeActive = false

    suspend fun read(): VpnStatus = withContext(Dispatchers.Main) {
        target?.let {
            return@withContext if (it == VpnStatus.CONNECTED) VpnStatus.CONNECTING else VpnStatus.DISCONNECTING
        }
        if (service == null && !VpnController.readVpnRunning(context)) {
            return@withContext VpnStatus.DISCONNECTED
        }
        val binder = bind()
        withContext(Dispatchers.IO) {
            val request = Parcel.obtain()
            val reply = Parcel.obtain()
            try {
                request.writeInterfaceToken(DESCRIPTOR)
                check(binder.transact(READ_STATUS, request, reply, 0)) { "VPN status query was rejected" }
                reply.readException()
                VpnStatus.entries[reply.readInt()]
            } finally {
                request.recycle()
                reply.recycle()
            }
        }
    }

    suspend fun changed(running: Boolean, error: String?) = withContext(Dispatchers.Main) {
        val generation = ++eventGeneration
        if (running) {
            // Subscribe to process death before acknowledging start completion.
            try { bind() } catch (failure: Exception) {
                if (generation != eventGeneration) return@withContext
                pending?.completeExceptionally(failure)
                throw failure
            }
            if (generation != eventGeneration) return@withContext
        } else if (!savedVpnChangeActive) {
            unbind()
        }
        if (running || error != null) VpnController.lastError = error
        val status = if (running) VpnStatus.CONNECTED else VpnStatus.DISCONNECTED
        if (status == target) pending?.complete(Unit)
        else if (!running) pending?.completeExceptionally(
            IllegalStateException(error ?: "VPN service stopped before connecting")
        )
        notify(status)
    }

    suspend fun command(wanted: VpnStatus, action: () -> Boolean): VpnStatus = withContext(Dispatchers.Main) {
        check(pending == null) { "A VPN command is already running" }
        val current = read()
        if (wanted == VpnStatus.DISCONNECTED && current == VpnStatus.DISCONNECTED) {
            check(action()) { VpnController.lastError ?: "Could not stop VPN" }
            return@withContext VpnStatus.DISCONNECTED
        }
        val completion = CompletableDeferred<Unit>()
        pending = completion
        target = wanted
        try {
            notify(if (wanted == VpnStatus.CONNECTED) VpnStatus.CONNECTING else VpnStatus.DISCONNECTING)
            check(action()) { VpnController.lastError ?: "VPN command failed" }
            withTimeout(if (wanted == VpnStatus.CONNECTED) 30_000L else 15_000L) { completion.await() }
            wanted
        } finally {
            pending = null
            target = null
        }
    }

    suspend fun beginSavedVpnChange(): Boolean = withContext(Dispatchers.Main) {
        check(!savedVpnChangeActive) { "A saved VPN change is already running" }
        val wasBound = service != null
        try {
            val begun = savedVpnCommand(bind(create = true), BEGIN_SAVED_VPN_CHANGE)
            savedVpnChangeActive = begun
            // If start admission won, retain process-death observation of that
            // now-active service rather than dropping its existing binding.
            begun
        } catch (error: Exception) {
            if (!wasBound && pending == null) unbind()
            throw error
        }
    }

    suspend fun completeSavedVpnChange(committed: Boolean) = withContext(Dispatchers.Main) {
        check(savedVpnChangeActive) { "No saved VPN change is running" }
        try {
            savedVpnCommand(bind(create = true), COMPLETE_SAVED_VPN_CHANGE, committed)
        } finally {
            savedVpnChangeActive = false
            if (pending == null) unbind()
        }
        Unit
    }

    private suspend fun savedVpnCommand(binder: IBinder, code: Int, committed: Boolean = false): Boolean =
        withContext(Dispatchers.IO) {
            val request = Parcel.obtain()
            val reply = Parcel.obtain()
            try {
                request.writeInterfaceToken(DESCRIPTOR)
                if (code == COMPLETE_SAVED_VPN_CHANGE) request.writeInt(if (committed) 1 else 0)
                check(binder.transact(code, request, reply, 0)) { "Saved VPN change was rejected" }
                reply.readException()
                code != BEGIN_SAVED_VPN_CHANGE || reply.readInt() != 0
            } finally {
                request.recycle()
                reply.recycle()
            }
        }

    private suspend fun bind(create: Boolean = false): IBinder {
        service?.let { return withTimeout(3_000) { it.await() } }
        val connected = CompletableDeferred<IBinder>()
        val connection = object : ServiceConnection {
            override fun onServiceConnected(name: ComponentName, binder: IBinder) {
                if (binding === this) connected.complete(binder)
            }
            override fun onServiceDisconnected(name: ComponentName) {
                if (binding !== this) return
                eventGeneration++
                val error = IllegalStateException("VPN service process exited")
                VpnController.lastError = error.message
                connected.completeExceptionally(error)
                if (target == VpnStatus.DISCONNECTED) pending?.complete(Unit)
                else pending?.completeExceptionally(error)
                unbind()
                notify(VpnStatus.DISCONNECTED)
            }
            override fun onBindingDied(name: ComponentName) = onServiceDisconnected(name)
            override fun onNullBinding(name: ComponentName) = onServiceDisconnected(name)
        }
        binding = connection
        service = connected
        try {
            // Reads only bind existing resources. Saved-input changes create the
            // service so admission always happens in the same :native owner.
            val flags = if (create) Context.BIND_AUTO_CREATE else 0
            check(context.bindService(Intent(context, OneVpnService::class.java).setAction(ACTION_BIND), connection, flags)) {
                "Could not bind the running VPN service"
            }
            return withTimeout(3_000) { connected.await() }
        } catch (error: Exception) {
            unbind()
            throw error
        }
    }

    private fun unbind() {
        val connection = binding
        binding = null
        service?.takeUnless { it.isCompleted }?.cancel()
        service = null
        if (connection != null) {
            try { context.unbindService(connection) } catch (_: IllegalArgumentException) { }
        }
    }

    fun close() {
        pending?.cancel()
        unbind()
    }
}
