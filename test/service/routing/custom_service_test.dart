import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/service/routing/custom_service.dart';
import 'package:onexray/service/routing/custom_template.dart';

void main() {
  test(
    'names use Unicode characters and trimmed case-insensitive uniqueness',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final service = CustomRoutingService(database);
      const text = '{"outbounds":[{}],"routing":{"rules":[]}}';
      final id = await service.save(name: ' Route ', text: text);
      expect((await database.routingProfileDao.searchRow(id))!.name, 'Route');
      await expectLater(
        service.save(name: 'route', text: text),
        throwsFormatException,
      );
      final name = List.filled(32, '🌐').join();
      final unicode = CustomRoutingTemplate.parse(
        jsonEncode({
          'name': name,
          'outbounds': [{}],
        }),
      );
      await service.save(id: id, name: name, text: unicode.encode());
      expect((await database.routingProfileDao.searchRow(id))!.name, name);
    },
  );
  test(
    'custom saves share one strict limit/encoding boundary; edits stay allowed',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final service = CustomRoutingService(database);
      const text = '{"outbounds":[{}],"routing":{"rules":[]}}';
      final id = await service.save(name: 'One', text: text);
      final row = (await database.routingProfileDao.searchRow(id))!;
      expect(jsonDecode(utf8.decode(base64Decode(row.data))), jsonDecode(text));
      expect(CustomRoutingService.read(row).entryCount, 1);
      await service.save(name: 'Two', text: text);
      await service.save(name: 'Three', text: text);
      await expectLater(
        service.save(name: 'Four', text: text),
        throwsStateError,
      );
      await service.save(id: id, name: 'Edited', text: text);
      expect((await database.routingProfileDao.searchRow(id))!.name, 'Edited');
      await expectLater(
        service.save(
          id: id,
          name: 'Hidden',
          text: '{"outbounds":[{}],"inbounds":[]}',
        ),
        throwsFormatException,
      );
      expect((await database.routingProfileDao.searchRow(id))!.name, 'Edited');
    },
  );
}
