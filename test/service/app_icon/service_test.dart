import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:onexray/service/app_icon/service.dart';

/// Stands in for a launcher icon, matching the 96x96 PNG the Android bridge
/// produces.
final _pngBytes = img.encodePng(
  img.fill(
    img.Image(width: 96, height: 96, numChannels: 4),
    color: img.ColorRgb8(0, 128, 255),
  ),
);

/// Decodes [icon] for real. The codec completes through real async, which the
/// fake async of a widget test does not drive, so the frame is only accounted
/// for in the image cache once it is awaited here.
Future<void> _decode(WidgetTester tester, ImageProvider icon) {
  return tester.runAsync(() async {
    final decoded = Completer<void>();
    final stream = icon.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener((info, _) {
      // The stream hands every listener its own clone to release.
      info.dispose();
      stream.removeListener(listener);
      decoded.complete();
    });
    stream.addListener(listener);
    await decoded.future;
  });
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

  test('a resolved icon is cached as one provider and reused', () async {
    var calls = 0;
    final bytes = Uint8List.fromList([1, 2, 3]);
    final service = AppIconService.withLoader((packageName) async {
      calls += 1;
      return bytes;
    });

    expect(service.isResolved('a.b.c'), isFalse);
    expect(service.resolved('a.b.c'), isNull);

    final first = await service.load('a.b.c');
    expect(
      first,
      isA<MemoryImage>().having((icon) => icon.bytes, 'bytes', same(bytes)),
    );
    expect(service.isResolved('a.b.c'), isTrue);
    expect(service.resolved('a.b.c'), same(first));

    // One provider per package keeps the icon to a single image cache entry,
    // which the flow can then release exactly once.
    expect(await service.load('a.b.c'), same(first));
    expect(calls, 1);
  });

  test('concurrent requests for one package share a single load', () async {
    var calls = 0;
    final completer = Completer<Uint8List?>();
    final service = AppIconService.withLoader((packageName) {
      calls += 1;
      return completer.future;
    });

    final requests = Future.wait([
      service.load('a.b.c'),
      service.load('a.b.c'),
      service.load('a.b.c'),
    ]);
    completer.complete(Uint8List.fromList([9]));

    final icons = await requests;
    expect(calls, 1);
    expect(icons, everyElement(same(service.resolved('a.b.c'))));
  });

  test('missing and empty icons are cached as unavailable', () async {
    var calls = 0;
    final service = AppIconService.withLoader((packageName) async {
      calls += 1;
      return packageName == 'empty' ? Uint8List(0) : null;
    });

    expect(await service.load('missing'), isNull);
    expect(await service.load('empty'), isNull);
    expect(service.isResolved('missing'), isTrue);
    expect(service.isResolved('empty'), isTrue);

    await service.load('missing');
    await service.load('empty');
    expect(calls, 2);
  });

  test('a failed load is reported as unavailable and can be retried', () async {
    var calls = 0;
    final service = AppIconService.withLoader((packageName) async {
      calls += 1;
      if (calls == 1) {
        throw StateError('bridge failure');
      }
      return Uint8List.fromList([7]);
    });

    expect(await service.load('a.b.c'), isNull);
    expect(service.isResolved('a.b.c'), isFalse);

    expect(await service.load('a.b.c'), isA<MemoryImage>());
    expect(calls, 2);
  });

  test('clear drops cached icons', () async {
    var calls = 0;
    final service = AppIconService.withLoader((packageName) async {
      calls += 1;
      return Uint8List.fromList([calls]);
    });

    final first = await service.load('a.b.c');
    await service.clear();

    expect(service.isResolved('a.b.c'), isFalse);
    expect(service.resolvedIcons, isEmpty);
    // The next flow builds its own provider instead of adopting the released
    // one.
    expect(await service.load('a.b.c'), isNot(same(first)));
    expect(calls, 2);
  });

  testWidgets('clear evicts the frames decoded from the icons', (tester) async {
    final service = AppIconService.withLoader((_) async => _pngBytes);
    final icon = (await service.load('a.b.c'))!;

    // Resolving the provider is what the rows do through Image: it registers
    // the icon in Flutter's global image cache.
    await _decode(tester, icon);
    final cache = PaintingBinding.instance.imageCache;
    expect(cache.containsKey(icon), isTrue);
    expect(cache.currentSizeBytes, greaterThan(0));

    await service.clear();

    expect(cache.containsKey(icon), isFalse);
    expect(cache.currentSizeBytes, 0);
    expect(tester.takeException(), isNull);
  });

  test('an in-flight load cannot repopulate the cache after clear', () async {
    final completer = Completer<Uint8List?>();
    final service = AppIconService.withLoader(
      (packageName) => completer.future,
    );

    final request = service.load('a.b.c');
    await service.clear();
    completer.complete(Uint8List.fromList([1]));

    // A stale request builds no provider at all, so it can neither write into
    // the cache nor leave a decoded frame the flow no longer owns.
    expect(await request, isNull);
    expect(service.isResolved('a.b.c'), isFalse);
    expect(service.resolved('a.b.c'), isNull);
    expect(service.resolvedIcons, isEmpty);
  });

  test(
    'a stale load leaves the pending request of the new flow alone',
    () async {
      final completers = <Completer<Uint8List?>>[];
      final service = AppIconService.withLoader((packageName) {
        final completer = Completer<Uint8List?>();
        completers.add(completer);
        return completer.future;
      });

      final stale = service.load('a.b.c');
      await service.clear();
      final fresh = service.load('a.b.c');
      expect(completers, hasLength(2));

      // The stale request finishing must not release the pending slot the new
      // flow is waiting on, nor answer it with the previous flow's icon.
      completers.first.complete(Uint8List.fromList([1]));
      expect(await stale, isNull);
      expect(service.isResolved('a.b.c'), isFalse);
      // The new flow still owns the pending slot, so no third bridge call.
      unawaited(service.load('a.b.c'));
      expect(completers, hasLength(2));

      completers.last.complete(_pngBytes);
      expect(await fresh, same(service.resolved('a.b.c')));
    },
  );

  test(
    'a stale load does not overwrite an icon resolved after clear',
    () async {
      final completers = <Completer<Uint8List?>>[];
      final service = AppIconService.withLoader((packageName) {
        final completer = Completer<Uint8List?>();
        completers.add(completer);
        return completer.future;
      });

      final stale = service.load('a.b.c');
      await service.clear();
      final fresh = service.load('a.b.c');

      completers.last.complete(_pngBytes);
      final icon = await fresh;
      expect(icon, same(service.resolved('a.b.c')));

      completers.first.complete(Uint8List.fromList([1]));
      await stale;
      expect(service.resolved('a.b.c'), same(icon));
    },
  );
}
