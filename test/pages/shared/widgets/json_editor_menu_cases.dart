import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/shared/widgets/json_editor.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/service/settings/language/locale.dart';
import 'package:re_editor/re_editor.dart';

// re_editor caches the target platform in top-level finals. Run each platform
// from a separate test file so its gestures are initialized in a fresh isolate.
void jsonEditorMenuTests(TargetPlatform platform) {
  final mobile =
      platform == TargetPlatform.iOS || platform == TargetPlatform.android;
  const text = '{"tag":"Example node"}';
  late String clipboard;
  late CodeLineEditingController controller;

  setUp(() {
    clipboard = '{"tag":"Pasted node"}';
    controller = CodeLineEditingController.fromText(text);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          switch (call.method) {
            case 'Clipboard.getData':
              return {'text': clipboard};
            case 'Clipboard.hasStrings':
              return {'value': clipboard.isNotEmpty};
            case 'Clipboard.setData':
              clipboard = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
  });

  tearDown(() {
    controller.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pumpEditor(
    WidgetTester tester,
    TargetPlatform platform, {
    Locale locale = const Locale('en'),
    bool showEditor = true,
    double width = 390,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalePolicy.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.material(Brightness.light, mobile: mobile),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.only(top: 80),
            child: SizedBox(
              height: 390,
              child: showEditor
                  ? AppJsonEditor(controller: controller)
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester, TargetPlatform platform) async {
    final target =
        tester.getTopLeft(find.byType(CodeEditor)) + const Offset(120, 24);
    if (platform == TargetPlatform.iOS || platform == TargetPlatform.android) {
      await tester.tapAt(target);
      await tester.pump();
      await tester.longPressAt(target);
    } else {
      await tester.tapAt(
        target,
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
    }
    await tester.pumpAndSettle();
  }

  Future<void> tapAction(
    WidgetTester tester,
    ContextMenuButtonType type,
  ) async {
    final toolbar = find.byType(AdaptiveTextSelectionToolbar);
    final item = tester
        .widget<AdaptiveTextSelectionToolbar>(toolbar)
        .buttonItems!
        .singleWhere((item) => item.type == type);
    final label = AdaptiveTextSelectionToolbar.getButtonLabel(
      tester.element(toolbar),
      item,
    );
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  if (mobile) {
    testWidgets('$platform long press exposes clipboard actions', (
      tester,
    ) async {
      await pumpEditor(tester, platform);
      await openMenu(tester, platform);
      expect(controller.selection.isCollapsed, isFalse);
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Cut'), findsOneWidget);
      expect(find.text('Paste'), findsOneWidget);
      expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(platform));
  }

  testWidgets('$platform menu can select all, copy, cut and paste', (
    tester,
  ) async {
    await pumpEditor(tester, platform, width: 600);
    await openMenu(tester, platform);
    await tapAction(tester, ContextMenuButtonType.selectAll);
    expect(controller.isAllSelected, isTrue);
    await tapAction(tester, ContextMenuButtonType.copy);
    expect(clipboard, text);
    expect(controller.text, text);
    expect(find.byType(AdaptiveTextSelectionToolbar), findsNothing);

    controller.cancelSelection();
    await openMenu(tester, platform);
    await tapAction(tester, ContextMenuButtonType.selectAll);
    await tapAction(tester, ContextMenuButtonType.cut);
    expect(controller.text, isEmpty);
    expect(clipboard, text);

    await openMenu(tester, platform);
    expect(find.text('Cut'), findsNothing);
    expect(find.text('Copy'), findsNothing);
    await tapAction(tester, ContextMenuButtonType.paste);
    expect(controller.text, text);
    expect(find.byType(AdaptiveTextSelectionToolbar), findsNothing);
    controller.undo();
    expect(controller.text, isEmpty);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(platform));

  testWidgets('$platform closes the menu outside and on editor removal', (
    tester,
  ) async {
    await pumpEditor(tester, platform);
    await openMenu(tester, platform);
    expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);
    await tester.tapAt(
      const Offset(200, 700),
      kind: platform == TargetPlatform.iOS || platform == TargetPlatform.android
          ? PointerDeviceKind.touch
          : PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(find.byType(AdaptiveTextSelectionToolbar), findsNothing);
    await openMenu(tester, platform);
    await pumpEditor(tester, platform, showEditor: false);
    expect(find.byType(AdaptiveTextSelectionToolbar), findsNothing);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(platform));

  testWidgets('menu hides paste when the clipboard is empty', (tester) async {
    clipboard = '';
    await pumpEditor(tester, platform);
    await openMenu(tester, platform);
    expect(find.text('Paste'), findsNothing);
    expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);
  }, variant: TargetPlatformVariant.only(platform));

  testWidgets('menu uses the current language and keeps JSON LTR', (
    tester,
  ) async {
    await pumpEditor(tester, platform, locale: const Locale('zh'));
    await openMenu(tester, platform);
    await tapAction(tester, ContextMenuButtonType.selectAll);
    expect(find.text('复制'), findsOneWidget);
    expect(find.text('剪切'), findsOneWidget);
    expect(find.text('粘贴'), findsOneWidget);
    await tapAction(tester, ContextMenuButtonType.copy);
    expect(clipboard, text);
    expect(
      Directionality.of(tester.element(find.byType(CodeEditor))),
      TextDirection.ltr,
    );
  }, variant: TargetPlatformVariant.only(platform));
}
