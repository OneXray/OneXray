import 'dart:convert';

import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/tools/empty.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/service/xray/outbound/enum.dart';
import 'package:onexray/service/xray/outbound/state.dart';
import 'package:onexray/service/xray/outbound/xhttp/state_reader.dart';

extension OutboundStateReader on OutboundState {
  void readFromDbData(CoreConfigData outbound) {
    if (EmptyTool.checkString(outbound.data)) {
      final bytes = base64Decode(outbound.data!);
      final text = utf8.decode(bytes);
      readFromText(text);
    }
  }

  bool readFromText(String text) {
    final jsonData = JsonTool.decoder.convert(text);
    final xrayJson = XrayJson.fromJson(jsonData);
    if (EmptyTool.checkList(xrayJson.outbounds)) {
      final outbound = xrayJson.outbounds!.first;
      return readFromOutbound(outbound);
    }
    return false;
  }

  bool readFromOutbound(XrayOutbound outbound) {
    if (EmptyTool.checkString(outbound.protocol)) {
      final protocol = XrayOutboundProtocol.fromString(outbound.protocol!);
      if (protocol != null) {
        this.protocol = protocol;
        name = _readName(outbound);
        if (EmptyTool.checkString(outbound.tag)) {
          tag = outbound.tag!;
        }

        if (!_parseMux(outbound)) {
          return false;
        }

        switch (protocol) {
          case XrayOutboundProtocol.vless:
            return _vlessState(outbound);
          case XrayOutboundProtocol.vmess:
            return _vmessState(outbound);
          case XrayOutboundProtocol.shadowsocks:
            return _shadowsocksState(outbound);
          case XrayOutboundProtocol.trojan:
            return _trojanState(outbound);
          case XrayOutboundProtocol.socks:
            return _socksState(outbound);
          case XrayOutboundProtocol.hysteria:
            return _hysteriaState(outbound);
          default:
            return false;
        }
      }
    }
    return false;
  }

  String _readName(XrayOutbound outbound) {
    if (EmptyTool.checkString(outbound.name)) {
      return outbound.name!;
    }
    if (EmptyTool.checkString(outbound.sendThrough)) {
      return outbound.sendThrough!;
    }
    if (EmptyTool.checkString(outbound.tag)) {
      return outbound.tag!;
    }
    if (EmptyTool.checkString(outbound.protocol)) {
      return outbound.protocol!;
    }
    return "";
  }

  bool _parseMux(XrayOutbound outbound) {
    final mux = outbound.mux;
    if (mux == null) {
      return true;
    }
    if (mux.enabled != null && mux.enabled!) {
      muxEnabled = mux.enabled!;
      if (mux.concurrency != null) {
        muxConcurrency = "${mux.concurrency!}";
      }
      if (mux.xudpConcurrency != null) {
        muxXudpConcurrency = "${mux.xudpConcurrency!}";
      }
      if (mux.xudpProxyUDP443 != null) {
        final xudpProxyUDP443 = MuxXudpProxyUDP443.fromString(
          mux.xudpProxyUDP443!,
        );
        if (xudpProxyUDP443 != null) {
          muxXudpProxyUDP443 = xudpProxyUDP443;
        } else {
          return false;
        }
      }
    }
    return true;
  }

  bool _vlessState(XrayOutbound outbound) {
    if (!EmptyTool.checkMap(outbound.settings)) {
      return false;
    }
    final settings = XrayOutboundVLESS.fromJson(outbound.settings!);

    if (!_readVlessSettings(settings)) {
      return false;
    }

    if (outbound.streamSettings != null) {
      if (!_parseStreamSettings(outbound.streamSettings!)) {
        return false;
      }
    }
    return true;
  }

  bool _readVlessSettings(XrayOutboundVLESS settings) {
    if (EmptyTool.checkString(settings.address)) {
      address = settings.address!;
    }
    if (settings.port != null) {
      port = "${settings.port!}";
    }

    if (EmptyTool.checkString(settings.id)) {
      vlessId = settings.id!;
    }
    if (EmptyTool.checkString(settings.flow)) {
      final flow = VLESSFlow.fromString(settings.flow!);
      if (flow == null) {
        return false;
      }
      vlessFlow = flow;
    }
    if (EmptyTool.checkString(settings.encryption)) {
      vlessEncryption = settings.encryption!;
    }

    if (EmptyTool.checkString(settings.reverse?.tag)) {
      vlessReverseTag = settings.reverse!.tag!;
    }

    return true;
  }

  bool _vmessState(XrayOutbound outbound) {
    if (!EmptyTool.checkMap(outbound.settings)) {
      return false;
    }
    final settings = XrayOutboundVMess.fromJson(outbound.settings!);

    if (!_readVmessSettings(settings)) {
      return false;
    }

    if (outbound.streamSettings != null) {
      if (!_parseStreamSettings(outbound.streamSettings!)) {
        return false;
      }
    }
    return true;
  }

  bool _readVmessSettings(XrayOutboundVMess settings) {
    if (EmptyTool.checkString(settings.address)) {
      address = settings.address!;
    }
    if (settings.port != null) {
      port = "${settings.port!}";
    }

    if (EmptyTool.checkString(settings.id)) {
      vmessId = settings.id!;
    }
    if (EmptyTool.checkString(settings.security)) {
      final security = VMessSecurity.fromString(settings.security!);
      if (security == null) {
        return false;
      }
      vmessSecurity = security;
    }

    return true;
  }

  bool _shadowsocksState(XrayOutbound outbound) {
    if (!EmptyTool.checkMap(outbound.settings)) {
      return false;
    }
    final settings = XrayOutboundShadowsocks.fromJson(outbound.settings!);

    if (!_readShadowsocksSettings(settings)) {
      return false;
    }

    if (outbound.streamSettings != null) {
      if (!_parseStreamSettings(outbound.streamSettings!)) {
        return false;
      }
    }
    return true;
  }

  bool _readShadowsocksSettings(XrayOutboundShadowsocks settings) {
    if (EmptyTool.checkString(settings.address)) {
      address = settings.address!;
    }
    if (settings.port != null) {
      port = "${settings.port!}";
    }
    if (EmptyTool.checkString(settings.method)) {
      final method = ShadowsocksMethod.fromString(settings.method!);
      if (method != null) {
        shadowsocksMethod = method;
      } else {
        return false;
      }
    }
    if (EmptyTool.checkString(settings.password)) {
      shadowsocksPassword = settings.password!;
    }
    if (settings.uot != null) {
      shadowsocksUot = settings.uot!;
    }
    if (settings.uotVersion != null) {
      final uoTVersion = ShadowsocksUoTVersion.fromString(
        "${settings.uotVersion}",
      );
      if (uoTVersion != null) {
        shadowsocksUotVersion = uoTVersion;
      } else {
        return false;
      }
    }
    return true;
  }

  bool _trojanState(XrayOutbound outbound) {
    if (!EmptyTool.checkMap(outbound.settings)) {
      return false;
    }
    final settings = XrayOutboundTrojan.fromJson(outbound.settings!);

    if (!_readTrojanSettings(settings)) {
      return false;
    }

    if (outbound.streamSettings != null) {
      if (!_parseStreamSettings(outbound.streamSettings!)) {
        return false;
      }
    }
    return true;
  }

  bool _readTrojanSettings(XrayOutboundTrojan settings) {
    if (EmptyTool.checkString(settings.address)) {
      address = settings.address!;
    }
    if (settings.port != null) {
      port = "${settings.port!}";
    }
    if (EmptyTool.checkString(settings.password)) {
      trojanPassword = settings.password!;
    }
    return true;
  }

  bool _socksState(XrayOutbound outbound) {
    if (!EmptyTool.checkMap(outbound.settings)) {
      return false;
    }
    final settings = XrayOutboundSocks.fromJson(outbound.settings!);

    if (!_readSocksSettings(settings)) {
      return false;
    }

    if (outbound.streamSettings != null) {
      if (!_parseStreamSettings(outbound.streamSettings!)) {
        return false;
      }
    }
    return true;
  }

  bool _readSocksSettings(XrayOutboundSocks settings) {
    if (EmptyTool.checkString(settings.address)) {
      address = settings.address!;
    }
    if (settings.port != null) {
      port = "${settings.port!}";
    }
    if (EmptyTool.checkString(settings.user)) {
      socksUser = settings.user!;
    }
    if (EmptyTool.checkString(settings.pass)) {
      socksPass = settings.pass!;
    }
    return true;
  }

  bool _hysteriaState(XrayOutbound outbound) {
    if (!EmptyTool.checkMap(outbound.settings)) {
      return false;
    }
    final settings = XrayOutboundHysteria.fromJson(outbound.settings!);
    if (!_readHysteriaSettings(settings)) {
      return false;
    }

    if (outbound.streamSettings != null) {
      if (!_parseStreamSettings(outbound.streamSettings!)) {
        return false;
      }
    }
    return true;
  }

  bool _readHysteriaSettings(XrayOutboundHysteria settings) {
    if (EmptyTool.checkString(settings.address)) {
      address = settings.address!;
    }
    if (settings.port != null) {
      port = "${settings.port!}";
    }
    return true;
  }

  bool _parseStreamSettings(XrayStreamSettings settings) {
    if (EmptyTool.checkString(settings.network)) {
      final network = StreamSettingsNetwork.fromString(settings.network!);
      if (network != null) {
        this.network = network;
      } else {
        return false;
      }
    }
    if (EmptyTool.checkString(settings.security)) {
      final security = StreamSettingsSecurity.fromString(settings.security!);
      if (security != null) {
        this.security = security;
      } else {
        return false;
      }
    }

    switch (network) {
      case StreamSettingsNetwork.raw:
        if (settings.rawSettings != null) {
          if (!_parseRawSettings(settings.rawSettings!)) {
            return false;
          }
        }
        break;
      case StreamSettingsNetwork.xhttp:
        if (settings.xhttpSettings != null) {
          if (!_parseXhttpSettings(settings.xhttpSettings!)) {
            return false;
          }
        }
        break;
      case StreamSettingsNetwork.kcp:
        if (settings.kcpSettings != null) {
          if (!_parseKcpSettings(settings.kcpSettings!)) {
            return false;
          }
        }
        break;
      case StreamSettingsNetwork.grpc:
        if (settings.grpcSettings != null) {
          if (!_parseGrpcSettings(settings.grpcSettings!)) {
            return false;
          }
        }
        break;
      case StreamSettingsNetwork.ws:
        if (settings.wsSettings != null) {
          if (!_parseWsSettings(settings.wsSettings!)) {
            return false;
          }
        }
        break;
      case StreamSettingsNetwork.httpupgrade:
        if (settings.httpupgradeSettings != null) {
          if (!_parseHttpupgradeSettings(settings.httpupgradeSettings!)) {
            return false;
          }
        }
        break;
      case StreamSettingsNetwork.hysteria:
        if (settings.hysteriaSettings != null) {
          if (!_parseHysteriaSettings(settings.hysteriaSettings!)) {
            return false;
          }
        }
        break;
    }

    if (settings.finalmask != null && EmptyTool.checkMap(settings.finalmask)) {
      finalMask = settings.finalmask!;
    }

    switch (security) {
      case StreamSettingsSecurity.tls:
        if (settings.tlsSettings != null) {
          if (!_parseTlsSettings(settings.tlsSettings!)) {
            return false;
          }
        }
        break;
      case StreamSettingsSecurity.reality:
        if (settings.realitySettings != null) {
          if (!_parseRealitySettings(settings.realitySettings!)) {
            return false;
          }
        }
        break;
      default:
        break;
    }

    if (settings.sockopt != null) {
      if (!_parseSockopt(settings.sockopt!)) {
        return false;
      }
    }

    // fix hysteria alpn
    if (network == StreamSettingsNetwork.hysteria) {
      alpn = <StreamSettingsSecurityALPN>{StreamSettingsSecurityALPN.h3};
    }

    return true;
  }

  bool _parseRawSettings(XrayRawSettings settings) {
    if (settings.header != null) {
      final header = settings.header!;
      if (EmptyTool.checkString(header.type)) {
        final type = RawHeaderType.fromString(header.type!);
        if (type == null) {
          return false;
        }
        rawHeaderType = type;
      }
      if (header.request != null) {
        final request = header.request!;
        if (EmptyTool.checkList(request.path)) {
          rawPath = request.path!;
        }
        if (EmptyTool.checkList(request.headers?.host)) {
          rawHost = request.headers!.host!;
        }
      }
    }
    return true;
  }

  bool _parseXhttpSettings(XrayXhttpSettings settings) {
    if (EmptyTool.checkString(settings.host)) {
      xhttpHost = settings.host!;
    }
    if (EmptyTool.checkString(settings.path)) {
      xhttpPath = settings.path!;
    }
    if (EmptyTool.checkString(settings.mode)) {
      final mode = XhttpMode.fromString(settings.mode!);
      if (mode == null) {
        return false;
      }
      xhttpMode = mode;
    }
    // extra
    if (settings.extra != null) {
      if (!xhttpExtra.readFromXrayJson(settings.extra!)) {
        return false;
      }
    }

    return true;
  }

  bool _parseKcpSettings(XrayKcpSettings settings) {
    if (settings.header != null) {
      final header = settings.header!;
      if (EmptyTool.checkString(header.type)) {
        final type = KcpHeaderType.fromString(header.type!);
        if (type == null) {
          return false;
        }
        kcpHeaderType = type;
      }
      if (EmptyTool.checkString(header.domain)) {
        kcpHeaderDomain = header.domain!;
      }
    }

    if (EmptyTool.checkString(settings.seed)) {
      kcpSeed = settings.seed!;
    }
    return true;
  }

  bool _parseGrpcSettings(XrayGrpcSettings settings) {
    if (EmptyTool.checkString(settings.authority)) {
      grpcAuthority = settings.authority!;
    }
    if (EmptyTool.checkString(settings.serviceName)) {
      grpcServiceName = settings.serviceName!;
    }
    if (settings.multiMode != null) {
      grpcMultiMode = settings.multiMode!;
    }
    return true;
  }

  bool _parseWsSettings(XrayWsSettings settings) {
    if (EmptyTool.checkString(settings.path)) {
      wsPath = settings.path!;
    }
    if (EmptyTool.checkString(settings.host)) {
      wsHost = settings.host!;
    }
    return true;
  }

  bool _parseHttpupgradeSettings(XrayHttpupgradeSettings settings) {
    if (EmptyTool.checkString(settings.host)) {
      httpupgradeHost = settings.host!;
    }
    if (EmptyTool.checkString(settings.path)) {
      httpupgradePath = settings.path!;
    }
    return true;
  }

  bool _parseHysteriaSettings(XrayHysteriaSettings settings) {
    if (EmptyTool.checkString(settings.auth)) {
      hysteriaAuth = settings.auth!;
    }
    if (EmptyTool.checkString(settings.up)) {
      hysteriaUp = settings.up!;
    }
    if (EmptyTool.checkString(settings.down)) {
      hysteriaDown = settings.down!;
    }
    if (EmptyTool.checkString(settings.udphop?.port)) {
      hysteriaUdphopPort = settings.udphop!.port!;
      if (settings.udphop!.interval != null) {
        hysteriaUdphopInterval = "${settings.udphop!.interval!}";
      }
    }
    return true;
  }

  bool _parseTlsSettings(XrayTlsSettings settings) {
    if (EmptyTool.checkString(settings.serverName)) {
      serverName = settings.serverName!;
    }
    if (EmptyTool.checkList(settings.alpn)) {
      alpn = StreamSettingsSecurityALPN.fromStrings(settings.alpn!);
    }
    if (EmptyTool.checkString(settings.fingerprint)) {
      final fingerprint = StreamSettingsSecurityFingerprint.fromString(
        settings.fingerprint!,
      );
      if (fingerprint == null) {
        return false;
      }
      this.fingerprint = fingerprint;
    }
    if (EmptyTool.checkString(settings.pinnedPeerCertSha256)) {
      pinnedPeerCertSha256 = settings.pinnedPeerCertSha256!;
    }
    if (EmptyTool.checkString(settings.verifyPeerCertByName)) {
      verifyPeerCertByName = settings.verifyPeerCertByName!;
    }
    if (EmptyTool.checkString(settings.echConfigList)) {
      echConfigList = settings.echConfigList!;
    }
    if (EmptyTool.checkString(settings.echForceQuery)) {
      final echForceQuery = StreamSettingsEchForceQuery.fromString(
        settings.echForceQuery!,
      );
      if (echForceQuery == null) {
        return false;
      }
      this.echForceQuery = echForceQuery;
    }
    return true;
  }

  bool _parseRealitySettings(XrayRealitySettings settings) {
    if (EmptyTool.checkString(settings.fingerprint)) {
      final fingerprint = StreamSettingsSecurityFingerprint.fromString(
        settings.fingerprint!,
      );
      if (fingerprint == null) {
        return false;
      }
      this.fingerprint = fingerprint;
    }
    if (EmptyTool.checkString(settings.serverName)) {
      serverName = settings.serverName!;
    }
    if (EmptyTool.checkString(settings.password)) {
      password = settings.password!;
    } else if (EmptyTool.checkString(settings.publicKey)) {
      password = settings.publicKey!;
    }
    if (EmptyTool.checkString(settings.shortId)) {
      shortId = settings.shortId!;
    }
    if (EmptyTool.checkString(settings.mldsa65Verify)) {
      mldsa65Verify = settings.mldsa65Verify!;
    }
    if (EmptyTool.checkString(settings.spiderX)) {
      spiderX = settings.spiderX!;
    }
    return true;
  }

  bool _parseSockopt(XraySockopt sockopt) {
    if (sockopt.tcpFastOpen != null) {
      tcpFastOpen = sockopt.tcpFastOpen!;
    }
    if (EmptyTool.checkString(sockopt.dialerProxy)) {
      dialerProxy = sockopt.dialerProxy!;
    }
    if (EmptyTool.checkString(sockopt.interface)) {
      interface = sockopt.interface!;
    }
    if (sockopt.tcpMptcp != null) {
      tcpMptcp = sockopt.tcpMptcp!;
    }

    return true;
  }
}
