import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';

typedef AppErrorReporter =
    FutureOr<void> Function(
      Object error,
      StackTrace stackTrace,
      String? reason,
    );

AppErrorReporter? _appErrorReporter;

void configureAppErrorReporter(AppErrorReporter? reporter) {
  _appErrorReporter = reporter;
}

void ygLogger(dynamic message) {
  if (!kReleaseMode) {
    final text = "$message";
    debugPrint(text);
    log(text);
  }
}

void ygReportError(Object error, StackTrace stackTrace, {String? reason}) {
  ygLogger(reason == null ? error : '$reason: $error');
  final reporter = _appErrorReporter;
  if (reporter != null) {
    unawaited(
      Future.sync(() => reporter(error, stackTrace, reason)).catchError((
        Object reporterError,
        StackTrace reporterStackTrace,
      ) {
        ygLogger('error reporter failed: $reporterError\n$reporterStackTrace');
      }),
    );
  }
}
