import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/pigeon/constants.dart';
import 'package:onexray/service/connect/routing/custom/service.dart';
import 'package:onexray/service/connect/routing/custom/state.dart';

void main() {
  test('routing validation passes native fields to libXray with local entry placeholders', () async {
    final state = RoutingProfileState(
      name: 'Route',
      entryCount: 3,
      domainStrategy: 'IPOnDemand',
      rules: [RoutingRuleState(port: 0, network: 'TCP')],
    );
    final source = state.encode();
    expect(jsonDecode(source)['outbounds'], [{}, {}, {}]);
    var calls = 0;
    Future<String> check(String text) async {
      calls++;
      final config = jsonDecode(text);
      expect(config['env']['xray.location.asset'], VpnConstants.datDir);
      expect(config['outbounds'], [
        for (var i = 0; i < 3; i++)
          {'tag': 'app-entry-$i', 'protocol': 'freedom'},
        {'tag': 'direct', 'protocol': 'freedom'},
        {'tag': 'block', 'protocol': 'blackhole'},
      ]);
      expect(config['routing']['domainStrategy'], 'IPOnDemand');
      expect(config['routing']['rules'], [state.rules.single.toJson()]);
      expect(config['routing']['balancers'].single, {
        'tag': 'proxy',
        'selector': ['app-entry-0', 'app-entry-1', 'app-entry-2'],
        'fallbackTag': 'direct',
      });
      return calls == 1 ? '' : 'Core rejected rule';
    }

    await CustomRoutingService.validate(state, testXray: check);
    await expectLater(
      CustomRoutingService.validate(state, testXray: check),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          'Core rejected rule',
        ),
      ),
    );
    expect(calls, 2);
    expect(state.encode(), source);
  });

  test(
    'names use Unicode characters and trimmed case-insensitive uniqueness',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final service = CustomRoutingService(database);
      final id = await service.save(RoutingProfileState(name: ' Route '));
      expect((await database.routingProfileDao.searchRow(id))!.name, 'Route');
      await expectLater(
        service.save(RoutingProfileState(name: 'route')),
        throwsFormatException,
      );
      final name = List.filled(32, '🌐').join();
      await service.save(RoutingProfileState(id: id, name: name));
      expect((await database.routingProfileDao.searchRow(id))!.name, name);
    },
  );
  test(
    'custom saves share one strict limit/encoding boundary; edits stay allowed',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final service = CustomRoutingService(database);
      final state = RoutingProfileState(
        name: 'One',
        rules: [
          RoutingRuleState(
            ruleTag: 'Example',
            domain: const ['domain:example.com'],
            action: RoutingRuleAction.direct,
          ),
        ],
      );
      final id = await service.save(state);
      final row = (await database.routingProfileDao.searchRow(id))!;
      final stored = jsonDecode(utf8.decode(base64Decode(row.data))) as Map;
      expect(stored['outbounds'], [{}]);
      expect(stored.containsKey('name'), false);
      expect(stored.containsKey('geodata'), false);
      final roundTrip = CustomRoutingService.read(row);
      expect(roundTrip.id, id);
      expect(roundTrip.name, 'One');
      expect(roundTrip.entryCount, 1);
      expect(roundTrip.rules.single.toJson(), state.rules.single.toJson());
      await service.save(RoutingProfileState(name: 'Two'));
      await service.save(RoutingProfileState(name: 'Three'));
      await expectLater(
        service.save(RoutingProfileState(name: 'Four')),
        throwsStateError,
      );
      await service.save(state.copyWith(id: id, name: 'Edited'));
      expect((await database.routingProfileDao.searchRow(id))!.name, 'Edited');
      await expectLater(
        service.save(state.copyWith(id: id, name: 'Hidden', entryCount: 4)),
        throwsFormatException,
      );
      expect((await database.routingProfileDao.searchRow(id))!.name, 'Edited');
    },
  );
}
