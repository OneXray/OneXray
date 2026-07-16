import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';

void main() {
  test('ignores an async state emitted after close', () async {
    final cubit = _DelayedPageCubit();

    await cubit.close();
    cubit.complete();
    await cubit.pending;

    expect(cubit.state, 0);
    expect(cubit.isClosed, isTrue);
  });

  test('becomes inactive before disposing page resources', () async {
    final cubit = _DisposingPageCubit();

    final closeFuture = cubit.close();
    await cubit.disposing.future;

    expect(cubit.isPageActive, isFalse);
    expect(cubit.state, 0);

    cubit.finishDisposing();
    await closeFuture;

    expect(cubit.isClosed, isTrue);
  });
}

class _DelayedPageCubit extends PageCubit<int> {
  _DelayedPageCubit() : super(0) {
    pending = _emitLater();
  }

  final _complete = Completer<void>();
  late final Future<void> pending;

  void complete() => _complete.complete();

  Future<void> _emitLater() async {
    await _complete.future;
    emit(1);
  }
}

class _DisposingPageCubit extends PageCubit<int> {
  _DisposingPageCubit() : super(0);

  final disposing = Completer<void>();
  final _finishDisposing = Completer<void>();

  void finishDisposing() => _finishDisposing.complete();

  @override
  Future<void> disposePageResources() async {
    disposing.complete();
    emit(1);
    await _finishDisposing.future;
  }
}
