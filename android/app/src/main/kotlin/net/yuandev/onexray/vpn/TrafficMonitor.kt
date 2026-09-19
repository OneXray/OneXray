package net.yuandev.onexray.vpn

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.PowerManager
import android.os.SystemClock
import androidx.core.content.ContextCompat
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.net.HttpURLConnection
import java.net.Proxy
import java.net.URL
import java.io.ByteArrayOutputStream

/** Owned by the VPN service, never by a Flutter engine or an Activity. */
class TrafficMonitor(
    private val context: Context,
    private val scope: CoroutineScope,
    private val publish: (TrafficSample?) -> Unit,
) {
    private var job: Job? = null
    private var port: Int? = null
    private var registered = false
    private var latest: TrafficSample? = null
    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == Intent.ACTION_SCREEN_ON) sampleWhileVisible()
            if (intent.action == Intent.ACTION_SCREEN_OFF) {
                job?.cancel()
                job = null
                publishUnavailable()
            }
        }
    }

    // Lifecycle calls and publications run on Android's main dispatcher.
    fun start(metricsPort: String?) {
        stop()
        port = metricsPort?.toIntOrNull()?.takeIf { it in 1..65535 }
        val filter = IntentFilter(Intent.ACTION_SCREEN_ON).apply {
            addAction(Intent.ACTION_SCREEN_OFF)
        }
        ContextCompat.registerReceiver(context, screenReceiver, filter, ContextCompat.RECEIVER_NOT_EXPORTED)
        registered = true
        publish(null)
        sampleWhileVisible()
    }

    fun stop() {
        job?.cancel()
        job = null
        if (registered) context.unregisterReceiver(screenReceiver)
        registered = false
        port = null
        latest = null
    }

    private fun publishUnavailable() {
        latest = latest?.copy(uploadSpeed = null, downloadSpeed = null)
        publish(latest)
    }

    private fun sampleWhileVisible() {
        val metricsPort = port ?: return
        if (job != null || !context.getSystemService(PowerManager::class.java).isInteractive) return
        job = scope.launch(Dispatchers.Main.immediate) {
            var previous: TrafficSample? = null
            var previousTime = 0L
            while (isActive) {
                try {
                    val counters = withContext(Dispatchers.IO) { readMetrics(metricsPort) }
                    val now = SystemClock.elapsedRealtime()
                    latest = counters.withSpeed(previous, now - previousTime)
                    previous = counters
                    previousTime = now
                    publish(latest)
                } catch (cancelled: CancellationException) {
                    throw cancelled
                } catch (_: Exception) {
                    previous = null
                    publishUnavailable() // Metrics failure never changes VPN state.
                }
                delay(1000)
            }
        }
    }

    private fun readMetrics(port: Int): TrafficSample {
        val connection = URL("http://127.0.0.1:$port/debug/vars")
            .openConnection(Proxy.NO_PROXY) as HttpURLConnection
        try {
            connection.connectTimeout = 2000
            connection.readTimeout = 2000
            connection.instanceFollowRedirects = false
            check(connection.responseCode == HttpURLConnection.HTTP_OK) { "Metrics unavailable" }
            val bytes = connection.inputStream.use { stream ->
                val output = ByteArrayOutputStream()
                val buffer = ByteArray(8192)
                while (true) {
                    val count = stream.read(buffer)
                    if (count < 0) break
                    require(output.size() + count <= 1048576) { "Invalid metrics response size" }
                    output.write(buffer, 0, count)
                }
                output.toByteArray()
            }
            return TrafficSample.parse(bytes.toString(Charsets.UTF_8))
        } finally {
            connection.disconnect()
        }
    }
}
