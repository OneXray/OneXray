import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/service/db/config_writer.dart';
import 'package:onexray/service/geo_data/service.dart';
import 'package:onexray/service/geo_data/validator.dart';
import 'package:onexray/service/ping/service.dart';
import 'package:onexray/service/share/app_link_model.dart';
import 'package:onexray/service/subscription/model.dart';
import 'package:onexray/service/subscription/service.dart';
import 'package:onexray/service/subscription/validator.dart';
import 'package:onexray/service/xray/multi_node_outbound/state_db.dart';
import 'package:onexray/service/xray/multi_node_outbound/state_reader.dart';
import 'package:onexray/service/xray/multi_node_outbound/state_validator.dart';
import 'package:onexray/service/xray/outbound/map.dart';
import 'package:onexray/service/xray/outbound/state_db.dart';
import 'package:onexray/service/xray/outbound/state_validator.dart';
import 'package:onexray/service/xray/profile/state_db.dart';
import 'package:onexray/service/xray/profile/state_reader.dart';
import 'package:onexray/service/xray/profile/state_validator.dart';
import 'package:onexray/service/xray/raw/db.dart';
import 'package:onexray/service/xray/raw/validator.dart';

final class OneXrayAppLinkImporter {
  Future<bool> importLink(
    OneXrayAppLink link, {
    bool showLoading = true,
  }) async {
    try {
      return await (switch (link) {
        OneXrayConfigLink() => _importConfig(link),
        OneXraySubscriptionLink() => _importSubscription(link, showLoading),
        OneXrayGeoDataLink() => _importGeoData(link, showLoading),
      });
    } catch (error, stackTrace) {
      ygLogger('import onexray link failed: $error\n$stackTrace');
      return false;
    }
  }

  Future<bool> _importConfig(OneXrayConfigLink link) async {
    final row = _readConfig(link);
    if (row == null) {
      return false;
    }
    final result = await ConfigWriter.writeRowsWithResult([row], null);
    if (result.count != 1) {
      return false;
    }
    PingService().schedulePingConfigIds(result.ids);
    return true;
  }

  CoreConfigCompanion? _readConfig(OneXrayConfigLink link) {
    try {
      return switch (link.type) {
        OneXrayConfigLinkType.outbound => _readOutbound(link),
        OneXrayConfigLinkType.profile => _readProfile(link),
        OneXrayConfigLinkType.multiNodeOutbound => _readMultiNodeOutbound(link),
        OneXrayConfigLinkType.raw => _readRawConfig(link),
      };
    } catch (error, stackTrace) {
      ygLogger('parse onexray config failed: $error\n$stackTrace');
      return null;
    }
  }

  CoreConfigCompanion? _readOutbound(OneXrayConfigLink link) {
    final outbound = decodeSingleOutbound(link.xrayJson);
    final databaseName = link.name.isEmpty ? null : link.name;
    if (!validateOutboundFields(outbound, databaseName: databaseName).item1) {
      return null;
    }
    return outboundCompanion(outbound, databaseName: databaseName);
  }

  CoreConfigCompanion? _readProfile(OneXrayConfigLink link) {
    final profile = readProfileMapFromText(
      link.xrayJson,
      nameOverride: link.name,
    );
    if (!validateProfileFields(profile).item1) {
      return null;
    }
    return profileCompanion(profile);
  }

  CoreConfigCompanion? _readMultiNodeOutbound(OneXrayConfigLink link) {
    final config = readMultiNodeOutboundFromText(
      link.xrayJson,
      nameOverride: link.name,
    );
    if (!validateMultiNodeOutboundFields(config).item1) {
      return null;
    }
    return multiNodeOutboundCompanion(config);
  }

  CoreConfigCompanion? _readRawConfig(OneXrayConfigLink link) {
    final result = XrayRawValidator.normalize(
      link.xrayJson,
      nameOverride: link.name,
    );
    if (!result.isValid || result.name == null) {
      return null;
    }
    return XrayRawDb.configCompanion(result.name!, result.normalizedText!);
  }

  Future<bool> _importSubscription(
    OneXraySubscriptionLink link,
    bool showLoading,
  ) async {
    final name = _nameOrAnonymous(link.name);
    final validation = await SubscriptionValidator.validate(name, link.url);
    if (!validation.item1) {
      return false;
    }

    String? secretKey;
    String? publicKey;
    final ageKeyType = link.ageKeyType;
    if (ageKeyType != null) {
      final pair = await AppHostApi().generateAgeKeyPair(keyType: ageKeyType);
      secretKey = pair.secretKey?.trim();
      publicKey = pair.publicKey?.trim();
      if (secretKey == null ||
          secretKey.isEmpty ||
          publicKey == null ||
          publicKey.isEmpty) {
        return false;
      }
    }

    final result = await SubscriptionService().insertSubscription(
      SubscriptionInput(
        name: name,
        url: link.url,
        ageSecretKey: secretKey,
        agePublicKey: publicKey,
      ),
      showLoading,
    );
    return result.success;
  }

  Future<bool> _importGeoData(OneXrayGeoDataLink link, bool showLoading) async {
    final name = _nameOrAnonymous(link.name);
    final validation = await GeoDataValidator.validate(name, link.url);
    if (!validation.item1) {
      return false;
    }
    return GeoDataService().insertGeoDat(
      name,
      link.type,
      link.url,
      showLoading: showLoading,
    );
  }

  String _nameOrAnonymous(String name) {
    final value = name.trim();
    return value.isEmpty ? 'anonymous' : value;
  }
}
