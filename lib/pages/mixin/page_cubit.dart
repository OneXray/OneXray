import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

abstract class PageCubit<State> extends Cubit<State> {
  PageCubit(super.initialState);

  bool _closing = false;

  bool get isPageActive => !_closing && !isClosed;

  @override
  void emit(State state) {
    if (!isPageActive) {
      return;
    }
    super.emit(state);
  }

  FutureOr<void> disposePageResources() {}

  @override
  Future<void> close() async {
    if (_closing || isClosed) {
      return;
    }
    _closing = true;
    try {
      await disposePageResources();
    } finally {
      await super.close();
    }
  }
}
