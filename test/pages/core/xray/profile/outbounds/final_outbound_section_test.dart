import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/profile/outbounds/final_outbound_section.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  Widget buildSubject({
    String? name,
    required VoidCallback onSelect,
    VoidCallback? onDelete,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => ShadTheme(
        data: ShadThemeData(
          colorScheme: const ShadBlueColorScheme.light(),
          radius: const BorderRadius.all(Radius.circular(8)),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
      home: Scaffold(
        body: FinalOutboundSection(
          name: name,
          onSelect: onSelect,
          onDelete: onDelete,
        ),
      ),
    );
  }

  testWidgets('selected final outbound uses an inline delete button', (
    tester,
  ) async {
    var selected = 0;
    var deleted = 0;
    await tester.pumpWidget(
      buildSubject(
        name: 'Denver-XHTTP',
        onSelect: () => selected++,
        onDelete: () => deleted++,
      ),
    );

    expect(find.text('Denver-XHTTP'), findsOneWidget);
    expect(find.text('Delete Final Outbound'), findsNothing);
    expect(find.byIcon(LucideIcons.trash2), findsOneWidget);
    expect(find.byIcon(LucideIcons.chevronRight), findsNothing);

    await tester.tap(find.byIcon(LucideIcons.trash2));
    await tester.pump();

    expect(deleted, 1);
    expect(selected, 0);

    await tester.tap(find.text('Denver-XHTTP'));
    await tester.pump();

    expect(selected, 1);
  });

  testWidgets('empty final outbound keeps the navigation affordance', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject(onSelect: () {}));

    expect(find.text('Disabled'), findsOneWidget);
    expect(find.byIcon(LucideIcons.chevronRight), findsOneWidget);
    expect(find.byIcon(LucideIcons.trash2), findsNothing);
  });
}
