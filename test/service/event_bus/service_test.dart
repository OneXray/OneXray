import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/event_bus/service.dart';

void main() {
  test(
    'downloads remain active until concurrent tasks finish, including errors',
    () async {
      final bus = AppEventBus();
      addTearDown(bus.close);
      final first = Completer<void>();
      final second = Completer<void>();
      final values = <bool>[];
      final subscription = bus.stream.listen(
        (state) => values.add(state.downloading),
      );
      addTearDown(subscription.cancel);

      final a = bus.trackDownload(() => first.future);
      final b = bus.trackDownload(() => second.future);
      final failure = expectLater(b, throwsStateError);
      expect(bus.state.downloading, isTrue);
      first.complete();
      await a;
      expect(bus.state.downloading, isTrue);
      second.completeError(StateError('Download failed'));
      await failure;
      expect(bus.state.downloading, isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(values, [true, false]);
    },
  );
}
