import 'package:collection/collection.dart';
import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/tools/empty.dart';
import 'package:onexray/service/xray/constants.dart';
import 'package:onexray/service/xray/standard.dart';

enum XrayLogLevel {
  debug("debug"),
  info("info"),
  warning("warning"),
  error("error"),
  none("none");

  const XrayLogLevel(this.name);

  final String name;

  @override
  String toString() => name;

  static XrayLogLevel? fromString(String name) =>
      XrayLogLevel.values.firstWhereOrNull((value) => value.name == name);

  static List<String> get names {
    return XrayLogLevel.values.map((e) => e.name).toList();
  }
}

enum XrayLogMaskAddress {
  none(""),
  quarter("quarter"),
  half("half"),
  full("full");

  const XrayLogMaskAddress(this.name);

  final String name;

  @override
  String toString() => name;

  static XrayLogMaskAddress? fromString(String name) =>
      XrayLogMaskAddress.values.firstWhereOrNull((value) => value.name == name);

  static List<String> get names {
    return XrayLogMaskAddress.values.map((e) => e.name).toList();
  }
}

class LogState {
  var logLevel = XrayLogLevel.none;
  var dnsLog = false;
  var maskAddress = XrayLogMaskAddress.none;

  void readFromXrayJson(XrayJson xrayJson) {
    final log = xrayJson.log;
    if (log == null) {
      return;
    }
    if (EmptyTool.checkString(log.logLevel)) {
      final logLevel = XrayLogLevel.fromString(log.logLevel!);
      if (logLevel != null) {
        this.logLevel = logLevel;
      }
    }
    if (log.dnsLog != null) {
      dnsLog = log.dnsLog!;
    }
    if (EmptyTool.checkString(log.maskAddress)) {
      final maskAddress = XrayLogMaskAddress.fromString(log.maskAddress!);
      if (maskAddress != null) {
        this.maskAddress = maskAddress;
      }
    }
  }

  XrayLog get xrayJson {
    final log = XrayLogStandard.standard;
    log.access = XrayStateConstants.accessLogPath;
    log.error = XrayStateConstants.errorLogPath;
    log.logLevel = logLevel.name;
    log.dnsLog = dnsLog;
    if (maskAddress != XrayLogMaskAddress.none) {
      log.maskAddress = maskAddress.name;
    }
    return log;
  }
}
