import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:onexray/pages/core/tun/app_icon/controller.dart';
import 'package:onexray/pages/core/tun/app_icon/view.dart';
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

Widget _host(TunAppIconController controller, Widget child) {
  return BlocProvider.value(
    value: controller,
    child: MaterialApp(
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
    ),
  );
}

TunAppIconController _controller(AppIconLoader loader) {
  final controller = TunAppIconController.withService(
    AppIconService.withLoader(loader),
  );
  addTearDown(controller.close);
  return controller;
}

void main() {
  testWidgets('a loading icon falls back to the generic package glyph', (
    tester,
  ) async {
    final completer = Completer<Uint8List?>();
    final controller = _controller((_) => completer.future);

    await tester.pumpWidget(
      _host(controller, const AppIconView(packageName: 'a.b.c')),
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
    final controller = _controller((_) async => null);

    await tester.pumpWidget(
      _host(controller, const AppIconView(packageName: 'a.b.c')),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(LucideIcons.package), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a cached icon renders on the first frame', (tester) async {
    final service = AppIconService.withLoader((_) async => _pngBytes);
    await service.load('a.b.c');
    final controller = TunAppIconController.withService(service);
    addTearDown(controller.close);

    await tester.pumpWidget(
      _host(controller, const AppIconView(packageName: 'a.b.c')),
    );

    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(LucideIcons.package), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a recycled row reloads the icon of its new package', (
    tester,
  ) async {
    final requested = <String>[];
    final controller = _controller((packageName) async {
      requested.add(packageName);
      return packageName == 'with.icon' ? _pngBytes : null;
    });

    await tester.pumpWidget(
      _host(controller, const AppIconView(packageName: 'with.icon')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);

    await tester.pumpWidget(
      _host(controller, const AppIconView(packageName: 'without.icon')),
    );
    await tester.pumpAndSettle();

    expect(requested, ['with.icon', 'without.icon']);
    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(LucideIcons.package), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
