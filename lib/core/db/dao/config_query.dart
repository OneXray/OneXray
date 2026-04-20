import 'package:onexray/core/db/database/database.dart';

enum ConfigQueryRowType { config, subscription, ads }

abstract class ConfigQueryRow {
  final ConfigQueryRowType rowType;

  ConfigQueryRow(this.rowType);
}

class ConfigItem extends ConfigQueryRow {
  final CoreConfigData config;

  ConfigItem(this.config, super.rowType);
}

class SubscriptionItem extends ConfigQueryRow {
  SubscriptionData subscription;
  int count = 0;

  SubscriptionItem(this.subscription, super.rowType);
}

class AdsItem extends ConfigQueryRow {
  AdsItem(super.rowType);
}

class ConfigGroup {
  final int subId;
  final SubscriptionItem subscription;
  final List<ConfigQueryRow> configs;
  var count = 0;

  ConfigGroup(this.subId, this.subscription, this.configs);
}
