import 'package:flutter/material.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/db/database/enum.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';

extension ConfigReader on CoreConfigData {
  List<String> readTags(BuildContext context) {
    final tags = <String>[];
    final type = CoreConfigType.fromString(this.type);
    if (type != null) {
      switch (type) {
        case CoreConfigType.outbound:
          tags.addAll(_readOutboundTags());
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

  List<String> _readOutboundTags() {
    final tags = <String>[];
    final tag = this.tags.split(",");
    if (tag.length == 3) {
      tags.addAll(tag);
    }
    return tags;
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
