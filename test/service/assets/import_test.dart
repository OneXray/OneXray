import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/network/client.dart';
import 'package:onexray/service/assets/import.dart';
import 'package:onexray/service/db/config_writer.dart';
import 'package:onexray/service/share/app_link_model.dart';
import 'package:onexray/service/share/xray_share_reader.dart';
import 'package:onexray/service/subscription/model.dart';
import 'package:onexray/service/xray/outbound/state_db.dart';
import 'package:onexray/service/xray/raw/db.dart';

void main() {
  test('manual detection has no writes; confirmation writes once and queues the saved IDs', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final queued = <int>[];
    final service = ServerImportService(
      validate: (_) async => '',
      write: (rows) => ConfigWriter.writeRowsInTransaction(db, rows, null),
      schedule: queued.addAll,
    );
    const source =
        '{"outbounds":[{"tag":"one","protocol":"freedom"},{"tag":"two","protocol":"freedom"}]}';
    final preview = await service.preview(source, manual: true);
    expect(preview.count, 2);
    expect(preview.failureCount, 0);
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
    expect(saved.every((row) => row.lastMeasuredAt == null), true);
  });

  test('manual invalid member or duplicate tag rejects the whole input before native validation', () async {
    var validations = 0;
    final service = ServerImportService(
      validate: (_) async {
        validations++;
        return '';
      },
    );
    for (final source in [
      '{"outbounds":[]}',
      '{"outbounds":[{"tag":"one","protocol":"freedom"},{}]}',
      '{"outbounds":[{"tag":"one","protocol":"freedom"},{"tag":"one","protocol":"freedom"}]}',
    ]) {
      await expectLater(
        service.preview(source, manual: true),
        throwsFormatException,
      );
    }
    expect(validations, 0);
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
    expect(
      preview.failureCount,
      0,
    ); // Every OneXray link was decoded and validated locally.
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
      parseReport: (text) async {
        events.add('preview');
        expect(text.trim(), 'vless://local');
        return ShareParseReport([node], failureCount: 3);
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
    expect(preview.failureCount, 3);
    // Cancel means commit is never called; the completed subscription is kept.
    expect(subscriptions.first.result.subId, 7);
  });

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
    expect(result.failureCount, 0);
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
    expect(preview.failureCount, 2);
    await expectLater(service.commit(preview), throwsFormatException);
  });

  test('zero usable and unavailable counts are not guessed; structured input remains intact', () async {
    final zero = ServerImportService(
      parseReport: (_) async => const ShareParseReport([], failureCount: 2),
    );
    final failed = await zero.preview('vless://invalid');
    expect(failed.hasItems, false);
    expect(failed.failureCount, 2);
    final unknown = await ServerImportService(parse: (_) async => [])
        .preview('plain text');
    expect(unknown.failureCount, isNull);
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
