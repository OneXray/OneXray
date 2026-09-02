import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/service/core_run_mode/state.dart';
import 'package:onexray/service/vpn/runtime_config.dart';

void main() {
  for (final type in ['setting', 'full', 'unknown']) {
    test('$type cannot enter runtime preparation', () async {
      final row = CoreConfigData(
        id: 1,
        name: 'Legacy',
        type: type,
        tags: '',
        delay: 0,
        subId: 0,
        favorite: false,
      );
      await expectLater(
        XrayRuntimeConfigService().prepare(row, mode: CoreRunMode.tun),
        throwsA(
          isA<XrayRuntimeConfigException>().having(
            (error) => error.message,
            'reason',
            'Unsupported configuration type',
          ),
        ),
      );
    });
  }
}
