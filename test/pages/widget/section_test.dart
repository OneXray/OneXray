import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('setting section exposes Material ink for native switch rows', (
    tester,
  ) async {
    var enabled = false;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => ShadTheme(
          data: ShadThemeData(colorScheme: const ShadBlueColorScheme.light()),
          child: child!,
        ),
        home: Scaffold(
          body: SettingSection(
            title: 'Logs',
            children: [
              SwitchListTile(
                title: const Text('Record logs'),
                value: enabled,
                onChanged: (value) => enabled = value,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Record logs'));
    await tester.pumpAndSettle();
    expect(enabled, isTrue);
    expect(tester.takeException(), isNull);
  });
}
