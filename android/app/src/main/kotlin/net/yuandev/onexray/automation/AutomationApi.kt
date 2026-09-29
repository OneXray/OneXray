package net.yuandev.onexray.automation

import android.content.Context
import net.yuandev.onexray.pigeon.AndroidAutomationHostApi
import net.yuandev.onexray.pigeon.AndroidAutomationSettings

/** Registered only by the main Activity; native receivers never write authorization. */
class AutomationApi(context: Context) : AndroidAutomationHostApi {
    private val store = AutomationStore(context)

    override fun read(callback: (Result<AndroidAutomationSettings>) -> Unit) =
        callback(runCatching { store.read().toBridge() })

    override fun setEnabled(enabled: Boolean, callback: (Result<AndroidAutomationSettings>) -> Unit) =
        callback(runCatching { store.setEnabled(enabled).toBridge() })

    override fun resetToken(callback: (Result<AndroidAutomationSettings>) -> Unit) =
        callback(runCatching { store.resetToken().toBridge() })

    override fun setStartBlocked(blocked: Boolean, callback: (Result<Unit>) -> Unit) =
        callback(runCatching { store.setStartBlocked(blocked) })

    override fun clear(callback: (Result<Unit>) -> Unit) = callback(runCatching { store.clear() })

    private fun AutomationSettings.toBridge() = AndroidAutomationSettings(enabled, token)
}
