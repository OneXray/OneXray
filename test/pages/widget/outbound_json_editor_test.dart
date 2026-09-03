import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/pages/widget/outbound_json_editor.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('long outbound JSON stays bounded, scrollable and LTR in fa', (
    tester,
  ) async {
    final controller = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert({
        'outbounds': List.generate(
          60,
          (index) => {
            'tag': 'Node $index',
            'protocol': 'vless',
            'settings': {'address': 'example.test'},
          },
        ),
        'last': 'END_OF_OUTBOUND_JSON',
      }),
    );
    addTearDown(controller.dispose);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final (width, height) in [(427.0, 340.0), (1000.0, 290.0)]) {
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.material(Brightness.light, mobile: width < 720),
          locale: const Locale('fa'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (_, child) => ShadTheme(
            data: AppTheme.shad(Brightness.light, mobile: width < 720),
            child: child!,
          ),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: OutboundJsonEditor(controller: controller),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final editor = find.byType(OutboundJsonEditor);
      final editable = find.descendant(
        of: editor,
        matching: find.byType(EditableText),
      );
      expect(tester.getSize(editor).height, height);
      expect(Directionality.of(tester.element(editor)), TextDirection.rtl);
      expect(Directionality.of(tester.element(editable)), TextDirection.ltr);
      expect(
        tester.state<EditableTextState>(editable).renderEditable.textDirection,
        TextDirection.ltr,
      );
      expect(tester.takeException(), isNull);

      final scrollable = find.descendant(
        of: editable,
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scrollable).position;
      expect(position.maxScrollExtent, greaterThan(0));
      await tester.drag(scrollable, Offset(0, -position.maxScrollExtent - 500));
      await tester.pumpAndSettle();
      expect(position.pixels, closeTo(position.maxScrollExtent, 0.1));
      final render = tester.state<EditableTextState>(editable).renderEditable;
      final lastCaret = render.getLocalRectForCaret(
        TextPosition(offset: controller.text.length),
      );
      expect(lastCaret.center.dy, inInclusiveRange(0.0, render.size.height));
      expect(controller.text, contains('END_OF_OUTBOUND_JSON'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
