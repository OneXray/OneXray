import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
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
}
