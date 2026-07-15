import 'dart:developer';

import 'package:flutter/foundation.dart';

void ygLogger(dynamic message) {
  if (!kReleaseMode) {
    final text = "$message";
    debugPrint(text);
    log(text);
  }
}

void ygReportError(Object error, StackTrace stackTrace, {String? reason}) {
  final message = reason == null ? '$error' : '$reason: $error';
  ygLogger('$message\n$stackTrace');
}
