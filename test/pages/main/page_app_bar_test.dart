import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macos_window_utils/window_manipulator.dart';
import 'package:material_ui/material_ui.dart';
import 'package:onexray/pages/main/desktop_window.dart';
import 'package:onexray/pages/shared/widgets/page_app_bar.dart';
import 'package:onexray/pages/theme/theme.dart';

void main() {
  testWidgets('page bar preserves themed sizing and tabs', (tester) async {
    final theme = AppTheme.light;
    await tester.pumpWidget(
      MaterialApp(
        theme: theme.copyWith(
          appBarTheme: theme.appBarTheme.copyWith(toolbarHeight: 64),
        ),
        home: const DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: PageAppBar(
              title: Text('Advanced'),
              bottom: TabBar(
                tabs: [
                  Tab(text: 'Tunnel'),
                  Tab(text: 'Xray'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final tabs = tester.widget<TabBar>(find.byType(TabBar));
    expect(
      tester.getSize(find.byType(AppBar)).height,
      64 + tabs.preferredSize.height,
    );
    expect(tester.widget<AppBar>(find.byType(AppBar)).backgroundColor, isNull);
  });

  testWidgets(
    'page bar keeps explicit callbacks and automatic back navigation',
    (tester) async {
      var leadingCalls = 0;
      var actionCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              appBar: PageAppBar(
                title: const Text('Root'),
                leading: BackButton(onPressed: () => leadingCalls++),
                actions: [
                  IconButton(
                    key: const Key('action'),
                    onPressed: () => actionCalls++,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(
                      appBar: PageAppBar(title: Text('Detail')),
                    ),
                  ),
                ),
                child: const Text('Open detail'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(BackButton));
      await tester.tap(find.byKey(const Key('action')));
      expect(leadingCalls, 1);
      expect(actionCalls, 1);
      await tester.tap(find.text('Open detail'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Detail'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Root'), findsOneWidget);
      expect(leadingCalls, 1);
    },
  );

  testWidgets('macOS toolbar hitboxes follow push and pop transitions', (
    tester,
  ) async {
    final rectangles = <String, Rect>{};
    const channel = MethodChannel('macos_window_utils/window_manipulator');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      final args = call.arguments as Map<Object?, Object?>?;
      if (call.method == 'updateToolbarPassthroughView') {
        rectangles[args!['id'] as String] = Rect.fromLTWH(
          (args['x'] as num).toDouble(),
          (args['y'] as num).toDouble(),
          (args['width'] as num).toDouble(),
          (args['height'] as num).toDouble(),
        );
      } else if (call.method == 'removeToolbarPassthroughView') {
        rectangles.remove(args!['id']);
      }
      return null;
    });
    await WindowManipulator.initialize(enableWindowDelegate: false);
    final navigator = GlobalKey<NavigatorState>();
    const rootAction = Key('root-action');
    const detailAction = Key('detail-action');
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        theme: AppTheme.light.copyWith(platform: TargetPlatform.macOS),
        builder: (context, child) => MacOSWindowInsets(
          titlebarHeight: 28,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(padding: EdgeInsets.zero),
            child: child!,
          ),
        ),
        home: Scaffold(
          appBar: PageAppBar(
            title: const Text('Root'),
            actions: [
              IconButton(
                key: rootAction,
                onPressed: () {},
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 20));
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: PageAppBar(
            title: const Text('Detail'),
            actions: [
              IconButton(
                key: detailAction,
                onPressed: () {},
                icon: const Icon(Icons.save),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(
      rectangles.values,
      contains(tester.getRect(find.byType(BackButton))),
    );
    expect(
      rectangles.values,
      contains(tester.getRect(find.byKey(detailAction))),
    );
    expect(rectangles, hasLength(2));

    navigator.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(rectangles.values, contains(tester.getRect(find.byKey(rootAction))));
    expect(rectangles, hasLength(1));

    showDialog<void>(
      context: tester.element(find.byKey(rootAction)),
      builder: (_) => const AlertDialog(title: Text('Dialog')),
    );
    await tester.pumpAndSettle();
    expect(rectangles, isEmpty);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(rectangles.values, contains(tester.getRect(find.byKey(rootAction))));
    expect(rectangles, hasLength(1));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(rectangles, isEmpty);
  });
}
