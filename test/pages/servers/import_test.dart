import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/model/geo_data_type.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/servers/import/controller.dart';
import 'package:onexray/pages/servers/import/page.dart';
import 'package:onexray/pages/subscriptions/widget/form_view.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/service/assets/import.dart';
import 'package:onexray/service/db/config_writer.dart';
import 'package:onexray/service/share/app_link_model.dart';
import 'package:onexray/service/share/xray_share_reader.dart';
import 'package:onexray/service/subscription/model.dart';
import 'package:onexray/service/xray/outbound/state_db.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets(
    'cancelling local preview keeps completed subscriptions and writes no local nodes',
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
      addTearDown(controller.dispose);
      controller.text.text =
          'https://provider.example/list#Provider\nvless://local';
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<ServerImportResult>(
                  MaterialPageRoute(
                    builder: (_) => ServerImportFormPage(
                      controller: controller,
                      action: ServerImportAction.paste,
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
      await tester.tap(find.text('Detect'));
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
      await tester.tap(find.text('Cancel'));
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
        return SubscriptionUpdateResult.success;
      },
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              routeResult = await Navigator.of(context).push<int>(
                MaterialPageRoute(
                  builder: (_) => ServerImportFormPage(
                    controller: controller,
                    action: ServerImportAction.subscription,
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
    expect(controller.obscureSecret, false);
    controller.name.text = 'Renamed';
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(savedId, 7);
    expect(saved?.name, 'Renamed');
    expect(saved?.ageSecretKey, 'secret');
    expect(saved?.agePublicKey, 'public');
    expect(routeResult, 7);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'partial local completion reports each source and Done cannot repeat writes',
    (tester) async {
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
      addTearDown(controller.dispose);
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
                result = await Navigator.of(context).push<ServerImportResult>(
                  MaterialPageRoute(
                    builder: (_) => ServerImportPreviewPage(
                      controller: controller,
                      preview: preview,
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
      await tester.tap(find.text('Confirm add'));
      await tester.pumpAndSettle();
      expect(find.text('Servers added'), findsOneWidget);
      expect(find.text('Data source'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(controller.committedResult?.writeFailureCount, 1);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(result?.count, 1);
      expect(result?.writeFailureCount, 1);
      expect(writes, 1);
      expect(downloads, 1);
      expect(tester.takeException(), isNull);
    },
  );
}

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
