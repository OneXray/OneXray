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
    val tunName: String?,
    val tunPriority: Int?,
    val bindInterface: String?,
    val onDemandEnabled: Boolean?,
    val disconnectOnSleep: Boolean?,
    val onDemandRules: List<OnDemandRule>?,
    val perAppVPNMode: PerAppVPNMode?,
    val allowAppList: List<String>?,
    val disallowAppList: List<String>?,
)

@Serializable
data class StartVpnRequest(
    val tun: TunJson?,
    val pingPort: String?,
    val coreBase64Text: String?,
)
