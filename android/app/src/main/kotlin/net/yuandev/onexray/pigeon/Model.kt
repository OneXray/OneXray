package net.yuandev.onexray.pigeon

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class OnDemandRule(
    val mode: String?,
    val interfaceType: String?,
    val ssid: List<String>?,
)

@Serializable
enum class PerAppVPNMode {
    @SerialName("allow")
    ALLOW,

    @SerialName("disallow")
    DISALLOW
}

@Serializable
data class TunJson(
    val tunDnsIPv4: String?,
    val tunDnsIPv6: String?,
    val enableDot: Boolean?,
    val dnsServerName: String?,
    val enableIPv6: Boolean?,
    val metricsEnabled: Boolean?,
    val tunName: String?,
    val autoOutboundsInterface: String?,
    val onDemandEnabled: Boolean?,
    val disconnectOnSleep: Boolean?,
    val onDemandRules: List<OnDemandRule>?,
    val perAppVPNMode: PerAppVPNMode?,
    val allowAppList: List<String>?,
    val disallowAppList: List<String>?,
)

@Serializable
data class XrayInboundAccount(
    val user: String?,
    val pass: String?,
)

@Serializable
data class StartVpnRequest(
    val tun: TunJson?,
    val pingPort: String?,
    val pingAuth: XrayInboundAccount?,
    val metricsPort: String?,
    val coreInvokeText: String?,
)

@Serializable
enum class LibXrayMethod {
    @SerialName("getFreePorts")
    GET_FREE_PORTS,

    @SerialName("convertShareLinksToXrayJson")
    CONVERT_SHARE_LINKS_TO_XRAY_JSON,

    @SerialName("convertXrayJsonToShareLinks")
    CONVERT_XRAY_JSON_TO_SHARE_LINKS,

    @SerialName("countGeoData")
    COUNT_GEO_DATA,

    @SerialName("ping")
    PING,

    @SerialName("testXray")
    TEST_XRAY,

    @SerialName("runXray")
    RUN_XRAY,

    @SerialName("runXrayFromJson")
    RUN_XRAY_FROM_JSON,

    @SerialName("stopXray")
    STOP_XRAY,

    @SerialName("xrayVersion")
    XRAY_VERSION,

    @SerialName("getXrayState")
    GET_XRAY_STATE,
}

@Serializable
data class RunXrayRequest(
    val configPath: String? = null,
)

@Serializable
data class XrayEnv(
    @SerialName("xray.location.asset")
    val assetLocation: String? = null,
    @SerialName("xray.location.cert")
    val certLocation: String? = null,
    @SerialName("xray.tun.fd")
    val tunFd: String? = null,
)

@Serializable
data class LibXrayInvokeRequest(
    val apiVersion: Int? = 1,
    val method: LibXrayMethod? = null,
    val payload: RunXrayRequest? = null,
)

@Serializable
data class LibXrayInvokeResponse(
    val success: Boolean,
    val error: String,
)
