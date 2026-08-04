import 'package:onexray/core/model/geo_data_type.dart';
import 'package:onexray/core/pigeon/model.dart';

enum OneXrayConfigLinkType { outbound, profile, full, raw }

sealed class OneXrayAppLink {
  const OneXrayAppLink({required this.name});

  final String name;
}

final class OneXrayConfigLink extends OneXrayAppLink {
  const OneXrayConfigLink({
    required super.name,
    required this.type,
    required this.xrayJson,
  });

  final OneXrayConfigLinkType type;
  final String xrayJson;
}

final class OneXraySubscriptionLink extends OneXrayAppLink {
  const OneXraySubscriptionLink({
    required super.name,
    required this.url,
    this.ageKeyType,
  });

  final String url;
  final AgeKeyType? ageKeyType;
}

final class OneXrayGeoDataLink extends OneXrayAppLink {
  const OneXrayGeoDataLink({
    required super.name,
    required this.type,
    required this.url,
  });

  final GeoDataType type;
  final String url;
}
