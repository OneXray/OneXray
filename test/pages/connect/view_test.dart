import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/connect/view.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/pages/widget/page_action_bar.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:onexray/service/connection/coordinator.dart';

void main() {
  test('connection traffic keeps byte conversion and prototype precision', () {
    expect(formatTraffic(0, connection: true), '0 B');
    expect(formatTraffic(1024, connection: true), '1 KB');
    expect(formatTraffic(1536, connection: true), '1.5 KB');
    expect(
      formatTraffic((2.34 * 1024 * 1024).round(), connection: true),
      '2.34 MB',
    );
    expect(formatTraffic(1536), '1.5 KiB');
  });

  testWidgets('JSON input stays top aligned and LTR in a Persian page', (
    tester,
  ) async {
    final controller = TextEditingController(text: '{\n  "outbounds": []\n}');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ShadTheme(
          data: AppTheme.shad(Brightness.light),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: SettingsJsonEditor(
                controller: controller,
                lineCount: 3,
                valid: true,
                validLabel: 'valid',
                invalidLabel: 'invalid',
                linesLabel: '3',
                spacesLabel: '2',
              ),
            ),
          ),
        ),
      ),
    );
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.textAlignVertical, TextAlignVertical.top);
    expect(
      Directionality.of(tester.element(find.byType(TextField))),
      TextDirection.ltr,
    );
    expect(tester.takeException(), isNull);
  });
  Widget screen({
    ConnectionView view = const ConnectionView(),
    bool hasServers = true,
    bool expert = false,
    String? runningPath,
    List<CoreConfigData> raws = const [],
    VoidCallback? onExpert,
  }) => ConnectView(
    view: view,
    hasServers: hasServers,
    expert: expert,
    raws: raws,
    activeRawId: null,
    location: 'Automatic selection',
    runningPath: runningPath,
    method: 'Smart Routing',
    onConnection: () {},
    onAddServers: () {},
    onExpert: (_) => onExpert?.call(),
    onServer: () {},
    onMethod: () {},
    onWhy: () {},
    onTraffic: () {},
    onRawAdd: () {},
    onRawSelect: (_) {},
    onRawActions: (_) {},
  );

  Widget app(
    Widget child, {
    Locale locale = const Locale('en'),
    double scale = 1,
  }) => MaterialApp(
    theme: AppTheme.light,
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: ShadTheme(data: AppTheme.shad(Brightness.light), child: child!),
    ),
    home: Scaffold(body: child),
  );

  for (final locale in [
    const Locale('en'),
    const Locale('zh'),
    const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    const Locale('ru'),
    const Locale('fa'),
  ]) {
    for (final width in [390.0, 1160.0]) {
      testWidgets('connection layout ${locale.toLanguageTag()} at $width', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(app(screen(), locale: locale, scale: 1.3));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final context = tester.element(find.byType(ConnectView));
        final l = AppLocalizations.of(context)!;
        expect(find.text(l.prototypeCurrentSpeed), findsOneWidget);
        expect(find.text(l.prototypeConnectionLocation), findsOneWidget);
        expect(
          Directionality.of(context),
          locale.languageCode == 'fa' ? TextDirection.rtl : TextDirection.ltr,
        );
      });
    }
    testWidgets(
      'connected path and selection reset notice ${locale.toLanguageTag()}',
      (tester) async {
        const path = 'Singapore 03 + Japan 02 → United States 01';
        await tester.pumpWidget(
          app(
            screen(
              view: const ConnectionView(
                phase: ConnectionPhase.connected,
                issue: 'selectionReset',
              ),
              runningPath: path,
            ),
            locale: locale,
          ),
        );
        final l = AppLocalizations.of(
          tester.element(find.byType(ConnectView)),
        )!;
        expect(find.text(path), findsOneWidget);
        expect(
          find.text(l.prototypeNameActive(l.prototypeAutomaticSelection)),
          findsOneWidget,
        );
        expect(find.text(l.prototypeConnectionFailed), findsNothing);
        expect(find.text(l.prototypeCheckNetwork), findsNothing);
        expect(find.text(l.prototypeConnected), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('empty normal state still offers expert configuration', (
    tester,
  ) async {
    var switched = false;
    await tester.pumpWidget(
      app(screen(hasServers: false, onExpert: () => switched = true)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use a complete Raw JSON configuration'));
    expect(switched, isTrue);
  });

  testWidgets(
    'all legacy Raw configurations remain visible; add hidden at 3+',
    (tester) async {
      final raws = List.generate(
        4,
        (index) => CoreConfigData(
          id: index + 1,
          name: 'Legacy ${index + 1}',
          type: 'raw',
          tags: '',
          delay: -1,
          subId: 0,
          favorite: false,
        ),
      );
      await tester.pumpWidget(app(screen(expert: true, raws: raws)));
      await tester.pumpAndSettle();
      for (final row in raws) {
        expect(find.text(row.name), findsOneWidget);
      }
      expect(find.text('Add Raw JSON'), findsNothing);
      expect(find.text('Why this connection?'), findsNothing);
    },
  );

  testWidgets('page footer stays compact and fixed while content scrolls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: List.generate(40, (i) => ListTile(title: Text('Row $i'))),
          ),
          bottomNavigationBar: PageActionBar(
            children: [
              TextButton(onPressed: () {}, child: const Text('Cancel')),
              FilledButton(onPressed: () {}, child: const Text('Save')),
            ],
          ),
        ),
      ),
    );
    final before = tester.getRect(find.text('Save'));
    expect(before.top, greaterThan(650));
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('Save')), before);
    expect(
      tester.getSize(find.byType(PageActionBar)).height,
      greaterThanOrEqualTo(AppLayout.mobilePageActionMinHeight),
    );
    expect(
      tester.getSize(find.byType(FilledButton)).height,
      greaterThanOrEqualTo(AppLayout.pageActionButtonMinHeight),
    );
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(FilledButton)).width,
      greaterThanOrEqualTo(AppLayout.pageActionButtonMinWidth),
    );
    expect(
      tester.getSize(find.byType(PageActionBar)).height,
      greaterThanOrEqualTo(AppLayout.pageActionMinHeight),
    );
    expect(tester.takeException(), isNull);
  });
}
