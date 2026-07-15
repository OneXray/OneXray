import 'package:flutter/material.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/db/database/enum.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';

extension ConfigReader on CoreConfigData {
  String readProtocolLabel() {
    return switch (CoreConfigType.fromString(type)) {
      CoreConfigType.outbound =>
        tags
            .split(',')
            .firstWhere((tag) => tag.isNotEmpty, orElse: () => type)
            .toUpperCase(),
      CoreConfigType.raw => 'JSON',
      CoreConfigType.full => 'FULL',
      CoreConfigType.profile || null => '',
    };
  }

  String readConnectionDetail(BuildContext context) {
    return switch (CoreConfigType.fromString(type)) {
      CoreConfigType.outbound =>
        tags
            .split(',')
            .skip(1)
            .where((tag) => tag.isNotEmpty && tag.toLowerCase() != 'none')
            .join(' · '),
      CoreConfigType.raw => AppLocalizations.of(
        context,
      )!.homeManualInputRawJson,
      CoreConfigType.full => AppLocalizations.of(
        context,
      )!.homeManualInputFullConfig,
      CoreConfigType.profile || null => '',
    };
  }

  String readDelayLabel(BuildContext context) => _readDelayTag(context);

  List<String> readTags(BuildContext context) {
    final tags = <String>[];
    final type = CoreConfigType.fromString(this.type);
    if (type != null) {
      switch (type) {
        case CoreConfigType.outbound:
          tags.add(_readOutboundTags());
          break;
        case CoreConfigType.raw:
          tags.add("JSON");
          break;
        case CoreConfigType.full:
          tags.add("FULL");
          break;
        default:
          break;
      }
    }
    final delay = _readDelayTag(context);
    if (delay.isNotEmpty) {
      tags.add(delay);
    }

    return tags;
  }

  String _readOutboundTags() {
    return tags.replaceAll(",", " | ");
  }

  String _readDelayTag(BuildContext context) {
    switch (delay) {
      case PingDelayConstants.unknown:
        return "";
      case PingDelayConstants.error:
        return AppLocalizations.of(context)!.pingError;
      case PingDelayConstants.timeout:
        return AppLocalizations.of(context)!.pingTimeout;
      default:
        return "${delay}ms";
    }
  }
}
