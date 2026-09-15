import 'dart:async';

import 'package:drift/native.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/shared/event_bus/service.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/service/settings/language/locale.dart';
import 'package:onexray/pages/connect/json_editor/controller.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/pages/shared/widgets/json_editor.dart';
import 'package:onexray/service/connect/raw/editor.dart';
import 'package:onexray/service/connect/routing/custom/advanced.dart';
import 'package:onexray/service/connect/routing/custom/editor.dart';
import 'package:onexray/service/connect/coordinator.dart';
import 'package:onexray/service/shared/share/configuration_transfer.dart';
import 'package:re_editor/re_editor.dart';

void main() {
  setUp(() {
    final bus = AppEventBus();
    addTearDown(bus.close);
  });
  testWidgets(
    'Raw save follows name and JSON while draft loading does not connect',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final coordinator = ConnectionCoordinator(database: db);
      final controller = JsonConfigurationEditorController(
        configurationId: null,
        service: RawEditorService(database: db, coordinator: coordinator),
      );
      addTearDown(() async {
        await controller.close();
        coordinator.dispose();
        await db.close();
      });
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalePolicy.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: Text('Draft')),
        ),
      );
      await controller.load(tester.element(find.text('Draft')));
      expect(controller.canSave, isFalse);
      final changed = controller.stream.firstWhere(
        (state) => state.name == 'Private configuration',
      );
      controller.name.text = 'Private configuration';
      await changed;
      expect(controller.canSave, isTrue);
      controller.text.text = '';
      expect(controller.canSave, isFalse);
      controller.text.text = '{}';
      expect(controller.canSave, isTrue);
      expect(await db.coreConfigDao.allRawRowsWithData, isEmpty);
    },
  );

  testWidgets('Raw save retains transfer resources until the save finishes', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final coordinator = ConnectionCoordinator(database: db);
    final service = _PendingRawSave(database: db, coordinator: coordinator);
    final controller = JsonConfigurationEditorController(
      configurationId: null,
      service: service,
    );
    addTearDown(() async {
      coordinator.dispose();
      await db.close();
    });
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalePolicy.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: Text('Draft')),
      ),
    );
    final context = tester.element(find.text('Draft'));
    await controller.load(context);
    controller.name.text = 'Private configuration';

    final saving = controller.save(context);
    await service.started.future;
    unawaited(controller.close());
    await tester.pump();
    expect(controller.transfers.isClosed, isFalse);

    service.result.complete(1);
    await saving;
    await tester.pump();
    expect(controller.transfers.isClosed, isTrue);
  });

  testWidgets('plain JSON editor scrolls long content without a second frame', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(427, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = CodeLineEditingController.fromText(
      List.generate(100, (i) => '  "line$i": $i,').join('\n'),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.material(Brightness.light, mobile: true),
        home: Scaffold(
          body: SizedBox(
            height: 390,
            child: AppJsonEditor(controller: controller),
          ),
        ),
      ),
    );
    expect(find.text('xray.json'), findsNothing);
    final editor = find.byType(CodeEditor);
    final vertical = find.descendant(
      of: editor,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable &&
            (widget.axisDirection == AxisDirection.down ||
                widget.axisDirection == AxisDirection.up),
      ),
    );
    expect(vertical, findsOneWidget);
    final position = tester.state<ScrollableState>(vertical).position;
    expect(position.maxScrollExtent, greaterThan(500));
    position.jumpTo(500);
    await tester.pumpAndSettle();
    expect(position.pixels, 500);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'advanced editor uses its own template and keeps imported fields on save',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final coordinator = ConnectionCoordinator(database: db);
      final service = _PendingAdvancedSave(
        database: db,
        coordinator: coordinator,
      );
      final controller = JsonConfigurationEditorController(
        configurationId: null,
        kind: ConfigurationKind.customAdvanced,
        customService: service,
      );
      addTearDown(() async {
        await controller.close();
        coordinator.dispose();
        await db.close();
      });
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalePolicy.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: Text('Advanced draft')),
        ),
      );
      final context = tester.element(find.text('Advanced draft'));
      await controller.load(context);
      expect(controller.advanced, isTrue);
      expect(controller.canSave, isFalse);
      expect(controller.text.text, contains('"routeOnly": true'));
      controller.name.text = 'Independent DNS';
      controller.text.text = '''{"outbounds":[{},{}],"dns":{"hosts":{"example.test":"192.0.2.1"}},"inbounds":[{"tag":"tunIn","sniffing":{"enabled":false}}],"routing":{"domainStrategy":"AsIs","rules":[]}}''';
      final expected = AdvancedRoutingDocument.parse(controller.text.text).state
          .toJson();
      final saving = controller.save(context);
      final draft = await service.started.future;
      expect(draft.state.advanced, isTrue);
      expect(draft.state.entryCount, 2);
      expect(draft.state.toJson(), expected);
      expect(draft.state.name, 'Independent DNS');
      expect(controller.state.busy, isTrue);
      expect(controller.state.deleting, isFalse);
      service.result.complete(null);
      await saving;
      expect(controller.error, isNull);
      expect(controller.canSave, isTrue);
      expect(await db.routingProfileDao.allRows, isEmpty);
      expect(await db.coreConfigDao.allRawRowsWithData, isEmpty);
    },
  );
}

class _PendingAdvancedSave extends CustomRoutingEditorService {
  _PendingAdvancedSave({super.database, super.coordinator});
  final started = Completer<CustomRoutingEditorDraft>();
  final result = Completer<int?>();
  @override
  Future<int?> save(
    CustomRoutingEditorDraft draft, {
    required Future<bool> Function() confirmReconnect,
    ConfigurationImportDraft? imported,
  }) {
    started.complete(draft);
    return result.future;
  }
}

class _PendingRawSave extends RawEditorService {
  _PendingRawSave({super.database, super.coordinator});

  final started = Completer<void>();
  final result = Completer<int?>();

  @override
  Future<RawEditorDraft> load(int? id) async =>
      const RawEditorDraft(name: '', text: '{}');

  @override
  Future<int?> save(
    RawEditorDraft draft, {
    required Future<bool> Function() confirmReconnect,
    ConfigurationImportDraft? imported,
  }) {
    started.complete();
    return result.future;
  }
}
