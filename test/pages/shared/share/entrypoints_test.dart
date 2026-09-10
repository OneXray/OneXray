import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/pages/shared/share/controller.dart';
import 'package:onexray/pages/shared/share/page.dart';
import 'package:onexray/pages/shared/share/params.dart';
import 'package:onexray/pages/shared/widgets/adaptive_dialog.dart';
import 'package:onexray/pages/shared/widgets/button_progress.dart';
import 'package:onexray/pages/shared/widgets/configuration_transfer.dart';
import 'package:onexray/service/shared/event_bus/service.dart';
import 'package:onexray/service/shared/share/app_link_model.dart';
import 'package:onexray/service/shared/share/app_link_parser.dart';
import 'package:onexray/service/shared/share/configuration_transfer.dart';
import 'package:onexray/service/shared/share/outgoing_share.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'test_app.dart';

void main() {
  setUp(() {
    final bus = AppEventBus();
    addTearDown(bus.close);
  });

  group('Node/subscription share page', () {
    late AppDatabase db;
    late int subscriptionId;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      subscriptionId = await db.subscriptionDao.insertRow(
        SubscriptionCompanion.insert(
          name: 'My subscription',
          url: 'https://example.test/subscription',
          ageSecretKey: const Value('AGE-SECRET-KEY-1PRIVATE'),
          agePublicKey: const Value('age1public'),
          timestamp: DateTime(2026, 9, 1),
        ),
      );
    });
    tearDown(() => db.close());

    testWidgets('unavailable keeps formats available and never copies', (
      tester,
    ) async {
      final sent = <ShareParams>[];
      await tester.pumpWidget(
        ShareTestApp(
          child: SharePage(
            params: SharePageParams(ShareType.subscription, subscriptionId),
            database: db,
            outgoingShare: OutgoingShare(
              destination: ShareDestination.system,
              platform: SharePlus.custom(
                FakeSharePlatform((params) async {
                  sent.add(params);
                  return ShareResult.unavailable;
                }),
              ),
              writeClipboard: (_) async => fail('No clipboard fallback'),
            ),
          ),
        ),
      );
      final controller = tester
          .element(find.byType(AppDialog))
          .read<ShareController>();
      await tester.runAsync(() async {
        if (controller.state.loading) {
          await controller.stream.firstWhere((state) => !state.loading);
        }
      });
      await tester.pumpAndSettle();

      final button = find.widgetWithText(FilledButton, 'Share');
      final anchor = tester.getRect(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(
        sent.single.text,
        'https://example.test/subscription#My%20subscription',
      );
      expect(sent.single.title, 'My subscription');
      expect(sent.single.subject, 'My subscription');
      expect(sent.single.sharePositionOrigin, anchor);
      expect(find.byType(SharePage), findsOneWidget);
      expect(find.byType(ShadToast), findsNothing);

      await tester.tap(find.text('OneXray link'));
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(sent, hasLength(2));
      final link = Uri.parse(sent.last.text!);
      expect(link.scheme, 'onexray');
      expect(link.queryParameters['age'], 'x25519');
      expect(sent.last.text, isNot(contains('PRIVATE')));
      expect(sent.last.text, isNot(contains('age1public')));
      expect(find.text('Show QR code'), findsOneWidget);
      expect(find.byType(ShadToast), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Linux uses an explicit copy action without closing the page', (
      tester,
    ) async {
      final copied = <String>[];
      await tester.pumpWidget(
        ShareTestApp(
          child: SharePage(
            params: SharePageParams(ShareType.subscription, subscriptionId),
            database: db,
            outgoingShare: OutgoingShare(
              destination: ShareDestination.clipboard,
              writeClipboard: (text) async => copied.add(text),
            ),
          ),
        ),
      );
      final controller = tester
          .element(find.byType(AppDialog))
          .read<ShareController>();
      await tester.runAsync(() async {
        if (controller.state.loading) {
          await controller.stream.firstWhere((state) => !state.loading);
        }
      });
      await tester.pumpAndSettle();
      expect(find.byIcon(LucideIcons.copy), findsOneWidget);
      expect(find.byIcon(LucideIcons.share2), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'Copy share link'));
      await tester.pumpAndSettle();
      expect(copied, ['https://example.test/subscription#My%20subscription']);
      expect(find.byType(SharePage), findsOneWidget);
      expect(find.byType(ShadToast), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  for (final kind in ConfigurationKind.values) {
    for (final copy in [false, true]) {
      testWidgets('${kind.name} tools share from their button, copy=$copy', (
        tester,
      ) async {
        const source = ' { "outbounds": [{}], "routing": {"rules": []} }\n';
        final controller = ConfigurationTransferController(
          kind: kind,
          readText: () => source,
          readName: () => 'Draft',
          onImport: (_) => fail('Sharing must not import'),
          service: ConfigurationTransferService(
            lookup: (_) async => null,
            prepare: (_) async => throw StateError('Sharing must not download'),
          ),
        );
        addTearDown(controller.close);
        final result = Completer<ShareResult>();
        final sent = <ShareParams>[];
        final copied = <String>[];
        final outgoing = OutgoingShare(
          destination: copy
              ? ShareDestination.clipboard
              : ShareDestination.system,
          platform: SharePlus.custom(
            FakeSharePlatform((params) {
              sent.add(params);
              return result.future;
            }),
          ),
          writeClipboard: (text) async => copied.add(text),
        );
        await tester.pumpWidget(
          ShareTestApp(
            child: ListView.builder(
              itemCount: 2,
              itemBuilder: (_, index) => index == 0
                  ? const SizedBox(height: 40)
                  : ConfigurationTransferTools(
                      controller: controller,
                      outgoingShare: outgoing,
                    ),
            ),
          ),
        );
        final label = copy ? 'Copy share link' : 'Share';
        final button = find.widgetWithText(OutlinedButton, label);
        expect(
          find.byIcon(copy ? LucideIcons.copy : LucideIcons.share2),
          findsOneWidget,
        );
        await tester.tap(button);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(ShadDialog), findsOneWidget);
        expect(sent, isEmpty);
        expect(copied, isEmpty);
        final anchor = tester.getRect(button);
        await tester.tap(find.widgetWithText(ShadButton, label));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(controller.busy, isFalse);
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Export JSON'),
              )
              .onPressed,
          isNotNull,
        );
        expect(controller.notice, isNull);

        late String links;
        if (copy) {
          expect(sent, isEmpty);
          links = copied.single;
          expect(find.text('Configuration share links copied'), findsOneWidget);
        } else {
          expect(copied, isEmpty);
          links = sent.single.text!;
          expect(sent.single.sharePositionOrigin, anchor);
          expect(sent.single.title, 'Draft');
          expect(sent.single.subject, 'Draft');
          expect(find.byType(ButtonProgressIndicator), findsOneWidget);
          result.complete(ShareResult.unavailable);
        }
        await tester.pumpAndSettle();
        final link =
            OneXrayAppLinkParser.parse(Uri.parse(links))! as OneXrayConfigLink;
        expect(
          link.type,
          kind == ConfigurationKind.raw
              ? OneXrayConfigLinkType.raw
              : OneXrayConfigLinkType.custom,
        );
        expect(link.name, 'Draft');
        if (kind == ConfigurationKind.raw) {
          expect(link.xrayJson, source);
        } else {
          final json = jsonDecode(link.xrayJson) as Map<String, dynamic>;
          expect(json['name'], 'Draft');
          expect(json['outbounds'], [{}]);
        }
        expect(find.byType(ConfigurationTransferTools), findsOneWidget);
        expect(find.byType(ButtonProgressIndicator), findsNothing);
        if (!copy) expect(find.byType(ShadToast), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
