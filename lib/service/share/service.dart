import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/service/localizations/service.dart';
import 'package:onexray/service/db/config_writer.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/share/protocol.dart';
import 'package:onexray/service/share/xray_share_reader.dart';
import 'package:onexray/service/toast/service.dart';
import 'package:zxing2/qrcode.dart';

final class ShareService {
  static final ShareService _singleton = ShareService._internal();

  factory ShareService() => _singleton;

  ShareService._internal();

  //==========================

  void init() {
    final appLinks = AppLinks();
    _deepLinkSubscription = appLinks.uriLinkStream.listen(
      (uri) => _readDeepLink(uri),
    );
  }

  void dispose() {
    _deepLinkSubscription.cancel();
  }

  late StreamSubscription<Uri> _deepLinkSubscription;

  Future<void> _readDeepLink(Uri uri) async {
    await readShareText(uri.toString());
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final text = await _readImageFile(image.path);
      await readShareText(text);
    } else {
      ToastService().showToast(
        appLocalizationsNoContext().homeOutboundViewNoValidConfig,
      );
    }
  }

  Future<String?> _readImageFile(String path) async {
    if (AppPlatform.isIOS || AppPlatform.isMacOS || AppPlatform.isAndroid) {
      return _readImageFileByMobileScanner(path);
    }
    return _readImageFileByZxing(path);
  }

  Future<String?> _readImageFileByMobileScanner(String path) async {
    final controller = MobileScannerController();
    final capture = await controller.analyzeImage(path);
    if (capture != null) {
      if (capture.barcodes.isNotEmpty) {
        final code = capture.barcodes.first;
        if (code.rawValue != null) {
          await controller.dispose();
          return code.rawValue;
        }
      }
    }
    await controller.dispose();
    return null;
  }

  Future<String?> _readImageFileByZxing(String path) async {
    final image = await img.decodeImageFile(path);
    if (image != null) {
      final source = RGBLuminanceSource(
        image.width,
        image.height,
        image
            .convert(numChannels: 4)
            .getBytes(order: img.ChannelOrder.abgr)
            .buffer
            .asInt32List(),
      );
      final bitmap = BinaryBitmap(GlobalHistogramBinarizer(source));
      final reader = QRCodeReader();
      try {
        final result = reader.decode(bitmap);
        return result.text;
      } catch (_) {}
    }
    return null;
  }

  Future<void> pickFile() async {
    final textFiles = <String>["txt", "json", "yaml"];
    final imageFiles = <String>["png", "jpg", "jpeg"];
    final allowedExtensions = <String>[];
    allowedExtensions.addAll(textFiles);
    allowedExtensions.addAll(imageFiles);
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );

    if (result != null) {
      final file = result.files.single;
      if (file.path != null) {
        if (imageFiles.contains(file.extension)) {
          final text = await _readImageFile(file.path!);
          await readShareText(text);
        } else {
          final pFile = File(file.path!);
          final text = await pFile.readAsString();
          ygLogger('Picked file content: $text');
          await readShareText(text);
        }
      } else {
        ToastService().showToast(
          appLocalizationsNoContext().homeOutboundViewNoValidConfig,
        );
      }
    } else {
      ygLogger('User canceled file picking');
    }
  }

  Future<void> readPasteboard() async {
    final hasStrings = await Clipboard.hasStrings();
    if (!hasStrings) {
      ToastService().showToast(
        appLocalizationsNoContext().homeOutboundViewNoValidConfig,
      );
      return;
    }
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data == null) {
      ToastService().showToast(
        appLocalizationsNoContext().homeOutboundViewNoValidConfig,
      );
      return;
    }

    final text = data.text;
    if (text == null) {
      ToastService().showToast(
        appLocalizationsNoContext().homeOutboundViewNoValidConfig,
      );
      return;
    }
    await readShareText(text);
  }

  Future<void> readShareText(String? text) async {
    var success = false;
    if (text != null) {
      final eventBus = AppEventBus.instance;
      eventBus.updateDownloading(true);
      final url = text.trim();
      if (AppShareService().checkAppShare(url)) {
        final result = await AppShareService().parseShareText(url);
        final rows = result.item1;
        if (rows.isNotEmpty) {
          await ConfigWriter.writeRows(rows, null);
        }
        success = result.item2;
      } else if (url.startsWith("https://")) {
        final uri = Uri.tryParse(url);
        if (uri != null) {
          success = await AppShareService().addSubscription(
            url,
            uri.fragment,
            true,
          );
        }
      } else {
        final rows = await XrayShareReader().parseShareText(url);
        if (rows.isNotEmpty) {
          final res = await ConfigWriter.writeRows(rows, null);
          if (res > 0) {
            success = true;
          }
        }
      }
      eventBus.updateDownloading(false);
    }

    if (success) {
      ToastService().showToast(
        appLocalizationsNoContext().homeOutboundViewImportSuccess,
      );
    } else {
      ToastService().showToast(
        appLocalizationsNoContext().homeOutboundViewNoValidConfig,
      );
    }
  }
}
