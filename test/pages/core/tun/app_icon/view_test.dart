import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:onexray/pages/core/tun/app_icon/controller.dart';
import 'package:onexray/pages/core/tun/app_icon/view.dart';
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

  testWidgets('the launcher icon fills the leading slot', (tester) async {
    final controller = _controller((_) async => _pngBytes);

    await tester.pumpWidget(
      BlocProvider.value(
        value: controller,
        child: const MaterialApp(
          home: Scaffold(
            body: DataListRow(
              title: 'OneXray',
              subtitle: 'net.yuandev.onexray',
              leading: AppIconView(packageName: 'net.yuandev.onexray'),
              leadingStyle: DataListRowLeadingStyle.image,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final image = find.byType(Image);
    // The image codec completes through real async, which the fake async of
    // pump and pumpAndSettle does not drive, so the frame is precached here to
    // make the laid-out size deterministic.
    await tester.runAsync(
      () => precacheImage(
        controller.state.icons['net.yuandev.onexray']!,
        tester.element(image),
      ),
    );
    await tester.pump();

    // A 96x96 launcher icon scales down into the 31dp slot instead of
    // overflowing it or collapsing to nothing.
    expect(tester.getSize(image), const Size(31, 31));
    expect(tester.takeException(), isNull);
  });
}
