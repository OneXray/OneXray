import 'dart:async';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/pages/home/share/controller.dart';
import 'package:onexray/pages/home/share/params.dart';
import 'package:onexray/service/event_bus/service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ShareController controller;

  setUp(() {
    final eventBus = AppEventBus();
    addTearDown(eventBus.close);
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() async {
    await controller.close();
    await db.close();
  });

  Future<void> loadSubscription({
    Future<Uint8List?> Function(String)? qrEncoder,
  }) async {
    final id = await db.subscriptionDao.insertRow(
      SubscriptionCompanion.insert(
        name: 'My subscription',
        url: 'https://example.test/subscription',
        ageSecretKey: const Value('AGE-SECRET-KEY-1PRIVATE'),
        agePublicKey: const Value('age1public'),
        timestamp: DateTime(2026, 9, 1),
        count: 2,
        expanded: true,
      ),
    );
    controller = ShareController(
      SharePageParams(ShareType.subscription, id),
      database: db,
      qrEncoder: qrEncoder,
    );
    await controller.stream.firstWhere((state) => !state.loading);
  }

  test(
    'starts with the original link and shares Age type, never keys',
    () async {
      var qrCalls = 0;
      await loadSubscription(
        qrEncoder: (_) async {
          qrCalls++;
          return Uint8List(0);
        },
      );
      expect(controller.state.name, 'My subscription');
      expect(controller.state.format, ShareLinkFormat.original);
      expect(controller.state.qrExpanded, isFalse);
      expect(controller.state.qrCode, isNull);
      expect(qrCalls, 0);
      expect(
        controller.state.selectedLink,
        'https://example.test/subscription#My%20subscription',
      );

      controller.selectFormat(ShareLinkFormat.onexray);
      final link = Uri.parse(controller.state.selectedLink);
      expect(link.scheme, 'onexray');
      expect(Uri.decodeComponent(link.fragment), 'My subscription');
      expect(link.queryParameters['age'], 'x25519');
      expect(controller.state.selectedLink, isNot(contains('PRIVATE')));
      expect(controller.state.selectedLink, isNot(contains('age1public')));
      expect(qrCalls, 0);
    },
  );

  test('format changes and collapsing discard obsolete QR results', () async {
    final links = <String>[];
    final results = <Completer<Uint8List?>>[];
    await loadSubscription(
      qrEncoder: (link) {
        links.add(link);
        final result = Completer<Uint8List?>();
        results.add(result);
        return result.future;
      },
    );
    controller.toggleQr();
    controller.selectFormat(ShareLinkFormat.onexray);
    controller.selectFormat(ShareLinkFormat.original);
    expect(links, [
      controller.state.originalLink,
      controller.state.appLink,
      controller.state.originalLink,
    ]);
    results[0].complete(Uint8List.fromList([1]));
    results[1].complete(Uint8List.fromList([2]));
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.qrCode, isNull);
    results[2].complete(Uint8List.fromList([3]));
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.qrCode, [3]);

    controller.selectFormat(ShareLinkFormat.onexray);
    expect(controller.state.qrCode, isNull);
    controller.toggleQr();
    results[3].complete(Uint8List.fromList([4]));
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.qrExpanded, isFalse);
    expect(controller.state.qrCode, isNull);
  });

  test('a missing subscription stops loading and exposes failure', () async {
    controller = ShareController(
      SharePageParams(ShareType.subscription, 999),
      database: db,
    );
    await controller.stream.firstWhere((state) => !state.loading);
    expect(controller.state.selectedLink, isEmpty);
    expect(controller.state.linkError, isNotEmpty);
    expect(controller.state.qrCode, isNull);
  });
}
