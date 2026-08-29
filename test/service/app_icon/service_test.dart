import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/app_icon/service.dart';

void main() {
  test('resolved icon bytes are cached and reused', () async {
    var calls = 0;
    final service = AppIconService.withLoader((packageName) async {
      calls += 1;
      return Uint8List.fromList([1, 2, 3]);
    });

    expect(service.isResolved('a.b.c'), isFalse);
    expect(service.resolved('a.b.c'), isNull);

    final first = await service.load('a.b.c');
    expect(first, Uint8List.fromList([1, 2, 3]));
    expect(service.isResolved('a.b.c'), isTrue);
    expect(service.resolved('a.b.c'), same(first));

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
    expect(icons, everyElement(Uint8List.fromList([9])));
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

    expect(await service.load('a.b.c'), Uint8List.fromList([7]));
    expect(calls, 2);
  });

  test('clear drops cached icons', () async {
    var calls = 0;
    final service = AppIconService.withLoader((packageName) async {
      calls += 1;
      return Uint8List.fromList([calls]);
    });

    expect(await service.load('a.b.c'), Uint8List.fromList([1]));
    service.clear();

    expect(service.isResolved('a.b.c'), isFalse);
    expect(await service.load('a.b.c'), Uint8List.fromList([2]));
    expect(calls, 2);
  });
}
