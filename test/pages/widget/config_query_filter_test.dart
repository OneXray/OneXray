import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/db/database/enum.dart';
import 'package:onexray/pages/widget/config_query_filter.dart';

void main() {
  test('Multi-node Outbound search uses its visible product name', () {
    final config = CoreConfigData(
      id: 1,
      name: 'Node',
      type: CoreConfigType.multiNodeOutbound.name,
      tags: '',
      data: null,
      delay: 0,
      subId: 0,
      favorite: false,
    );

    for (final query in const ['multi-node', 'multi node', '多节点', '多節點']) {
      expect(ConfigQueryFilter.filterConfigs([config], query), [config]);
    }
    expect(ConfigQueryFilter.filterConfigs([config], 'full'), isEmpty);
  });
}
