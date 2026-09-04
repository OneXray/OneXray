import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/routing/custom/controller.dart';
import 'package:onexray/pages/routing/custom/rule_controller.dart';
import 'package:onexray/pages/routing/custom/rule_page.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/service/connection/coordinator.dart';
import 'package:onexray/service/routing/custom_editor.dart';
import 'package:onexray/service/routing/geodata_suggestions.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void _phone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Widget _app(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  theme: AppTheme.material(Brightness.light, mobile: true),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => ShadTheme(
    data: AppTheme.shad(Brightness.light, mobile: true),
    child: child!,
  ),
  home: child,
);

Finder _input(TextEditingController controller) => find.byWidgetPredicate(
  (widget) => widget is ShadInput && widget.controller == controller,
);

void main() {
  testWidgets(
    'conditions stay collapsed with summaries and keep real completion',
    (tester) async {
      _phone(tester);
      final original = <String, dynamic>{
        'ruleTag': 'Sites',
        'domain': ['geosite:CN'],
        'balancerTag': 'proxy',
      };
      final controller = CustomRoutingRuleController(
        rule: original,
        loadIndex: () async => const RoutingGeodataIndex(
          domainFiles: {
            'geosite.dat': ['CN'],
            'other.dat': ['CN'],
          },
          ipFiles: {},
        ),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: CustomRoutingRuleForm(controller: controller),
            ),
          ),
        ),
      );
      expect(find.byType(ShadInput), findsOneWidget);
      expect(find.text('geosite:CN'), findsOneWidget);
      await tester.tap(find.text('Websites and domains'));
      await tester.pumpAndSettle();
      await tester.enterText(_input(controller.domains.single.text), 'cn');
      await tester.pumpAndSettle();
      expect(find.text('ext:other.dat:CN'), findsOneWidget);
      await tester.tap(find.text('ext:other.dat:CN'));
      await tester.pumpAndSettle();
      expect(controller.domains.single.text.text, 'ext:other.dat:CN');
      await tester.tap(find.text('Add another'));
      await tester.pumpAndSettle();
      expect(controller.domains, hasLength(2));
      expect(find.byTooltip('Remove this entry'), findsNWidgets(2));
      await tester.tap(find.byTooltip('Remove this entry').first);
      await tester.pumpAndSettle();
      expect(controller.domains.single.text.text, isEmpty);
      expect(find.byTooltip('Remove this entry'), findsNothing);
      await tester.tap(find.text('Websites and domains'));
      await tester.pumpAndSettle();
      expect(find.byType(ShadInput), findsOneWidget);
      expect(original['domain'], ['geosite:CN']);
      expect(tester.takeException(), isNull);
    },
  );

  for (final locale in const [
    Locale('en'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    Locale('ru'),
    Locale('fa'),
  ]) {
    testWidgets(
      'four-condition form fits phone and preserves input direction ($locale)',
      (tester) async {
        _phone(tester);
        final controller = CustomRoutingRuleController(
          loadIndex: () async =>
              const RoutingGeodataIndex(domainFiles: {}, ipFiles: {}),
        );
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          _app(
            Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(14),
                child: CustomRoutingRuleForm(controller: controller),
              ),
            ),
            locale: locale,
          ),
        );
        await tester.pumpAndSettle();
        final l = AppLocalizations.of(
          tester.element(find.byType(CustomRoutingRuleForm)),
        )!;
        for (final title in [
          l.prototypeWebsitesDomains,
          l.prototypeIpAddressesRanges,
          l.prototypeTargetPort,
        ]) {
          await tester.ensureVisible(find.text(title));
          await tester.tap(find.text(title));
          await tester.pumpAndSettle();
        }
        for (final value in [
          controller.domains.single.text,
          controller.ips.single.text,
          controller.port,
        ]) {
          final editable = find.descendant(
            of: _input(value),
            matching: find.byType(EditableText),
          );
          expect(
            Directionality.of(tester.element(editable)),
            TextDirection.ltr,
          );
          expect(tester.widget<EditableText>(editable).style.fontSize, 16);
        }
        controller.setAction('block');
        await tester.pumpAndSettle();
        expect(find.text(l.prototypeVpnRuleHint), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'new rule validates before save and cancel does not return a draft',
    (tester) async {
      _phone(tester);
      Map<String, dynamic>? result;
      var completed = 0;
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await Navigator.push<Map<String, dynamic>>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CustomRoutingRulePage(),
                    ),
                  );
                  completed++;
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ShadInput>(find.byType(ShadInput)).controller!.text,
        'New rule',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(completed, 0);
      await tester.tap(find.text('Target port'));
      await tester.pumpAndSettle();
      final port = find.byWidgetPredicate(
        (widget) =>
            widget is ShadInput &&
            widget.placeholder is Text &&
            (widget.placeholder as Text).data == '80, 443, 1000-2000',
      );
      await tester.enterText(port, '443');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(result, {
        'ruleTag': 'New rule',
        'port': '443',
        'balancerTag': 'proxy',
      });
      expect(completed, 1);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(completed, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'route ordering and inline edits only change the in-memory draft',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final coordinator = ConnectionCoordinator(database: db);
      final controller = CustomRoutingEditorController(
        service: CustomRoutingEditorService(
          database: db,
          coordinator: coordinator,
        ),
      );
      addTearDown(controller.dispose);
      addTearDown(coordinator.dispose);
      addTearDown(db.close);
      late BuildContext context;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (value) {
              context = value;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.runAsync(() async {
        await db.routingProfileDao.insertRow(
          RoutingProfileCompanion.insert(
            name: 'Work 1',
            data: base64Encode(
              utf8.encode('{"outbounds":[{}],"routing":{"rules":[]}}'),
            ),
          ),
        );
        await controller.load(context);
      });
      expect(controller.loaded, isTrue);
      expect(controller.routeCount, 2);
      expect(controller.name.text, 'Custom Routing 2');
      expect(controller.rules, isEmpty);
      controller.replaceTemplate(
        jsonEncode({
          'outbounds': [{}],
          'routing': {
            'rules': [
              for (final name in ['A', 'B', 'C'])
                {
                  'ruleTag': name,
                  'domain': ['$name.example'],
                  'balancerTag': 'proxy',
                },
            ],
          },
        }),
      );
      final selected = controller.selectedRuleKey;
      controller.reorder(1, 0);
      expect(controller.rules.map((rule) => rule['ruleTag']), ['B', 'A', 'C']);
      expect(controller.selectedRuleKey, selected);
      controller.deleteRule(0);
      expect(controller.rules.map((rule) => rule['ruleTag']), ['A', 'C']);
      expect(controller.selectedRuleKey, controller.ruleKeys.first);
      controller.setInlineEditing(true);
      expect(controller.inlineRule!.name.text, 'A');
      controller.inlineRule!.name.text = 'A edited';
      controller.inlineRule!.domains.single.text.text = 'edited.example';
      controller.inlineRule!.port.text = '65536';
      expect(controller.previewTemplate, isNull);
      Future<Map<String, dynamic>?> unexpectedNavigation(
        BuildContext _,
        Map<String, dynamic>? _,
      ) async =>
          throw StateError('Desktop must keep the editor beside the list');
      await controller.editRule(context, unexpectedNavigation, 1);
      expect(controller.inlineRule!.name.text, 'C');
      expect(controller.rules.first['port'], '65536');
      await controller.editRule(context, unexpectedNavigation, 0);
      expect(controller.inlineRule!.domains.single.text.text, 'edited.example');
      expect(controller.inlineRule!.port.text, '65536');
      controller.inlineRule!.port.text = '443';
      controller.reorder(0, 1);
      expect(controller.rules.last['ruleTag'], 'A edited');
      controller.inlineRule!.setAction('direct');
      expect(controller.rules.last['outboundTag'], 'direct');
      await controller.editRule(context, unexpectedNavigation);
      expect(controller.inlineRule!.name.text, 'New rule');
      expect(controller.previewTemplate, isNull);
      controller.inlineRule!.domains.single.text.text = 'new.example';
      expect(controller.previewTemplate!.rules, hasLength(3));
      controller.deleteRule(2);
      expect(controller.inlineRule!.name.text, 'A edited');
      controller.setInlineEditing(false);
      expect(controller.inlineRule, isNull);
      var mobileOpened = false;
      await controller.editRule(context, (_, rule) async {
        mobileOpened = true;
        final current = rule!;
        expect(current['ruleTag'], 'A edited');
        return {...current, 'ruleTag': 'Mobile edit'};
      }, 1);
      expect(mobileOpened, isTrue);
      expect(controller.rules.last['ruleTag'], 'Mobile edit');
      await tester.pump();
      expect(
        await tester.runAsync(() => db.routingProfileDao.allRows),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
