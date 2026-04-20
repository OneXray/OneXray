import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/db/database/enum.dart';
import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/tools/file.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/service/localizations/service.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/home/share/params.dart';
import 'package:onexray/service/share/protocol.dart';
import 'package:onexray/service/xray/outbound/state.dart';
import 'package:onexray/service/xray/outbound/state_reader.dart';
import 'package:onexray/service/xray/outbound/state_writer.dart';
import 'package:onexray/service/xray/standard.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:tuple/tuple.dart';
import 'package:zxing2/qrcode.dart';

class ShareState {
  final bool showLinkSection;
  final String linkSection;
  final String linkUrl;
  final bool linkQrcodeSuccess;
  final String appUrl;

  const ShareState({
    required this.showLinkSection,
    required this.linkSection,
    required this.linkUrl,
    required this.linkQrcodeSuccess,
    required this.appUrl,
  });

  factory ShareState.initial() => const ShareState(
        showLinkSection: false,
        linkSection: "",
        linkUrl: "",
        linkQrcodeSuccess: false,
        appUrl: "",
      );

  ShareState copyWith({
    bool? showLinkSection,
    String? linkSection,
    String? linkUrl,
    bool? linkQrcodeSuccess,
    String? appUrl,
  }) {
    return ShareState(
      showLinkSection: showLinkSection ?? this.showLinkSection,
      linkSection: linkSection ?? this.linkSection,
      linkUrl: linkUrl ?? this.linkUrl,
      linkQrcodeSuccess: linkQrcodeSuccess ?? this.linkQrcodeSuccess,
      appUrl: appUrl ?? this.appUrl,
    );
  }
}

class ShareController extends Cubit<ShareState> {
  final SharePageParams params;
  ShareController(this.params) : super(ShareState.initial()) {
    _initParams();
  }

  var _linkQrcode = Uint8List(0);
  var _name = "";

  void _initParams() {
    switch (params.type) {
      case ShareType.config:
        _queryConfig(params.id);
        break;
      case ShareType.subscription:
        _querySubscription(params.id);
        break;
      case ShareType.geoDat:
        _queryGeoData(params.id);
        break;
    }
  }

  Future<void> _queryConfig(int configId) async {
    final db = AppDatabase();
    if (configId != DBConstants.defaultId) {
      final config = await db.coreConfigDao.searchRow(configId);
      if (config != null) {
        final type = CoreConfigType.fromString(config.type);
        if (type == CoreConfigType.outbound) {
          emit(state.copyWith(
            showLinkSection: true,
            linkSection: appLocalizationsNoContext().sharePageXrayLink,
          ));
          await _parseXrayJson(config);
        }
        final result = await AppShareService().generateConfigLink(config);
        await _finishApp(result);
      }
    }
  }

  Future<void> _querySubscription(int subscriptionId) async {
    final db = AppDatabase();
    if (subscriptionId != DBConstants.defaultId) {
      final subscription = await db.subscriptionDao.searchRow(subscriptionId);
      if (subscription != null) {
        emit(state.copyWith(
          showLinkSection: true,
          linkSection: appLocalizationsNoContext().sharePageSubscriptionLink,
        ));
        await _parseShareSubscription(subscription);
        final result = AppShareService().generateSubscriptionLink(subscription);
        await _finishApp(result);
      }
    }
  }

  Future<void> _queryGeoData(int geoDataId) async {
    final db = AppDatabase();
    if (geoDataId != DBConstants.defaultId) {
      final geoData = await db.geoDataDao.searchRow(geoDataId);
      if (geoData != null) {
        final result = AppShareService().generateGeoDataLink(geoData);
        await _finishApp(result);
      }
    }
  }

  Future<void> _parseXrayJson(CoreConfigData outbound) async {
    final outboundState = OutboundState();
    outboundState.readFromDbData(outbound);
    final xrayJson = XrayJsonStandard.standard;
    xrayJson.outbounds = [_readXrayOutbounds(outboundState)];
    final url = await AppHostApi().convertXrayJsonToShareLinks(xrayJson);
    await _finishLink(url, outboundState.name);
  }

  XrayOutbound _readXrayOutbounds(OutboundState outboundState) {
    final outbound = outboundState.xrayJson;
    outbound.sendThrough = outbound.name;
    return outbound;
  }

  Future<void> _parseShareSubscription(SubscriptionData subscription) async {
    var url = subscription.url;
    final name = subscription.name;
    final uri = Uri.tryParse(url);
    if (uri != null) {
      if (uri.fragment.isEmpty) {
        url = "$url#${Uri.encodeComponent(name)}";
      }
    }
    await _finishLink(url, name);
  }

  Future<void> _finishLink(String url, String name) async {
    _name = name;
    emit(state.copyWith(linkUrl: url));
    final qrcode = await Isolate.run(() => _drawQrcode(url, name));
    if (qrcode != null) {
      _linkQrcode = qrcode;
      emit(state.copyWith(linkQrcodeSuccess: true));
    }
  }

  Future<void> _finishApp(Tuple2<String, String> result) async {
    final url = result.item1;
    final name = result.item2;
    if (url.isEmpty || name.isEmpty) {
      return;
    }

    _name = name;
    emit(state.copyWith(appUrl: url));
  }

  Future<void> shareLinkQrcode(BuildContext context) async {
    await _shareQrcode(context, _linkQrcode);
  }

  Future<void> _shareQrcode(BuildContext context, Uint8List qrcode) async {
    Rect? sharePositionOrigin;
    if (context.mounted) {
      final box = context.findRenderObject() as RenderBox?;
      if (box != null) {
        sharePositionOrigin = box.localToGlobal(Offset.zero) & box.size;
      }
    }

    final cacheDir = await FileTool.makeCacheDir();
    final imagePath = p.join(cacheDir, "$_name.png");
    await File(imagePath).writeAsBytes(qrcode);

    final params = ShareParams(
      files: [XFile(imagePath)],
      fileNameOverrides: [_name],
      sharePositionOrigin: sharePositionOrigin,
    );
    final result = await SharePlus.instance.share(params);
    await FileTool.deleteDirIfExists(cacheDir);
    if (context.mounted) {
      _showActionResult(
        context,
        result.status == ShareResultStatus.success,
        AppLocalizations.of(context)!.sharePageShareQRCode,
      );
    }
  }

  void _showActionResult(BuildContext context, bool success, String action) {
    if (success) {
      ContextAlert.showToast(
        context,
        AppLocalizations.of(
          context,
        )!.actionResult(action, AppLocalizations.of(context)!.resultSuccess),
      );
      context.pop();
    } else {
      ContextAlert.showToast(
        context,
        AppLocalizations.of(
          context,
        )!.actionResult(action, AppLocalizations.of(context)!.resultFailed),
      );
    }
  }

  Future<void> saveLinkQrcode(BuildContext context) async {
    await _saveQrcode(context, _linkQrcode);
  }

  Future<void> _saveQrcode(BuildContext context, Uint8List qrcode) async {
    final success = await FileTool.saveData(qrcode, "$_name.png", ".png");
    if (context.mounted) {
      _showActionResult(
        context,
        success,
        AppLocalizations.of(context)!.sharePageSaveQRCode,
      );
    }
  }

  Future<void> showLinkQrcode(BuildContext context) async {
    await _showQrcode(context, _linkQrcode);
  }

  Future<void> _showQrcode(BuildContext context, Uint8List qrcode) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Container(
          constraints: const BoxConstraints(maxWidth: 300, maxHeight: 300),
          child: Image.memory(qrcode),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context)!.buttonOK),
          ),
        ],
      ),
    );
  }

  Future<void> shareLinkUrl(BuildContext context) async {
    await _shareUrl(context, state.linkUrl);
  }

  Future<void> shareAppUrl(BuildContext context) async {
    await _shareUrl(context, state.appUrl);
  }

  Future<void> _shareUrl(BuildContext context, String url) async {
    Rect? sharePositionOrigin;
    if (context.mounted) {
      final box = context.findRenderObject() as RenderBox?;
      if (box != null) {
        sharePositionOrigin = box.localToGlobal(Offset.zero) & box.size;
      }
    }
    final params = ShareParams(
      text: url,
      subject: _name,
      sharePositionOrigin: sharePositionOrigin,
    );
    final result = await SharePlus.instance.share(params);

    if (context.mounted) {
      _showActionResult(
        context,
        result.status == ShareResultStatus.success,
        AppLocalizations.of(context)!.sharePageShareLink,
      );
    }
  }

  Future<void> copyLinkUrl(BuildContext context) async {
    await _copyUrl(context, state.linkUrl);
  }

  Future<void> copyAppUrl(BuildContext context) async {
    await _copyUrl(context, state.appUrl);
  }

  Future<void> _copyUrl(BuildContext context, String url) async {
    final data = ClipboardData(text: url);
    await Clipboard.setData(data);
    if (context.mounted) {
      ContextAlert.showToast(
        context,
        AppLocalizations.of(context)!.actionResult(
          AppLocalizations.of(context)!.sharePageCopyLink,
          AppLocalizations.of(context)!.resultSuccess,
        ),
      );
      context.pop();
    }
  }
}

Uint8List? _drawQrcode(String shareLink, String name) {
  try {
    final qrcode = Encoder.encode(shareLink, ErrorCorrectionLevel.h);
    final matrix = qrcode.matrix!;
    var scale = (800 / matrix.width).toInt();
    if (scale < 1) {
      scale = 1;
    }
    final padding = 80;
    final width = matrix.width * scale + padding * 2;
    final height = matrix.height * scale + padding * 2;

    final image = img.Image(width: width, height: height, numChannels: 4);
    img.fill(image, color: img.ColorRgb8(255, 255, 255));

    for (var x = 0; x < matrix.width; x++) {
      for (var y = 0; y < matrix.height; y++) {
        if (matrix.get(x, y) == 1) {
          img.fillRect(
            image,
            x1: x * scale + padding,
            y1: y * scale + padding,
            x2: x * scale + scale + padding,
            y2: y * scale + scale + padding,
            color: img.ColorRgb8(0, 0, 0),
          );
        }
      }
    }

    img.drawString(
      image,
      name,
      font: img.arial48,
      x: padding,
      y: height - padding + 10,
      color: img.ColorRgb8(0, 0, 0),
    );

    return img.encodePng(image);
  } catch (_) {
    return null;
  }
}
