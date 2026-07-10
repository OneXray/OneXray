import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrcodeController {
  bool _completed = false;

  void handleBarcode(BuildContext context, BarcodeCapture capture) {
    if (_completed || capture.barcodes.isEmpty) {
      return;
    }
    final value = capture.barcodes.first.rawValue;
    if (value == null) {
      return;
    }
    _completed = true;
    context.pop<String>(value);
  }
}
