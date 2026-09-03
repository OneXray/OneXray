import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/connect/raw_editor/controller.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/service/assets/raw_editor.dart';
import 'package:onexray/service/connection/coordinator.dart';

void main() {
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
        controller.dispose();
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
      var notified = 0;
      controller.addListener(() => notified++);
      controller.name.text = 'Private configuration';
      expect(notified, greaterThan(0));
      expect(controller.canSave, isTrue);
      controller.text.clear();
      expect(controller.canTest, isFalse);
      expect(controller.canSave, isFalse);
      controller.text.text = '{}';
      controller.busy = true;
      expect(controller.canSave, isFalse);
      controller.busy = false;
      expect(controller.canSave, isTrue);
      expect(await db.coreConfigDao.allRawRowsWithData, isEmpty);
    },
  );

  testWidgets('plain JSON editor scrolls long content without a second frame', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(427, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = TextEditingController(
      text: List.generate(100, (i) => '  "line$i": $i,').join('\n'),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.material(Brightness.light, mobile: true),
        home: Scaffold(
          body: SizedBox(
            height: 390,
            child: SettingsJsonEditor(controller: controller, lineCount: 100),
          ),
        ),
      ),
    );
    expect(find.text('xray.json'), findsNothing);
    final field = tester.widget<TextField>(find.byType(TextField));
    field.scrollController!.jumpTo(500);
    await tester.pumpAndSettle();
    expect(field.scrollController!.offset, 500);
    expect(tester.takeException(), isNull);
  });
}
