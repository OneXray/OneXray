package net.yuandev.onexray.vpn

import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.put
import net.yuandev.onexray.pigeon.JsonTool
import net.yuandev.onexray.pigeon.LibXrayInvokeRequest
import net.yuandev.onexray.pigeon.LibXrayMethod
import net.yuandev.onexray.pigeon.StartVpnRequest
import java.io.File

/** The existing native start request, not a second configuration or a VPN-state cache. */
object SavedVpnConfig {
    fun read(file: File): StartVpnRequest {
        require(file.isFile && file.length() <= 16 * 1024 * 1024) { "VPN start configuration is unavailable" }
        return try {
            decode(file.readText())
        } catch (_: SerializationException) {
            // Decoder messages can include node credentials from the input.
            throw IllegalStateException("Invalid VPN start request")
        }
    }

    fun decode(text: String): StartVpnRequest {
        val request = JsonTool.json.decodeFromString<StartVpnRequest>(text)
        requireNotNull(request.tun) { "Missing TUN configuration" }
        require(!request.tun.tunDnsIPv4.isNullOrBlank()) { "Missing IPv4 TUN DNS" }
        val invoke = JsonTool.json.decodeFromString<LibXrayInvokeRequest>(
            requireNotNull(request.coreInvokeText) { "Missing Xray run request" },
        )
        require(invoke.method == LibXrayMethod.RUN_XRAY && !invoke.payload?.xrayJson.isNullOrBlank()) {
            "Missing Xray run configuration"
        }
        // Xray owns validation of the configuration itself, including local assets.
        return request
    }

    fun renewSession(request: StartVpnRequest, startedAtMicros: Long): StartVpnRequest {
        val metadata = request.metadataJson?.let {
            runCatching { JsonTool.json.parseToJsonElement(it).jsonObject }.getOrNull()
        } ?: return request
        val updated = buildJsonObject {
            metadata.forEach { (key, value) -> put(key, value) }
            put("startedAt", startedAtMicros)
        }
        return request.copy(metadataJson = updated.toString())
    }
}
