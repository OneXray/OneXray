import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';

class QrcodePage extends StatelessWidget {
  const QrcodePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.qrcodePageTitle),
      ),
      body: SafeArea(
        child: MobileScanner(
          onDetect: (barcodes) => _handleBarcode(context, barcodes),
        ),
      ),
    );
  }

  Future<void> _handleBarcode(
    BuildContext context,
    BarcodeCapture barcodes,
  ) async {
    if (barcodes.barcodes.isNotEmpty) {
      final code = barcodes.barcodes.first;
      if (code.rawValue != null) {
        context.pop<String>(code.rawValue);
      }
    }
  }
}
