package net.yuandev.onexray.vpn

import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.long
import kotlinx.serialization.json.put
import net.yuandev.onexray.pigeon.JsonTool
import net.yuandev.onexray.pigeon.PerAppVPNMode
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class SavedVpnConfigTest {
    private fun request(
        tun: Boolean = true,
        dns: String = "8.8.8.8",
        method: String = "runXray",
        xray: String = """{"outbounds":[{"protocol":"freedom"}]}""",
        metadata: String? = """{"version":1,"startedAt":1,"entries":[{"id":2,"name":"Example"}]}""",
    ) = buildJsonObject {
        if (tun) put("tun", buildJsonObject { put("tunDnsIPv4", dns) })
        put("metricsPort", "19400")
        put("coreInvokeText", buildJsonObject {
            put("apiVersion", 3)
            put("method", method)
            put("payload", buildJsonObject { put("xrayJson", xray) })
        }.toString())
        metadata?.let { put("metadataJson", it) }
    }.toString()

    @Test fun savedRequestRoundTripsThroughNativeJson() {
        val xray = """{"outbounds":[{"tag":"Example 节点","protocol":"freedom"}],"futureOption":{"enabled":true}}"""
        val original = SavedVpnConfig.decode(request(xray = xray))
        for (mode in listOf(PerAppVPNMode.ALLOW, PerAppVPNMode.DISALLOW)) {
            val saved = original.copy(tun = original.tun!!.copy(
                enableIPv6 = true,
                tunDnsIPv6 = "2001:4860:4860::8888",
                perAppVPNMode = mode,
                allowAppList = listOf("com.android.chrome"),
                disallowAppList = listOf("org.mozilla.firefox"),
            ))
            val encoded = JsonTool.json.encodeToString(saved)
            val decoded = SavedVpnConfig.decode(encoded)
            assertEquals(saved, decoded)
            assertEquals("8.8.8.8", decoded.tun?.tunDnsIPv4)
            assertEquals("19400", decoded.metricsPort)

            val wire = JsonTool.json.parseToJsonElement(encoded).jsonObject
            assertEquals(if (mode == PerAppVPNMode.ALLOW) "allow" else "disallow",
                wire.getValue("tun").jsonObject.getValue("perAppVPNMode").jsonPrimitive.content)
            val invoke = JsonTool.json.parseToJsonElement(decoded.coreInvokeText!!).jsonObject
            assertEquals("runXray", invoke.getValue("method").jsonPrimitive.content)
            assertEquals(3L, invoke.getValue("apiVersion").jsonPrimitive.long)
            assertEquals(xray, invoke.getValue("payload").jsonObject.getValue("xrayJson").jsonPrimitive.content)
        }
    }

    @Test fun rejectsMissingStartupInputs() {
        for (text in listOf(
            "not json", "{}", request(tun = false), request(dns = ""),
            request(method = "testXray"), request(xray = ""),
        )) {
            assertThrows(IllegalArgumentException::class.java) { SavedVpnConfig.decode(text) }
        }
    }

    @Test fun leavesXrayValidationToCore() {
        // Parsing the wrapper must not grow another validator for Raw or outbound fields.
        val decoded = SavedVpnConfig.decode(request(xray = """{"futureOption":true}"""))
        assertEquals(true, decoded.coreInvokeText!!.contains("futureOption"))
    }

    @Test fun renewsOnlyTheSessionTimestamp() {
        val xray = """{"inbounds":[{"tag":"app-lan-proxy","protocol":"socks","listen":"0.0.0.0","port":11024,"settings":{"auth":"noauth","udp":true}}],"outbounds":[{"protocol":"freedom"}]}"""
        val saved = SavedVpnConfig.decode(request(xray = xray))
        val renewed = SavedVpnConfig.renewSession(saved, 123456789L)
        assertEquals(saved.coreInvokeText, renewed.coreInvokeText)
        assertEquals(saved.tun, renewed.tun)
        assertEquals(saved.metricsPort, renewed.metricsPort)
        val old = JsonTool.json.parseToJsonElement(saved.metadataJson!!).jsonObject
        val current = JsonTool.json.parseToJsonElement(renewed.metadataJson!!).jsonObject
        assertEquals(1L, old.getValue("startedAt").jsonPrimitive.long)
        assertEquals(123456789L, current.getValue("startedAt").jsonPrimitive.long)
        assertEquals(old - "startedAt", current - "startedAt")
    }

    @Test fun savedRequestWithoutDisplayMetadataCanStartAgain() {
        val saved = SavedVpnConfig.decode(request(metadata = null))
        assertEquals(saved, SavedVpnConfig.renewSession(saved, 9))
    }
}
