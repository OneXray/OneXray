import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/service/share/app_link_generator.dart';

typedef OneXrayGeoDataLookup = Future<GeoDataData?> Function(String name);

final class OneXrayAppLinkShareService {
  OneXrayAppLinkShareService({OneXrayGeoDataLookup? geoDataLookup})
    : _geoDataLookup =
          geoDataLookup ?? AppDatabase().geoDataDao.searchRowByName;

  final OneXrayGeoDataLookup _geoDataLookup;

  Future<String?> config(CoreConfigData config) async {
    final configUri = OneXrayAppLinkGenerator.config(config);
    if (configUri == null) {
      return null;
    }

    final links = <String>[];
    final names = OneXrayAppLinkGenerator.referencedGeoDataNames(
      config,
    ).toList()..sort();
    for (final name in names) {
      final geoData = await _geoDataLookup(name);
      if (geoData == null) {
        continue;
      }
      final uri = OneXrayAppLinkGenerator.geoData(geoData);
      if (uri != null) {
        links.add(uri.toString());
      }
    }
    links.add(configUri.toString());
    return links.join('\n');
  }

  String? subscription(SubscriptionData subscription) {
    return OneXrayAppLinkGenerator.subscription(subscription)?.toString();
  }

  String? geoData(GeoDataData geoData) {
    return OneXrayAppLinkGenerator.geoData(geoData)?.toString();
  }
}
