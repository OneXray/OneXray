import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/service/localizations/service.dart';
import 'package:onexray/service/db/config_writer.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/ping/service.dart';
import 'package:onexray/service/share/app_link_importer.dart';
import 'package:onexray/service/share/app_link_parser.dart';
import 'package:onexray/service/share/xray_share_reader.dart';
import 'package:onexray/service/subscription/model.dart';
import 'package:onexray/service/subscription/service.dart';
import 'package:onexray/service/toast/service.dart';
import 'package:zxing2/qrcode.dart';

final class ShareService {
  static final ShareService _singleton = ShareService._internal();

  factory ShareService() => _singleton;

  ShareService._internal();

  //==========================

  final Queue<Uri> _pendingAppLinks = Queue<Uri>();
  final OneXrayAppLinkImporter _appLinkImporter = OneXrayAppLinkImporter();
  StreamSubscription<Uri>? _appLinkSubscription;
  var _appLinksReady = false;
  var _processingAppLinks = false;

  void startAppLinks() {
    if (_appLinkSubscription != null) {
      return;
    }
    _appLinkSubscription = AppLinks().uriLinkStream.listen(
      (uri) {
        _pendingAppLinks.add(uri);
        unawaited(_processAppLinks());
      },
      onError: (Object error, StackTrace stackTrace) {
        ygLogger('receive app link failed: $error\n$stackTrace');
      },
    );
  }

  Future<void> init() async {
    startAppLinks();
    _appLinksReady = true;
    await _processAppLinks();
  }

  void dispose() {
    _appLinksReady = false;
    _pendingAppLinks.clear();
    final subscription = _appLinkSubscription;
    _appLinkSubscription = null;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
  }

  Future<void> _processAppLinks() async {
    if (!_appLinksReady || _processingAppLinks) {
      return;
    }
    _processingAppLinks = true;
    try {
      while (_appLinksReady && _pendingAppLinks.isNotEmpty) {
        final uri = _pendingAppLinks.removeFirst();
        final link = OneXrayAppLinkParser.parse(uri);
        final success = link != null && await _appLinkImporter.importLink(link);
        ToastService().showToast(
          success
              ? appLocalizationsNoContext().homeOutboundViewImportSuccess
              : appLocalizationsNoContext().homeOutboundViewNoValidConfig,
        );
      }
    } finally {
      _processingAppLinks = false;
      if (_appLinksReady && _pendingAppLinks.isNotEmpty) {
        unawaited(_processAppLinks());
      }
    }
  }

  @visibleForTesting
  static List<SubscriptionImportEntry> parseSubscriptionImportEntries(
    String text,
  ) {
    final entries = <SubscriptionImportEntry>[];
    for (final rawLine in text.split('\n')) {
      final line = rawLine.trim();
      if (!line.startsWith('https://')) {
        continue;
      }

      final uri = Uri.tryParse(line);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        continue;
      }

      entries.add(
        SubscriptionImportEntry(
          url: SubscriptionUrl.normalize(line),
          name: Uri.decodeComponent(uri.fragment),
        ),
      );
    }
    return entries;
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
    final textFiles = <String>["txt", "json", "yaml", "yml"];
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
      try {
        final url = text.trim();
        if (url.startsWith('onexray://')) {
          final links = OneXrayAppLinkParser.parseText(url);
          for (final link in links) {
            if (await _appLinkImporter.importLink(link, showLoading: false)) {
              success = true;
            }
          }
        } else if (url.startsWith("https://")) {
          final entries = parseSubscriptionImportEntries(url);
          final imported = await SubscriptionService().importSubscriptions(
            entries,
          );
          success = imported > 0;
        } else {
          final rows = await XrayShareReader().parseShareText(url);
          if (rows.isNotEmpty) {
            final writeResult = await ConfigWriter.writeRowsWithResult(
              rows,
              null,
            );
            if (writeResult.count > 0) {
              PingService().schedulePingConfigIds(writeResult.ids);
              success = true;
            }
          }
        }
      } catch (error, stackTrace) {
        ygLogger('import share text failed: $error\n$stackTrace');
      } finally {
        eventBus.updateDownloading(false);
      }
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
