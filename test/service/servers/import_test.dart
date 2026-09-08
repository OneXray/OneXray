import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/network/client.dart';
import 'package:onexray/service/servers/import.dart';
import 'package:onexray/service/shared/db/config_writer.dart';
import 'package:onexray/service/shared/share/app_link_model.dart';
import 'package:onexray/service/servers/subscription/model.dart';
import 'package:onexray/service/servers/outbound/state_db.dart';
import 'package:onexray/service/connect/raw/db.dart';

void main() {
  test('preparation has no writes; commit writes once and queues the saved IDs', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final queued = <int>[];
    final validated = <Map<String, dynamic>>[];
    final service = ServerImportService(
      database: db,
      validate: (text) async {
        validated.add(jsonDecode(text) as Map<String, dynamic>);
        return '';
      },
      write: (rows) => ConfigWriter.writeRowsInTransaction(db, rows, null),
      schedule: queued.addAll,
    );
    const source =
        '{"outbounds":[{"tag":"one","protocol":"freedom"},{"tag":"two","protocol":"freedom"}]}';
    final preview = await service.preview(source, manual: true);
    expect(validated, [jsonDecode(source)]);
    expect(preview.count, 2);
    expect(await db.coreConfigDao.allOutboundRowsWithDataBySubId(0), isEmpty);
    expect(queued, isEmpty);
    final result = await service.commit(preview);
    final saved = await db.coreConfigDao.allOutboundRowsWithDataBySubId(0);
    expect(result.count, 2);
    expect(queued, saved.map((row) => row.id));
    expect(saved.map(readOutboundFromDbData).map((node) => node['tag']), [
      'one',
      'two',
    ]);
    expect(saved.every((row) => row.delay == PingDelayConstants.unknown), true);
  });

  test(
    'manual import delegates node values and duplicate tags to libXray',
    () async {
      final inputs = <Map<String, dynamic>>[];
      final service = ServerImportService(
        validate: (text) async {
          inputs.add(jsonDecode(text) as Map<String, dynamic>);
          return '';
        },
      );
      final outbounds = [
        {'tag': 'same', 'protocol': 'vmess', 'settings': <String, dynamic>{}},
        {
          'tag': 'same',
          'protocol': 'vmess',
          'settings': {'security': 'none'},
        },
        {'protocol': 'freedom'},
      ];
      final preview = await service.preview(
        jsonEncode({'outbounds': outbounds}),
        manual: true,
      );
      expect(inputs.single['outbounds'], outbounds);
      expect(preview.rows.map((row) => row.name.value), [
        'same',
        'same',
        'freedom',
      ]);
    },
  );

  test('libXray rejection aborts manual import before persistence', () async {
    var validations = 0;
    final service = ServerImportService(
      validate: (_) async {
        validations++;
        return 'Invalid node';
      },
      write: (_) async => throw StateError('Must not write rejected input'),
    );
    for (final source in [
      '{"outbounds":[{"tag":"one","protocol":"freedom"},{}]}',
      '{"outbounds":[1]}',
    ]) {
      await expectLater(
        service.preview(source, manual: true),
        throwsFormatException,
      );
    }
    expect(validations, 2);
  });

  test('OneXray node links use the existing decoder; subscriptions stay read-only form inputs', () async {
    final link = Uri(
      scheme: 'onexray',
      host: 'onexray.com',
      path: '/config/add',
      queryParameters: {
        'type': 'outbound',
        'data': base64Encode(
          utf8.encode(
            '{"outbounds":[{"tag":"same-name","protocol":"freedom"}]}',
          ),
        ),
      },
    );
    final service = ServerImportService(
      parse: (_) async => throw StateError('Unexpected native parsing'),
      validate: (_) async => '',
    );
    final preview = await service.preview('$link\n$link');
    expect(
      preview.count,
      2,
    ); // Equal labels never collapse distinct imported assets.
    final subscription = ServerImportService.singleLink(
      'https://provider.example/list#Provider',
    );
    expect(subscription, isA<OneXraySubscriptionLink>());
    expect(
      (subscription as OneXraySubscriptionLink).url,
      'https://provider.example/list',
    );
    expect(subscription.name, 'Provider');
    expect(
      ServerImportService.singleLink('http://provider.example/list'),
      isNull,
    );
  });

  test('HTTPS restriction rejects initial cleartext and downgraded redirect targets', () async {
    final origin = Uri.parse('https://provider.example/sub');
    expect(NetClient.isHttpsDownloadUri(origin), true);
    expect(NetClient.isHttpsDownloadUri(origin.resolve('/next')), true);
    for (final target in [
      'http://provider.example/next',
      'https://user:secret@provider.example/next',
      'file:///tmp/sub',
    ]) {
      expect(NetClient.isHttpsDownloadUri(origin.resolve(target)), false);
      expect(await NetClient().getText(target, httpsOnly: true), isNull);
    }
  });

  test('mixed detection imports subscriptions independently before read-only local preview', () async {
    final events = <String>[];
    final node = outboundCompanion({'tag': 'local', 'protocol': 'freedom'});
    final service = ServerImportService(
      subscribe: (link) async {
        events.add('subscription:${link.name}');
        return SubscriptionInsertResult(
          status: link.name == 'good'
              ? SubscriptionUpdateResult.success
              : SubscriptionUpdateResult.downloadFailed,
          count: link.name == 'good' ? 2 : 0,
          subId: link.name == 'good' ? 7 : 0,
        );
      },
      parse: (text) async {
        events.add('preview');
        expect(text.trim(), 'vless://local');
        return [node];
      },
      write: (_) async =>
          throw StateError('Cancelled local content must not write'),
      schedule: (_) =>
          throw StateError('Cancelled local content must not queue'),
    );
    final detected = service.detect(
      'https://provider.example/a#good\nhttps://provider.example/b#bad\nvless://local',
    );
    expect(events, isEmpty);
    final subscriptions = await service.importSubscriptions(
      detected.subscriptions,
    );
    final preview = await service.preview(detected.localText);
    expect(events, ['subscription:good', 'subscription:bad', 'preview']);
    expect(subscriptions.map((item) => item.result.success), [true, false]);
    expect(preview.count, 1);
    // Cancel means commit is never called; the completed subscription is kept.
    expect(subscriptions.first.result.subId, 7);
  });

  test(
    'clear-data stops the imported subscription list after its active source',
    () async {
      final started = Completer<void>();
      final release = Completer<void>();
      final events = <String>[];
      final service = ServerImportService(
        subscribe: (link) async {
          if (!started.isCompleted) {
            started.complete();
            await release.future;
          }
          events.add(link.name);
          return const SubscriptionInsertResult(
            status: SubscriptionUpdateResult.success,
            subId: 1,
            count: 1,
          );
        },
      );
      final links = service
          .detect('https://example.com/one#one\nhttps://example.com/two#two')
          .subscriptions;
      final importing = service.importSubscriptions(links);
      await started.future;
      final clearing = ServerImportService.pauseForDataClear().then(
        (_) => events.add('clear'),
      );
      addTearDown(ServerImportService.resumeAfterDataClear);
      release.complete();
      expect(
        (await importing).every((result) => result.result.success),
        isTrue,
      );
      await clearing;
      expect(events, ['one', 'clear']);
    },
  );

  test('Raw and data sources stay read-only until confirmation and partial results remain distinct', () async {
    const raw =
        '{ "name": "Expert", "outbounds": [{"protocol":"freedom"}], "custom": true }';
    final node = _configLink(
      'outbound',
      '{"outbounds":[{"tag":"local","protocol":"freedom"}]}',
    );
    final rawLink = _configLink('raw', raw);
    final writes = <CoreConfigCompanion>[];
    final queued = <int>[];
    final downloaded = <String>[];
    final service = ServerImportService(
      validate: (_) async => '',
      validateGeoData: (_) async => true,
      writeGeoData: (link) async {
        downloaded.add(link.name);
        return link.name == 'good-data';
      },
      write: (rows) async {
        writes.addAll(rows);
        return ConfigWriteResult(
          count: rows.length,
          ids: List.generate(rows.length, (index) => 20 + index),
        );
      },
      schedule: queued.addAll,
    );
    final preview = await service.preview(
      '$node\n$rawLink\n${_geoLink('good-data')}\n${_geoLink('failed-data')}',
    );
    expect(preview.count, 1);
    expect(preview.rawCount, 1);
    expect(preview.geoData, hasLength(2));
    expect(writes, isEmpty);
    expect(downloaded, isEmpty);
    final result = await service.commit(preview);
    expect(result.count, 1);
    expect(result.rawCount, 1);
    expect(result.geoDataCount, 1);
    expect(result.failedGeoData.single.name, 'failed-data');
    expect(utf8.decode(base64Decode(writes[1].data.value!)), raw);
    expect(queued, [20]); // Only the outbound, never the Raw config.
    expect(
      XrayRawDb.configCompanion('Expert', raw).data.value,
      writes[1].data.value,
    );
  });

  test('unrecognized legacy assets and unsafe data names cannot become Raw or file paths', () async {
    final service = ServerImportService(validateGeoData: (_) async => true);
    final preview = await service.preview(
      '${_configLink('profile', '{"name":"legacy"}')}\n${_geoLink('../outside')}',
    );
    expect(preview.hasItems, false);
    expect(preview.rawCount, 0);
    await expectLater(service.commit(preview), throwsFormatException);
  });

  test('empty parsed lists cannot be imported; structured input remains intact', () async {
    final zero = ServerImportService(parse: (_) async => []);
    final failed = await zero.preview('vless://invalid');
    expect(failed.hasItems, false);
    await expectLater(zero.commit(failed), throwsFormatException);
    final unknown = await ServerImportService(parse: (_) async => [])
        .preview('plain text');
    expect(unknown.hasItems, false);
    const yaml =
        'proxies:\n  - name: sample\n    description: |\n      https://not-a-subscription.example';
    final detection = zero.detect(yaml);
    expect(detection.subscriptions, isEmpty);
    expect(detection.localText, yaml);
  });
}

String _configLink(String type, String json) => Uri(
  scheme: 'onexray',
  host: 'onexray.com',
  path: '/config/add',
  queryParameters: {'type': type, 'data': base64Encode(utf8.encode(json))},
).toString();

String _geoLink(String name) => Uri(
  scheme: 'onexray',
  host: 'onexray.com',
  path: '/dat/add',
  fragment: name,
  queryParameters: {'type': 'domain', 'url': 'https://data.example/list.dat'},
).toString();
