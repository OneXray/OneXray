import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/network/client.dart';
import 'package:onexray/service/assets/import.dart';
import 'package:onexray/service/db/config_writer.dart';
import 'package:onexray/service/share/app_link_model.dart';
import 'package:onexray/service/xray/outbound/state_db.dart';

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
    );
    final preview = await service.preview('$link\n$link');
    expect(
      preview.count,
      2,
    ); // Equal labels never collapse distinct imported assets.
    expect(
      preview.failureCount,
      isNull,
    ); // The converter has no exact rejected count yet.
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
}
