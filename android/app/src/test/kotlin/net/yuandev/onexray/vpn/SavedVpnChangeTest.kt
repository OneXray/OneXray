package net.yuandev.onexray.vpn

import android.app.Application
import android.content.Intent
import android.os.Parcel
import net.yuandev.onexray.pigeon.VpnStatus
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [29, 34], application = Application::class)
class SavedVpnChangeTest {
    private val context get() = RuntimeEnvironment.getApplication()

    @Before fun grantDynamicReceiverPermission() {
        shadowOf(context).grantPermissions("${context.packageName}.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION")
    }

    private fun savedConfig(): String {
        val text = """{"tun":{"tunDnsIPv4":"8.8.8.8"},"metricsPort":"19400","metadataJson":"{\"startedAt\":1}","coreInvokeText":"{\"apiVersion\":3,\"method\":\"runXray\",\"payload\":{\"xrayJson\":\"{}\"}}"}"""
        VpnController.startFile(context).apply {
            parentFile!!.mkdirs()
            writeText(text)
        }
        return text
    }

    private fun transact(service: OneVpnService, code: Int, committed: Boolean = false): Int? {
        val binder = service.onBind(Intent(VpnStatusConnection.ACTION_BIND))!!
        val request = Parcel.obtain()
        val reply = Parcel.obtain()
        try {
            request.writeInterfaceToken(VpnStatusConnection.DESCRIPTOR)
            if (code == VpnStatusConnection.COMPLETE_SAVED_VPN_CHANGE) request.writeInt(if (committed) 1 else 0)
            assertTrue(binder.transact(code, request, reply, 0))
            reply.readException()
            return if (code == VpnStatusConnection.COMPLETE_SAVED_VPN_CHANGE) null else reply.readInt()
        } finally {
            request.recycle()
            reply.recycle()
        }
    }

    @Test fun failedSavePreservesExactInputAndBlocksAnAlreadyDispatchedBackgroundStart() {
        val text = savedConfig()
        val file = VpnController.startFile(context)
        // The Widget/Tile adapter already read the old request before the save.
        assertNotNull(SavedVpnConfig.read(file))
        val service = Robolectric.buildService(OneVpnService::class.java).create().get()
        assertEquals(1, transact(service, VpnStatusConnection.BEGIN_SAVED_VPN_CHANGE))
        service.onStartCommand(
            Intent(context, OneVpnService::class.java)
                .setAction(OneVpnService.ACTION_START)
                .putExtra(OneVpnService.EXTRA_REUSE_CONFIGURATION, true),
            0, 1,
        )
        assertEquals(VpnStatus.DISCONNECTED.ordinal, transact(service, VpnStatusConnection.READ_STATUS))
        assertEquals(text, file.readText()) // No renewSession rewrite while held.
        assertTrue(SavedVpnConfig.isChangeBlocked(file))
        transact(service, VpnStatusConnection.COMPLETE_SAVED_VPN_CHANGE, committed = false)
        assertFalse(SavedVpnConfig.isChangeBlocked(file))
        assertEquals(text, file.readText())
        assertNotNull(SavedVpnConfig.read(file))
        service.onDestroy()
    }

    @Test fun successfulSaveInvalidatesInputBeforeBackgroundStartsAreUnblocked() {
        savedConfig()
        val file = VpnController.startFile(context)
        val service = Robolectric.buildService(OneVpnService::class.java).create().get()
        assertEquals(1, transact(service, VpnStatusConnection.BEGIN_SAVED_VPN_CHANGE))
        transact(service, VpnStatusConnection.COMPLETE_SAVED_VPN_CHANGE, committed = true)
        assertFalse(file.exists())
        assertFalse(SavedVpnConfig.isChangeBlocked(file))
        assertEquals(VpnController.SavedStartResult.OPEN_APP, VpnController.startSavedVpn(context))
        service.onDestroy()
    }
}
