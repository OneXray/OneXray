import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/home/qrcode/controller.dart';
import 'package:onexray/pages/theme/color.dart';

class QrcodePage extends StatefulWidget {
  const QrcodePage({super.key});

  @override
  State<QrcodePage> createState() => _QrcodePageState();
}

class _QrcodePageState extends State<QrcodePage> {
  late final QrcodeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = QrcodeController();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.qrcodePageTitle),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 600;
            return ColoredBox(
              color: ColorManager.palette(context).scannerBackground,
              child: Padding(
                padding: compact
                    ? EdgeInsets.zero
                    : const EdgeInsetsDirectional.all(20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: ClipRRect(
                      borderRadius: compact
                          ? BorderRadius.zero
                          : BorderRadius.circular(8),
                      child: SizedBox(
                        width: double.infinity,
                        height: double.infinity,
                        child: MobileScanner(
                          onDetect: (barcodes) =>
                              _controller.handleBarcode(context, barcodes),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
