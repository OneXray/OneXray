package net.yuandev.onexray.vpn

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.longOrNull
import java.util.Locale

data class TrafficSample(
    val uplink: Long,
    val downlink: Long,
    val uploadSpeed: Long? = null,
    val downloadSpeed: Long? = null,
) {
    fun withSpeed(previous: TrafficSample?, elapsedMs: Long): TrafficSample {
        if (previous == null || elapsedMs <= 0 ||
            uplink < previous.uplink || downlink < previous.downlink) return this
        return copy(
            uploadSpeed = ((uplink - previous.uplink) * 1000.0 / elapsedMs).toLong(),
            downloadSpeed = ((downlink - previous.downlink) * 1000.0 / elapsedMs).toLong(),
        )
    }

    companion object {
        fun parse(text: String): TrafficSample {
            val root = Json.parseToJsonElement(text) as? JsonObject
            val stats = root?.get("stats") as? JsonObject
                ?: throw IllegalArgumentException("Missing metrics stats")
            val inbound = stats["inbound"] as? JsonObject
            val tun = inbound?.get("tunIn") as? JsonObject
            fun counter(key: String): Long {
                val value = tun?.get(key) ?: return 0 // Counters are created lazily.
                return (value as? JsonPrimitive)?.longOrNull?.takeIf { it >= 0 }
                    ?: throw IllegalArgumentException("Invalid metrics counter")
            }
            return TrafficSample(counter("uplink"), counter("downlink"))
        }

        fun formatBytes(bytes: Long): String {
            val units = arrayOf("B", "KB", "MB", "GB", "TB")
            var value = bytes.toDouble()
            var unit = 0
            while (value >= 1024 && unit < units.lastIndex) {
                value /= 1024
                unit++
            }
            val number = if (unit == 0) bytes.toString() else
                String.format(Locale.ROOT, "%.2f", value).trimEnd('0').trimEnd('.')
            return "$number ${units[unit]}"
        }

        fun speedText(sample: TrafficSample?): String {
            fun speed(value: Long?) = value?.let { "${formatBytes(it)}/s" } ?: "—"
            return "↓ ${speed(sample?.downloadSpeed)}   ↑ ${speed(sample?.uploadSpeed)}"
        }

        fun sessionText(sample: TrafficSample?): String {
            fun size(value: Long?) = value?.let { formatBytes(it) } ?: "—"
            return "↓ ${size(sample?.downlink)}   ↑ ${size(sample?.uplink)}"
        }
    }
}
