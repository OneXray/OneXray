package net.yuandev.onexray.vpn

import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.long
import kotlinx.serialization.json.put
import net.yuandev.onexray.pigeon.JsonTool
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

    @Test fun readsCompleteNativeStartRequest() {
        val decoded = SavedVpnConfig.decode(request())
        assertEquals("8.8.8.8", decoded.tun?.tunDnsIPv4)
        assertEquals("19400", decoded.metricsPort)
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
        val saved = SavedVpnConfig.decode(request())
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

    @Test fun missingOrInvalidDisplayMetadataDoesNotBlockVpn() {
        for (metadata in listOf(null, "invalid")) {
            val saved = SavedVpnConfig.decode(request(metadata = metadata))
            assertEquals(saved, SavedVpnConfig.renewSession(saved, 9))
        }
    }
}
