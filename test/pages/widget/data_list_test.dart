import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/pages/widget/data_list.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Both leading styles are checked with the same child, so the assertions can
/// only differ because of [DataListRow.leadingStyle].
Widget _row(DataListRowLeadingStyle leadingStyle) {
  return MaterialApp(
    home: Scaffold(
      body: DataListRow(
        title: 'GeoData',
        subtitle: 'geoip.dat',
        leading: const Icon(LucideIcons.database),
        leadingStyle: leadingStyle,
      ),
    ),
  );
}

void main() {
  testWidgets('a symbol leading keeps the tinted tile', (tester) async {
    await tester.pumpWidget(_row(DataListRowLeadingStyle.symbol));

    final icon = find.byIcon(LucideIcons.database);
    final decoration = _leadingTileDecoration(tester, icon);
    expect(decoration, isNotNull);
    expect(decoration!.color, isNotNull);
    expect(decoration.borderRadius, BorderRadius.circular(6));
    expect(tester.takeException(), isNull);
  });

  testWidgets('an image leading drops the tinted tile', (tester) async {
    await tester.pumpWidget(_row(DataListRowLeadingStyle.image));

    final icon = find.byIcon(LucideIcons.database);
    // Full-color artwork keeps the shape it arrives with: no tinted tile and
    // no second rounded clip on top of it. The footprint is unchanged.
    expect(_leadingTileDecoration(tester, icon), isNull);
    expect(
      find.ancestor(of: icon, matching: find.byType(ClipRRect)),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the default leading style is symbol', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DataListRow(
            title: 'GeoData',
            leading: Icon(LucideIcons.database),
          ),
        ),
      ),
    );

    expect(
      _leadingTileDecoration(tester, find.byIcon(LucideIcons.database)),
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });
}

/// Reads the decoration of the 31x31 leading tile wrapping [child].
BoxDecoration? _leadingTileDecoration(WidgetTester tester, Finder child) {
  final tile = tester.widget<Container>(
    find.ancestor(of: child, matching: find.byType(Container)).first,
  );
  expect(tester.getSize(find.byWidget(tile)), const Size(31, 31));
  return tile.decoration as BoxDecoration?;
}
