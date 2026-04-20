import 'dart:developer';

import 'package:flutter/foundation.dart';

void ygLogger(dynamic message) {
  if (!kReleaseMode) {
    log(message);
  }
}
