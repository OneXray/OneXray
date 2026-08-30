import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:onexray/pages/core/tun/app_icon/controller.dart';
import 'package:onexray/pages/core/tun/app_icon/view.dart';
import 'package:onexray/service/app_icon/service.dart';

/// Stands in for a launcher icon, matching the 96x96 PNG the Android bridge
/// produces.
final _pngBytes = img.encodePng(
  img.fill(
    img.Image(width: 96, height: 96, numChannels: 4),
    color: img.ColorRgb8(0, 128, 255),
  ),
);

void main() {
  // Evicting decoded icons on teardown needs the painting binding, which the
  // plain unit tests below also rely on.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('icons already resolved by the flow are seeded on construction', () async {
    final service = AppIconService.withLoader((packageName) async {
      return packageName == 'with.icon' ? Uint8List.fromList([1, 2, 3]) : null;
    });
    await service.load('with.icon');
    await service.load('without.icon');

    final controller = TunAppIconController.withService(service);
    addTearDown(controller.close);

    // A page reopened inside the same flow paints its icons on the first frame
    // instead of flashing the fallback glyph.
    expect(controller.state.icons['with.icon'], isA<MemoryImage>());
    expect(controller.state.icons.containsKey('without.icon'), isTrue);
    expect(controller.state.icons['without.icon'], isNull);
  });

  test(
    'a package is requested once no matter how often a row rebuilds',
    () async {
      var calls = 0;
      final completer = Completer<Uint8List?>();
      final controller = TunAppIconController.withService(
        AppIconService.withLoader((packageName) {
          calls += 1;
          return completer.future;
        }),
      );
      addTearDown(controller.close);

      controller.requestIcon('a.b.c');
      controller.requestIcon('a.b.c');
      completer.complete(Uint8List.fromList([1]));
      await Future<void>.delayed(Duration.zero);

      controller.requestIcon('a.b.c');
      expect(calls, 1);
      expect(controller.state.icons['a.b.c'], isA<MemoryImage>());
    },
  );

  test('a package without an icon keeps a resolved empty slot', () async {
    var calls = 0;
    final controller = TunAppIconController.withService(
      AppIconService.withLoader((packageName) async {
        calls += 1;
        return null;
      }),
    );
    addTearDown(controller.close);

    controller.requestIcon('a.b.c');
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.icons.containsKey('a.b.c'), isTrue);
    expect(controller.state.icons['a.b.c'], isNull);

    controller.requestIcon('a.b.c');
    expect(calls, 1);
  });

  test('a failed bridge call stays unresolved and can be retried', () async {
    var calls = 0;
    final controller = TunAppIconController.withService(
      AppIconService.withLoader((packageName) async {
        calls += 1;
        if (calls == 1) {
          throw StateError('bridge failure');
        }
        return Uint8List.fromList([7]);
      }),
    );
    addTearDown(controller.close);

    controller.requestIcon('a.b.c');
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.icons.containsKey('a.b.c'), isFalse);

    controller.requestIcon('a.b.c');
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.icons['a.b.c'], isA<MemoryImage>());
    expect(calls, 2);
  });

  test('an icon arriving after the page closed is dropped', () async {
    final completer = Completer<Uint8List?>();
    final controller = TunAppIconController.withService(
      AppIconService.withLoader((_) => completer.future),
    );

    controller.requestIcon('a.b.c');
    await controller.close();
    completer.complete(Uint8List.fromList([1]));
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.icons, isEmpty);
  });

  test(
    'an icon arriving after the flow released its icons is dropped',
    () async {
      var calls = 0;
      final completers = <Completer<Uint8List?>>[];
      final service = AppIconService.withLoader((packageName) {
        calls += 1;
        final completer = Completer<Uint8List?>();
        completers.add(completer);
        return completer.future;
      });
      final controller = TunAppIconController.withService(service);
      addTearDown(controller.close);

      controller.requestIcon('a.b.c');
      // The flow owner leaves the per-app VPN pages while the bridge call is
      // still running.
      service.clear();
      completers.first.complete(Uint8List.fromList([1]));
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.icons, isEmpty);

      // The package is unresolved again, so the next row that needs it retries.
      controller.requestIcon('a.b.c');
      completers.last.complete(Uint8List.fromList([2]));
      await Future<void>.delayed(Duration.zero);

      expect(calls, 2);
      expect(controller.state.icons['a.b.c'], isA<MemoryImage>());
    },
  );

  testWidgets('closing the page evicts the decoded icons', (tester) async {
    final controller = TunAppIconController.withService(
      AppIconService.withLoader((_) async => _pngBytes),
    );

    await tester.pumpWidget(
      BlocProvider.value(
        value: controller,
        child: const MaterialApp(
          home: Scaffold(body: AppIconView(packageName: 'a.b.c')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final icon = controller.state.icons['a.b.c']!;
    final cache = PaintingBinding.instance.imageCache;
    expect(cache.containsKey(icon), isTrue);

    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    await controller.close();

    expect(cache.containsKey(icon), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a seeded icon is left to the page that decoded it', (
    tester,
  ) async {
    final service = AppIconService.withLoader((_) async => _pngBytes);
    final owner = TunAppIconController.withService(service);
    addTearDown(owner.close);

    await tester.pumpWidget(
      BlocProvider.value(
        value: owner,
        child: const MaterialApp(
          home: Scaffold(body: AppIconView(packageName: 'a.b.c')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final icon = owner.state.icons['a.b.c']!;
    final cache = PaintingBinding.instance.imageCache;
    expect(cache.containsKey(icon), isTrue);

    // The next page of the flow seeds the same bytes, so its provider shares
    // the cache entry the first page is still painting from.
    final next = TunAppIconController.withService(service);
    expect(next.state.icons['a.b.c'], isA<MemoryImage>());
    await next.close();

    expect(cache.containsKey(icon), isTrue);
    expect(tester.takeException(), isNull);
  });
}
