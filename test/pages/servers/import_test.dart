import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/model/geo_data_type.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/servers/import/controller.dart';
import 'package:onexray/pages/servers/import/page.dart';
import 'package:onexray/pages/subscriptions/widget/form_view.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/pages/widget/adaptive_dialog.dart';
import 'package:onexray/pages/widget/button_progress.dart';
import 'package:onexray/service/assets/import.dart';
import 'package:onexray/service/db/config_writer.dart';
import 'package:onexray/service/share/app_link_model.dart';
import 'package:onexray/service/share/xray_share_reader.dart';
import 'package:onexray/service/subscription/model.dart';
import 'package:onexray/service/xray/outbound/state_db.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  test('submit availability follows text, HTTPS, and Age state', () async {
    final controller = ServerImportController(
      loadSubscription: (_) async => null,
    );
    addTearDown(controller.close);
    var changes = 0;
    final subscription = controller.stream.listen((_) => changes++);
    addTearDown(subscription.cancel);

    expect(controller.canSubmit(ServerImportAction.paste), isFalse);
    controller.text.text = 'vless://local';
    expect(controller.canSubmit(ServerImportAction.paste), isTrue);
    expect(controller.canSubmit(ServerImportAction.json), isFalse);
    controller.jsonText.text = '{"protocol":"vless"}';
    expect(controller.canSubmit(ServerImportAction.json), isTrue);
    controller.jsonText.text = '  ';
    expect(controller.canSubmit(ServerImportAction.json), isFalse);

    controller.name.text = 'Provider';
    expect(controller.canSubmit(ServerImportAction.subscription), isFalse);
    controller.url.text = 'http://provider.example/list';
    expect(controller.canSubmit(ServerImportAction.subscription), isFalse);
    controller.url.text = 'https://provider.example/list';
    expect(controller.canSubmit(ServerImportAction.subscription), isTrue);
    controller.secretKey.text = 'secret';
    expect(controller.canSubmit(ServerImportAction.subscription), isFalse);
    controller.publicKey.text = 'public';
    expect(controller.canSubmit(ServerImportAction.subscription), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(changes, 8);
  });

  testWidgets('Back returns to methods; Cancel closes only the import wizard', (
    tester,
  ) async {
    _mobileViewport(tester);
    var completed = false;
    ServerImportResult? result;
    var clipboardReads = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.getData') {
          clipboardReads++;
          return {'text': 'Do not read automatically'};
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showAppDialog<ServerImportResult>(
                context,
                (_) => const ServersImportPage(),
              );
              completed = true;
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paste link'));
    await tester.pumpAndSettle();
    expect(find.byType(ServerImportFormPage), findsOneWidget);
    final controller = tester
        .widget<ServerImportFormPage>(find.byType(ServerImportFormPage))
        .controller;
    expect(controller.text.text, isEmpty);
    expect(clipboardReads, 0);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Add servers to OneXray'), findsOneWidget);
    expect(completed, isFalse);

    await tester.tap(find.text('Paste link'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ServerImportFormPage>(find.byType(ServerImportFormPage))
          .controller,
      same(controller),
    );
    await tester.tap(find.byTooltip('Close dialog'));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(result, isNull);
    expect(find.byType(ServerImportFormPage), findsNothing);
    expect(find.text('Add servers to OneXray'), findsNothing);
    expect(find.text('Open'), findsOneWidget);
    expect(Navigator.of(tester.element(find.text('Open'))).canPop(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'preview Cancel unwinds form and method dialogs without a write',
    (tester) async {
      _mobileViewport(tester);
      var writes = 0;
      var completed = false;
      final controller = ServerImportController(
        loadSubscription: (_) async => null,
        service: ServerImportService(
          parseReport: (_) async => ShareParseReport([
            outboundCompanion({'tag': 'local', 'protocol': 'freedom'}),
          ], failureCount: 0),
          write: (_) async {
            writes++;
            throw StateError('Cancel cannot write');
          },
        ),
      );
      addTearDown(controller.close);
      controller.text.text = 'vless://local';
      await tester.pumpWidget(_wizard(controller, (_) => completed = true));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paste route'));
      await tester.pumpAndSettle();
      await _tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Import links'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ServerImportPreviewPage), findsOneWidget);
      controller.closeFlow(
        tester.element(find.byType(ServerImportPreviewPage)),
      );
      await tester.pumpAndSettle();
      expect(completed, isTrue);
      expect(writes, 0);
      expect(find.byType(ServerImportPreviewPage), findsNothing);
      expect(find.byType(ServerImportFormPage), findsNothing);
      expect(find.text('Choose method'), findsNothing);
      expect(Navigator.of(tester.element(find.text('Open'))).canPop(), isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'preview Back and retry keep subscriptions; Cancel reports completed imports',
    (tester) async {
      var imported = 0;
      var writes = 0;
      ServerImportResult? result;
      final service = ServerImportService(
        subscribe: (_) async {
          imported++;
          return const SubscriptionInsertResult(
            status: SubscriptionUpdateResult.success,
            subId: 7,
            count: 2,
            parseFailureCount: 0,
          );
        },
        parseReport: (_) async => ShareParseReport([
          outboundCompanion({'tag': 'local', 'protocol': 'freedom'}),
        ], failureCount: 0),
        write: (_) async {
          writes++;
          throw StateError('The user cancelled');
        },
      );
      final controller = ServerImportController(
        service: service,
        loadSubscription: (_) async => null,
      );
      addTearDown(controller.close);
      controller.text.text =
          'https://provider.example/list#Provider\nvless://local';
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<ServerImportResult>(
                  MaterialPageRoute(
                    builder: (_) => AppDialogFrame(
                      child: ServerImportFormPage(
                        controller: controller,
                        action: ServerImportAction.paste,
                      ),
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await _tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Import links'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ServerImportPreviewPage), findsOneWidget);
      expect(
        find.text(
          '1 subscriptions imported. Only the remaining local items need confirmation.',
        ),
        findsOneWidget,
      );
      expect(imported, 1);
      expect(writes, 0);
      controller.closePage(
        tester.element(find.byType(ServerImportPreviewPage)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ServerImportFormPage), findsOneWidget);
      expect(result, isNull);
      await _tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Import links'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ServerImportPreviewPage), findsOneWidget);
      expect(imported, 1);
      await _tapVisible(tester, find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result?.count, 2);
      expect(result?.subscriptionCount, 1);
      expect(imported, 1);
      expect(writes, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('editing reuses the complete Age form and only saves metadata', (
    tester,
  ) async {
    SubscriptionInput? saved;
    int? savedId;
    int? routeResult;
    final saveCompletion = Completer<SubscriptionUpdateResult>();
    final controller = ServerImportController(
      subscriptionId: 7,
      loadSubscription: (_) async => SubscriptionData(
        id: 7,
        name: 'Provider',
        url: 'https://provider.example/list',
        ageSecretKey: 'secret',
        agePublicKey: 'public',
        timestamp: DateTime(2026),
        count: 2,
        expanded: true,
      ),
      validateSubscription: (_, id) async {
        expect(id, 7);
        return null;
      },
      saveSubscriptionInput: (id, input) async {
        savedId = id;
        saved = input;
        return saveCompletion.future;
      },
    );
    addTearDown(controller.close);
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              routeResult = await Navigator.of(context).push<int>(
                MaterialPageRoute(
                  builder: (_) => AppDialogFrame(
                    child: ServerImportFormPage(
                      controller: controller,
                      action: ServerImportAction.subscription,
                    ),
                  ),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await controller.loadSubscription(
      tester.element(find.byType(ServerImportFormPage)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SubscriptionFormView), findsOneWidget);
    expect(
      find.text('Changes apply to future updates, not the running connection.'),
      findsOneWidget,
    );
    expect(controller.secretKey.text, 'secret');
    expect(controller.publicKey.text, 'public');
    controller.toggleSecret();
    expect(controller.state.obscureSecret, false);
    controller.name.text = 'Renamed';
    await _tapVisible(tester, find.text('Save'));
    await tester.pump();
    expect(find.text('Save'), findsOneWidget);
    expect(find.byType(ButtonProgressIndicator), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(
      tester
          .widgetList<ShadInput>(find.byType(ShadInput))
          .every((input) => input.enabled),
      isTrue,
    );
    expect(controller.state.canClose, isFalse);
    controller.name.text = 'Another draft';
    expect(saved?.name, 'Renamed');
    saveCompletion.complete(SubscriptionUpdateResult.success);
    await tester.pumpAndSettle();
    expect(savedId, 7);
    expect(saved?.name, 'Renamed');
    expect(saved?.ageSecretKey, 'secret');
    expect(saved?.agePublicKey, 'public');
    expect(routeResult, 7);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'loading subscription preserves input and does not block closing',
    (tester) async {
      final loaded = Completer<SubscriptionData?>();
      final controller = ServerImportController(
        subscriptionId: 7,
        loadSubscription: (_) => loaded.future,
      );
      addTearDown(controller.close);
      await tester.pumpWidget(
        _app(
          ServerImportFormPage(
            controller: controller,
            action: ServerImportAction.subscription,
          ),
        ),
      );
      final pending = controller.loadSubscription(
        tester.element(find.byType(ServerImportFormPage)),
      );
      await tester.pump();
      expect(controller.state.canClose, isTrue);
      expect(controller.state.submitting, isFalse);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byType(ButtonProgressIndicator), findsNothing);
      controller.name.text = 'Typed while loading';
      loaded.complete(
        SubscriptionData(
          id: 7,
          name: 'Provider',
          url: 'https://provider.example/list',
          timestamp: DateTime(2026),
          count: 2,
          expanded: true,
        ),
      );
      await pending;
      await tester.pumpAndSettle();
      expect(controller.name.text, 'Typed while loading');
      expect(controller.url.text, 'https://provider.example/list');
      expect(tester.takeException(), isNull);
    },
  );

  for (final exit in ['done', 'system', 'barrier']) {
    testWidgets(
      'partial local completion returns committed results without rewriting ($exit)',
      (tester) async {
        _mobileViewport(tester);
        var writes = 0;
        var downloads = 0;
        ServerImportResult? result;
        final service = ServerImportService(
          write: (rows) async {
            writes++;
            return ConfigWriteResult(count: rows.length, ids: [1]);
          },
          schedule: (_) {},
          writeGeoData: (_) async {
            downloads++;
            return false;
          },
        );
        final controller = ServerImportController(
          service: service,
          loadSubscription: (_) async => null,
        );
        addTearDown(controller.close);
        final preview = ServerImportPreview(
          [
            outboundCompanion({'tag': 'local', 'protocol': 'freedom'}),
          ],
          failureCount: 0,
          geoData: [
            const OneXrayGeoDataLink(
              name: 'Data source',
              type: GeoDataType.domain,
              url: 'https://data.example/list.dat',
            ),
          ],
        );
        await tester.pumpWidget(
          _app(
            Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showAppDialog<ServerImportResult>(
                    context,
                    (_) => ServerImportPreviewPage(
                      controller: controller,
                      preview: preview,
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await _tapVisible(tester, find.text('Confirm add'));
        await tester.pumpAndSettle();
        expect(find.text('Servers added'), findsOneWidget);
        expect(find.text('Data source'), findsOneWidget);
        expect(find.text('Done'), findsOneWidget);
        expect(controller.state.committedResult?.writeFailureCount, 1);
        if (exit == 'done') {
          await _tapVisible(tester, find.text('Done'));
        } else if (exit == 'system') {
          await Navigator.of(
            tester.element(find.byType(ServerImportPreviewPage)),
          ).maybePop();
        } else {
          await tester.tapAt(const Offset(5, 5));
        }
        await tester.pumpAndSettle();
        expect(find.byType(ServerImportPreviewPage), findsNothing);
        expect(result?.count, 1);
        expect(result?.writeFailureCount, 1);
        expect(writes, 1);
        expect(downloads, 1);
        expect(
          Navigator.of(tester.element(find.text('Open'))).canPop(),
          isFalse,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}

void _mobileViewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

Widget _wizard(
  ServerImportController controller,
  ValueChanged<ServerImportResult?> onResult,
) => _app(
  Builder(
    builder: (context) => TextButton(
      onPressed: () async {
        onResult(
          await showAppDialog<ServerImportResult>(
            context,
            (dialogContext) => AppDialog(
              title: 'Choose method',
              body: TextButton(
                onPressed: () =>
                    controller.open(dialogContext, ServerImportAction.paste),
                child: const Text('Paste route'),
              ),
            ),
          ),
        );
      },
      child: const Text('Open'),
    ),
  ),
);

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.light,
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  builder: (_, child) => ShadTheme(
    data: AppTheme.shad(Brightness.light),
    child: ShadToaster(child: child!),
  ),
  home: Scaffold(body: child),
);
