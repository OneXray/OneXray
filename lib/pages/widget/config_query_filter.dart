import 'package:onexray/core/db/dao/config_query.dart';
import 'package:onexray/core/db/database/database.dart';

abstract final class ConfigQueryFilter {
  static List<ConfigQueryRow> filterRows(
    List<ConfigQueryRow> rows,
    String query,
  ) {
    final keyword = query.trim().toLowerCase();
    if (keyword.isEmpty) {
      return rows;
    }

    final results = <ConfigQueryRow>[];
    SubscriptionItem? currentSubscription;
    var subscriptionAdded = false;
    var includeGroup = false;

    for (final row in rows) {
      switch (row) {
        case SubscriptionItem():
          currentSubscription = row;
          subscriptionAdded = false;
          includeGroup = _matchesSubscription(row, keyword);
          if (includeGroup) {
            results.add(row);
            subscriptionAdded = true;
          }
          break;
        case ConfigItem():
          if (includeGroup || _matchesConfig(row.config, keyword)) {
            if (currentSubscription != null && !subscriptionAdded) {
              results.add(currentSubscription);
              subscriptionAdded = true;
            }
            results.add(row);
          }
          break;
        case AdsItem():
          break;
      }
    }

    return results;
  }

  static List<CoreConfigData> filterConfigs(
    List<CoreConfigData> configs,
    String query,
  ) {
    final keyword = query.trim().toLowerCase();
    if (keyword.isEmpty) {
      return configs;
    }
    return configs.where((config) => _matchesConfig(config, keyword)).toList();
  }

  static bool _matchesSubscription(SubscriptionItem item, String keyword) {
    final subscription = item.subscription;
    return _contains(subscription.name, keyword) ||
        _contains(subscription.url, keyword);
  }

  static bool _matchesConfig(CoreConfigData config, String keyword) {
    return _contains(config.name, keyword) ||
        _contains(config.tags, keyword) ||
        _contains(config.type, keyword);
  }

  static bool _contains(String value, String keyword) {
    return value.toLowerCase().contains(keyword);
  }
}
