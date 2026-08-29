import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:onexray/pages/widget/app_icon.dart';
import 'package:onexray/pages/widget/data_list.dart';
import 'package:onexray/service/app_icon/service.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Stands in for a launcher icon, matching the 96x96 PNG the Android bridge
/// produces.
final _pngBytes = img.encodePng(
  img.fill(
    img.Image(width: 96, height: 96, numChannels: 4),
    color: img.ColorRgb8(0, 128, 255),
  ),
);

/// Mirrors the leading slot of [DataListRow]: a fixed 31x31 box that hands
/// loose constraints to its child.
Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: Container(
          width: 31,
          height: 31,
          alignment: Alignment.center,
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('a loading icon falls back to the generic package glyph', (
    tester,
  ) async {
    final completer = Completer<Uint8List?>();
    final service = AppIconService.withLoader((_) => completer.future);

    await tester.pumpWidget(
      _host(AppIconView(packageName: 'a.b.c', service: service)),
    );

    expect(find.byIcon(LucideIcons.package), findsOneWidget);
    expect(find.byType(Image), findsNothing);

    completer.complete(_pngBytes);
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(LucideIcons.package), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an app without an icon keeps the generic package glyph', (
    tester,
  ) async {
    final service = AppIconService.withLoader((_) async => null);

    await tester.pumpWidget(
      _host(AppIconView(packageName: 'a.b.c', service: service)),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(LucideIcons.package), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a cached icon renders on the first frame', (tester) async {
    final service = AppIconService.withLoader((_) async => _pngBytes);
    await service.load('a.b.c');

    await tester.pumpWidget(
      _host(AppIconView(packageName: 'a.b.c', service: service)),
    );

    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(LucideIcons.package), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a recycled row reloads the icon of its new package', (
    tester,
  ) async {
    final requested = <String>[];
    final service = AppIconService.withLoader((packageName) async {
      requested.add(packageName);
      return packageName == 'with.icon' ? _pngBytes : null;
    });

    await tester.pumpWidget(
      _host(AppIconView(packageName: 'with.icon', service: service)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);

    await tester.pumpWidget(
      _host(AppIconView(packageName: 'without.icon', service: service)),
    );
    await tester.pumpAndSettle();

    expect(requested, ['with.icon', 'without.icon']);
    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(LucideIcons.package), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the icon fills the leading slot without a tile behind it', (
    tester,
  ) async {
    final service = AppIconService.withLoader((_) async => _pngBytes);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DataListRow(
            title: 'OneXray',
            subtitle: 'net.yuandev.onexray',
            leading: AppIconView(
              packageName: 'net.yuandev.onexray',
              service: service,
            ),
            leadingStyle: DataListRowLeadingStyle.image,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final image = find.byType(Image);
    expect(tester.getSize(image), const Size(31, 31));
    // Full-color artwork keeps the platform icon shape: no tinted tile and no
    // second rounded clip on top of it.
    expect(_leadingTileDecoration(tester, image), isNull);
    expect(
      find.ancestor(of: image, matching: find.byType(ClipRRect)),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a symbol leading keeps the tinted tile', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DataListRow(
            title: 'GeoData',
            subtitle: 'geoip.dat',
            leading: Icon(LucideIcons.database),
          ),
        ),
      ),
    );

    final icon = find.byIcon(LucideIcons.database);
    final decoration = _leadingTileDecoration(tester, icon);
    expect(decoration, isNotNull);
    expect(decoration!.color, isNotNull);
    expect(decoration.borderRadius, BorderRadius.circular(6));
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
