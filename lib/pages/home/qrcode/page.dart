import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/home/qrcode/controller.dart';

class QrcodePage extends StatelessWidget {
  const QrcodePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = QrcodeController();
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.qrcodePageTitle),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: MobileScanner(
                onDetect: (barcodes) =>
                    controller.handleBarcode(context, barcodes),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
