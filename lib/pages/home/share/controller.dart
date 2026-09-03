import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/db/database/enum.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/tools/file.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/home/share/params.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:onexray/service/localizations/service.dart';
import 'package:onexray/service/share/app_link_share_service.dart';
import 'package:onexray/service/xray/outbound/map.dart';
import 'package:onexray/service/xray/outbound/state_db.dart';
import 'package:share_plus/share_plus.dart';
import 'package:zxing2/qrcode.dart';

enum ShareLinkFormat { original, onexray }

class SharePageState {
  const SharePageState({
    this.loading = true,
    this.name = '',
    this.originalLink = '',
    this.appLink = '',
    this.linkError = '',
    this.format = ShareLinkFormat.original,
    this.qrExpanded = false,
    this.qrCode,
    this.qrError = '',
  });

  final bool loading;
  final String name;
  final String originalLink;
  final String appLink;
  final String linkError;
  final ShareLinkFormat format;
  final bool qrExpanded;
  final Uint8List? qrCode;
  final String qrError;

  String get selectedLink =>
      format == ShareLinkFormat.original ? originalLink : appLink;

  SharePageState copyWith({
    bool? loading,
    String? name,
    String? originalLink,
    String? appLink,
    String? linkError,
    ShareLinkFormat? format,
    bool? qrExpanded,
    Uint8List? qrCode,
    bool clearQr = false,
    String? qrError,
  }) => SharePageState(
    loading: loading ?? this.loading,
    name: name ?? this.name,
    originalLink: originalLink ?? this.originalLink,
    appLink: appLink ?? this.appLink,
    linkError: linkError ?? this.linkError,
    format: format ?? this.format,
    qrExpanded: qrExpanded ?? this.qrExpanded,
    qrCode: clearQr ? null : qrCode ?? this.qrCode,
    qrError: qrError ?? this.qrError,
  );
}

class ShareController extends PageCubit<SharePageState> {
  ShareController(
    this.params, {
    AppDatabase? database,
    Future<Uint8List?> Function(String)? qrEncoder,
  }) : _database = database ?? AppDatabase(),
       _qrEncoder = qrEncoder ?? _encodeQr,
       super(const SharePageState()) {
    _initialize();
  }

  final SharePageParams params;
  final AppDatabase _database;
  final Future<Uint8List?> Function(String) _qrEncoder;
  late final _appLinkShareService = OneXrayAppLinkShareService(
    geoDataLookup: _database.geoDataDao.searchRowByName,
  );
  int _qrGeneration = 0;

  Future<void> _initialize() async {
    try {
      switch (params.type) {
        case ShareType.config:
          await _queryConfig(params.id);
        case ShareType.subscription:
          await _querySubscription(params.id);
      }
    } catch (error) {
      ygLogger('generate share link failed (${error.runtimeType})');
      _finishLinkError();
    } finally {
      emit(state.copyWith(loading: false));
    }
  }

  Future<void> _queryConfig(int configId) async {
    final config = configId == DBConstants.defaultId
        ? null
        : await _database.coreConfigDao.searchRow(configId);
    if (config == null ||
        CoreConfigType.fromString(config.type) != CoreConfigType.outbound) {
      _finishLinkError();
      return;
    }
    emit(
      state.copyWith(
        name: config.name,
        appLink: await _appLinkShareService.config(config) ?? '',
      ),
    );
    final outbound = readOutboundFromDbData(config);
    requireCanonicalOutbound(outbound);
    final url = await AppHostApi().convertXrayJsonToShareLinks({
      'outbounds': [outbound],
    });
    if (url.trim().isEmpty) {
      _finishLinkError();
      return;
    }
    emit(
      state.copyWith(name: outboundDisplayName(outbound), originalLink: url),
    );
  }

  Future<void> _querySubscription(int subscriptionId) async {
    final source = subscriptionId == DBConstants.defaultId
        ? null
        : await _database.subscriptionDao.searchRow(subscriptionId);
    if (source == null) {
      _finishLinkError();
      return;
    }
    var url = source.url;
    final uri = Uri.tryParse(url);
    if (uri != null && uri.fragment.isEmpty) {
      url = '$url#${Uri.encodeComponent(source.name)}';
    }
    emit(state.copyWith(name: source.name, originalLink: url));
    emit(
      state.copyWith(appLink: _appLinkShareService.subscription(source) ?? ''),
    );
  }

  void _finishLinkError() {
    final l = appLocalizationsNoContext();
    emit(state.copyWith(linkError: '${l.sharePageLink}: ${l.resultFailed}'));
  }

  void selectFormat(ShareLinkFormat format) {
    if (state.format == format) return;
    _qrGeneration++;
    emit(state.copyWith(format: format, clearQr: true, qrError: ''));
    if (state.qrExpanded) _generateQr();
  }

  void toggleQr() {
    _qrGeneration++;
    emit(
      state.copyWith(qrExpanded: !state.qrExpanded, clearQr: true, qrError: ''),
    );
    if (state.qrExpanded) _generateQr();
  }

  Future<void> _generateQr() async {
    final link = state.selectedLink;
    if (link.isEmpty) return;
    final generation = ++_qrGeneration;
    Uint8List? image;
    try {
      image = await _qrEncoder(link);
    } catch (_) {
      // Generation failure is shown only for the currently selected format.
    }
    if (!isPageActive ||
        generation != _qrGeneration ||
        !state.qrExpanded ||
        link != state.selectedLink) {
      return;
    }
    final l = appLocalizationsNoContext();
    emit(
      state.copyWith(
        qrCode: image,
        clearQr: image == null,
        qrError: image == null ? '${l.sharePageQRCode}: ${l.resultFailed}' : '',
      ),
    );
  }

  Future<void> shareSelectedLink(BuildContext context) async {
    final url = state.selectedLink;
    if (state.loading || url.isEmpty) return;
    if (AppPlatform.isLinux) {
      await _copyUrl(context, url);
      return;
    }
    Rect? sharePositionOrigin;
    if (context.mounted) {
      final box = context.findRenderObject() as RenderBox?;
      if (box != null) {
        sharePositionOrigin = box.localToGlobal(Offset.zero) & box.size;
      }
    }
    final result = await SharePlus.instance.share(
      ShareParams(
        text: url,
        subject: state.name,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
    if (context.mounted && result.status != ShareResultStatus.dismissed) {
      _showActionResult(
        context,
        result.status == ShareResultStatus.success,
        AppLocalizations.of(context)!.sharePageShareLink,
      );
    }
  }

  Future<void> saveQr(BuildContext context) async {
    final qrcode = state.qrCode;
    if (qrcode == null) return;
    final success = await FileTool.saveData(
      qrcode,
      '${state.name}.png',
      '.png',
    );
    if (context.mounted) {
      _showActionResult(
        context,
        success,
        AppLocalizations.of(context)!.sharePageSaveQRCode,
        closeOnSuccess: false,
      );
    }
  }

  void _showActionResult(
    BuildContext context,
    bool success,
    String action, {
    bool closeOnSuccess = true,
  }) {
    final l = AppLocalizations.of(context)!;
    ContextAlert.showToast(
      context,
      l.actionResult(action, success ? l.resultSuccess : l.resultFailed),
    );
    if (success && closeOnSuccess) context.pop();
  }

  Future<void> _copyUrl(BuildContext context, String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      final l = AppLocalizations.of(context)!;
      ContextAlert.showToast(
        context,
        l.actionResult(l.sharePageCopyLink, l.resultSuccess),
      );
      context.pop();
    }
  }
}

Future<Uint8List?> _encodeQr(String link) =>
    Isolate.run(() => _drawQrcode(link));

Uint8List? _drawQrcode(String shareLink) {
  try {
    final qrcode = Encoder.encode(shareLink, ErrorCorrectionLevel.h);
    final matrix = qrcode.matrix!;
    var scale = (800 / matrix.width).toInt();
    if (scale < 1) scale = 1;
    const padding = 80;
    final image = img.Image(
      width: matrix.width * scale + padding * 2,
      height: matrix.height * scale + padding * 2,
      numChannels: 4,
    );
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
    return img.encodePng(image);
  } catch (_) {
    return null;
  }
}
