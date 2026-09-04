import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/connect/raw_editor/controller.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/pages/widget/json_editor.dart';
import 'package:onexray/service/assets/raw_editor.dart';
import 'package:onexray/service/connection/coordinator.dart';
import 'package:onexray/service/geo_data/model.dart';
import 'package:re_editor/re_editor.dart';

void main() {
  testWidgets('Raw test result is discarded after the editable JSON changes', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final coordinator = ConnectionCoordinator(database: db);
    final service = _PendingRawTest(database: db, coordinator: coordinator);
    final controller = RawEditorController(rawId: null, service: service);
    addTearDown(() async {
      await controller.close();
      coordinator.dispose();
      await db.close();
    });
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: Text('Draft')),
      ),
    );
    final context = tester.element(find.text('Draft'));
    await controller.load(context);
    final testing = controller.test(context);
    expect(controller.action, RawEditorAction.test);
    controller.text.text = '{"outbounds": [], "tag": "edited"}';
    service.result.complete(const RawTestResult(42, 'https://example.com', 5));
    await testing;
    expect(controller.testResult, isNull);
    expect(controller.action, isNull);
    expect(controller.canTest, isTrue);
  });
  testWidgets(
    'Raw save follows name and JSON while draft loading does not connect',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final coordinator = ConnectionCoordinator(database: db);
      final controller = RawEditorController(
        rawId: null,
        service: RawEditorService(database: db, coordinator: coordinator),
      );
      addTearDown(() async {
        await controller.close();
        coordinator.dispose();
        await db.close();
      });
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: Text('Draft')),
        ),
      );
      await controller.load(tester.element(find.text('Draft')));
      expect(controller.canTest, isTrue);
      expect(controller.canSave, isFalse);
      final changed = controller.stream.firstWhere(
        (state) => state.name == 'Private configuration',
      );
      controller.name.text = 'Private configuration';
      await changed;
      expect(controller.canSave, isTrue);
      controller.text.text = '';
      expect(controller.canTest, isFalse);
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
    final controller = RawEditorController(rawId: null, service: service);
    addTearDown(() async {
      coordinator.dispose();
      await db.close();
    });
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
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
}

class _PendingRawTest extends RawEditorService {
  _PendingRawTest({super.database, super.coordinator});
  final result = Completer<RawTestResult>();

  @override
  Future<RawTestResult> test(
    RawEditorDraft draft, {
    GeoDataImportDraft? geodata,
  }) => result.future;
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
    GeoDataImportDraft? geodata,
  }) {
    started.complete();
    return result.future;
  }
}
