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

/// Renders one row of a page driven by [controller].
Future<void> _openPage(
  WidgetTester tester,
  TunAppIconController controller,
) async {
  await tester.pumpWidget(
    BlocProvider.value(
      value: controller,
      child: const MaterialApp(
        home: Scaffold(body: AppIconView(packageName: 'a.b.c')),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Unmounts the rows, which is what happens before a page controller closes.
Future<void> _closeRows(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: Scaffold()));
}

/// Decodes the rendered icon for real. The image codec completes through real
/// async, which the fake async of pump does not drive, so the decoded frame is
/// only accounted for in the image cache once it is precached here.
Future<void> _decodeIcon(WidgetTester tester, ImageProvider icon) async {
  final element = tester.element(find.byType(Image));
  await tester.runAsync(() => precacheImage(icon, element));
  await tester.pump();
}

void main() {
  // Releasing the icons evicts them from Flutter's global image cache, which
  // needs the painting binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  // Every provider built from one byte buffer keys the same image cache entry,
  // so the tests below share keys unless the cache starts empty.
  setUp(() {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  });

  test('icons already resolved by the flow are seeded on construction', () async {
    final service = AppIconService.withLoader((packageName) async {
      return packageName == 'with.icon' ? Uint8List.fromList([1, 2, 3]) : null;
    });
    await service.load('with.icon');
    await service.load('without.icon');

    final controller = TunAppIconController.withService(service);
    addTearDown(controller.close);

    // A page reopened inside the same flow paints its icons on the first frame
    // instead of flashing the fallback glyph, and it paints them through the
    // provider the flow already owns.
    expect(
      controller.state.icons['with.icon'],
      same(service.resolved('with.icon')),
    );
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
      await service.clear();
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

  testWidgets('leaving the flow evicts the decoded icons', (tester) async {
    final service = AppIconService.withLoader((_) async => _pngBytes);
    final controller = TunAppIconController.withService(service);

    await _openPage(tester, controller);

    final icon = controller.state.icons['a.b.c']!;
    final cache = PaintingBinding.instance.imageCache;
    await _decodeIcon(tester, icon);
    expect(cache.containsKey(icon), isTrue);
    expect(cache.currentSizeBytes, greaterThan(0));

    // Closing one page of the flow keeps the icon: the pages that are still
    // open, and the ones reopened later, paint from this entry.
    await _closeRows(tester);
    await controller.close();
    expect(cache.containsKey(icon), isTrue);

    await service.clear();

    expect(cache.containsKey(icon), isFalse);
    expect(cache.currentSizeBytes, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the pages of one flow share a single icon provider', (
    tester,
  ) async {
    final service = AppIconService.withLoader((_) async => _pngBytes);
    final owner = TunAppIconController.withService(service);
    addTearDown(owner.close);

    await _openPage(tester, owner);

    final icon = owner.state.icons['a.b.c']!;
    final cache = PaintingBinding.instance.imageCache;
    expect(cache.containsKey(icon), isTrue);

    // The next page of the flow seeds the provider the first one is painting
    // from instead of building a second one over the same bytes, so closing it
    // cannot release an entry another page is still using.
    final next = TunAppIconController.withService(service);
    expect(next.state.icons['a.b.c'], same(icon));
    await next.close();

    expect(cache.containsKey(icon), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a page closed, reopened and rendered leaves no icon behind', (
    tester,
  ) async {
    final service = AppIconService.withLoader((_) async => _pngBytes);
    final cache = PaintingBinding.instance.imageCache;

    final first = TunAppIconController.withService(service);
    await _openPage(tester, first);
    final icon = first.state.icons['a.b.c']!;
    await _decodeIcon(tester, icon);
    final decodedBytes = cache.currentSizeBytes;
    expect(cache.containsKey(icon), isTrue);
    expect(decodedBytes, greaterThan(0));
    expect(cache.currentSize, 1);

    // The user leaves the page while the flow that owns the icons stays open.
    await _closeRows(tester);
    await first.close();

    // Reopening seeds the provider the flow already owns, so rendering it
    // again decodes into the entry that provider owns instead of adding an
    // unowned one.
    final reopened = TunAppIconController.withService(service);
    expect(reopened.state.icons['a.b.c'], same(icon));
    await _openPage(tester, reopened);
    await _decodeIcon(tester, icon);
    expect(cache.containsKey(icon), isTrue);
    expect(cache.currentSizeBytes, decodedBytes);
    expect(cache.currentSize, 1);

    await _closeRows(tester);
    await reopened.close();

    // Leaving the flow releases what the reopened page painted from too.
    await service.clear();

    expect(cache.containsKey(icon), isFalse);
    expect(cache.currentSizeBytes, 0);
    expect(cache.currentSize, 0);
    expect(tester.takeException(), isNull);
  });
}
