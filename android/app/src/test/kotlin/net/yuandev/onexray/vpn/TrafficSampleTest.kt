package net.yuandev.onexray.vpn

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Test

class TrafficSampleTest {
    @Test fun readsOnlyManagedInboundCounters() {
        val sample = TrafficSample.parse("""{"stats":{"inbound":{"tunIn":{"uplink":1024,"downlink":4096},"other":{"uplink":999}},"outbound":{"proxy":{"uplink":999}}}}""")
        assertEquals(1024L, sample.uplink)
        assertEquals(4096L, sample.downlink)
        assertEquals(TrafficSample(0, 0), TrafficSample.parse("""{"stats":{}}"""))
    }

    @Test fun rejectsUnavailableOrInvalidCounters() {
        for (json in listOf("{}", """{"stats":{"inbound":{"tunIn":{"uplink":-1}}}}""", """{"stats":{"inbound":{"tunIn":{"downlink":"oops"}}}}""")) {
            assertThrows(IllegalArgumentException::class.java) { TrafficSample.parse(json) }
        }
    }

    @Test fun computesRatesAndResetsAfterRestartOrMissingBaseline() {
        val previous = TrafficSample(100, 200)
        val current = TrafficSample(1100, 2200)
        val rated = current.withSpeed(previous, 2000)
        assertEquals(500L, rated.uploadSpeed)
        assertEquals(1000L, rated.downloadSpeed)
        assertNull(current.withSpeed(null, 2000).uploadSpeed)
        assertNull(previous.withSpeed(current, 2000).downloadSpeed)
        assertNull(current.withSpeed(previous, 0).downloadSpeed)
    }

    @Test fun formatsSameUnitsAsTheConnectionPage() {
        assertEquals("0 B", TrafficSample.formatBytes(0))
        assertEquals("1 KB", TrafficSample.formatBytes(1024))
        assertEquals("1.5 KB", TrafficSample.formatBytes(1536))
        assertEquals("1 GB", TrafficSample.formatBytes(1073741824))
        assertEquals("↓ —   ↑ —", TrafficSample.speedText(null))
        assertEquals("↓ 4 KB   ↑ 1 KB", TrafficSample.sessionText(TrafficSample(1024, 4096)))
    }
}
