import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/raw_edit/page.dart';
import 'package:onexray/pages/core/xray/raw_edit/params.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:re_editor/re_editor.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  late AppEventBus eventBus;

  setUp(() {
    eventBus = AppEventBus();
  });

  tearDown(() async {
    await eventBus.close();
  });

  testWidgets('raw editor stays usable at phone width and reports JSON state', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _testApp(XrayRawEditParams('Raw Edit', '{\n  "name": "Test"\n}')),
    );
    await tester.pump();

    expect(find.text('xray.json'), findsOneWidget);
    expect(find.text('Configuration valid'), findsWidgets);
    expect(find.text('3 lines'), findsOneWidget);
    expect(find.byIcon(LucideIcons.save), findsOneWidget);

    final editor = tester.widget<CodeEditor>(find.byType(CodeEditor));
    editor.controller!.text = '{';
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('JSON parse error'), findsWidgets);
    expect(tester.takeException(), isNull);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('custom validation keeps invalid content in the editor', (
    tester,
  ) async {
    const text = '{"outbounds":[]}';
    await tester.pumpWidget(
      _testApp(
        XrayRawEditParams(
          'Raw Edit',
          text,
          validator: (_) => 'Exactly one outbound is required',
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(LucideIcons.save));
    await tester.pump();

    final editor = tester.widget<CodeEditor>(find.byType(CodeEditor));
    expect(editor.controller!.text, text);
    expect(find.text('Exactly one outbound is required'), findsOneWidget);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Widget _testApp(XrayRawEditParams params) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => ShadTheme(
      data: ShadThemeData(
        colorScheme: const ShadBlueColorScheme.light(),
        radius: const BorderRadius.all(Radius.circular(8)),
      ),
      child: ShadToaster(child: child ?? const SizedBox.shrink()),
    ),
    home: XrayRawEditPage(params: params),
  );
}
