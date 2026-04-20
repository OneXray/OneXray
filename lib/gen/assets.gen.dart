// dart format width=80

/// GENERATED CODE - DO NOT MODIFY BY HAND
/// *****************************************************
///  FlutterGen
/// *****************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: deprecated_member_use,directives_ordering,implicit_dynamic_list_literal,unnecessary_import

import 'package:flutter/widgets.dart';

class $AssetsAppIconGen {
  const $AssetsAppIconGen();

  /// File path: assets/app_icon/black.png
  AssetGenImage get black => const AssetGenImage('assets/app_icon/black.png');

  /// File path: assets/app_icon/blue.png
  AssetGenImage get blue => const AssetGenImage('assets/app_icon/blue.png');

  /// File path: assets/app_icon/green.png
  AssetGenImage get green => const AssetGenImage('assets/app_icon/green.png');

  /// File path: assets/app_icon/orange.png
  AssetGenImage get orange => const AssetGenImage('assets/app_icon/orange.png');

  /// File path: assets/app_icon/purple.png
  AssetGenImage get purple => const AssetGenImage('assets/app_icon/purple.png');

  /// File path: assets/app_icon/red.png
  AssetGenImage get red => const AssetGenImage('assets/app_icon/red.png');

  /// List of all assets
  List<AssetGenImage> get values => [black, blue, green, orange, purple, red];
}

class $AssetsDatGen {
  const $AssetsDatGen();

  /// File path: assets/dat/geoip.dat
  String get geoipDat => 'assets/dat/geoip.dat';

  /// File path: assets/dat/geoip.json
  String get geoipJson => 'assets/dat/geoip.json';

  /// File path: assets/dat/geosite.dat
  String get geositeDat => 'assets/dat/geosite.dat';

  /// File path: assets/dat/geosite.json
  String get geositeJson => 'assets/dat/geosite.json';

  /// File path: assets/dat/timestamp.txt
  String get timestamp => 'assets/dat/timestamp.txt';

  /// List of all assets
  List<String> get values => [
    geoipDat,
    geoipJson,
    geositeDat,
    geositeJson,
    timestamp,
  ];
}

class $AssetsIconGen {
  const $AssetsIconGen();

  /// File path: assets/icon/tray_not_running.ico
  String get trayNotRunningIco => 'assets/icon/tray_not_running.ico';

  /// File path: assets/icon/tray_not_running.png
  AssetGenImage get trayNotRunningPng =>
      const AssetGenImage('assets/icon/tray_not_running.png');

  /// File path: assets/icon/tray_running.ico
  String get trayRunningIco => 'assets/icon/tray_running.ico';

  /// File path: assets/icon/tray_running.png
  AssetGenImage get trayRunningPng =>
      const AssetGenImage('assets/icon/tray_running.png');

  /// List of all assets
  List<dynamic> get values => [
    trayNotRunningIco,
    trayNotRunningPng,
    trayRunningIco,
    trayRunningPng,
  ];
}

class $AssetsMdGen {
  const $AssetsMdGen();

  /// File path: assets/md/privacy.md
  String get privacy => 'assets/md/privacy.md';

  /// List of all assets
  List<String> get values => [privacy];
}

class Assets {
  const Assets._();

  static const $AssetsAppIconGen appIcon = $AssetsAppIconGen();
  static const $AssetsDatGen dat = $AssetsDatGen();
  static const $AssetsIconGen icon = $AssetsIconGen();
  static const AssetGenImage logo = AssetGenImage('assets/logo.png');
  static const $AssetsMdGen md = $AssetsMdGen();

  /// List of all assets
  static List<AssetGenImage> get values => [logo];
}

class AssetGenImage {
  const AssetGenImage(
    this._assetName, {
    this.size,
    this.flavors = const {},
    this.animation,
  });

  final String _assetName;

  final Size? size;
  final Set<String> flavors;
  final AssetGenImageAnimation? animation;

  Image image({
    Key? key,
    AssetBundle? bundle,
    ImageFrameBuilder? frameBuilder,
    ImageErrorWidgetBuilder? errorBuilder,
    String? semanticLabel,
    bool excludeFromSemantics = false,
    double? scale,
    double? width,
    double? height,
    Color? color,
    Animation<double>? opacity,
    BlendMode? colorBlendMode,
    BoxFit? fit,
    AlignmentGeometry alignment = Alignment.center,
    ImageRepeat repeat = ImageRepeat.noRepeat,
    Rect? centerSlice,
    bool matchTextDirection = false,
    bool gaplessPlayback = true,
    bool isAntiAlias = false,
    String? package,
    FilterQuality filterQuality = FilterQuality.medium,
    int? cacheWidth,
    int? cacheHeight,
  }) {
    return Image.asset(
      _assetName,
      key: key,
      bundle: bundle,
      frameBuilder: frameBuilder,
      errorBuilder: errorBuilder,
      semanticLabel: semanticLabel,
      excludeFromSemantics: excludeFromSemantics,
      scale: scale,
      width: width,
      height: height,
      color: color,
      opacity: opacity,
      colorBlendMode: colorBlendMode,
      fit: fit,
      alignment: alignment,
      repeat: repeat,
      centerSlice: centerSlice,
      matchTextDirection: matchTextDirection,
      gaplessPlayback: gaplessPlayback,
      isAntiAlias: isAntiAlias,
      package: package,
      filterQuality: filterQuality,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
    );
  }

  ImageProvider provider({AssetBundle? bundle, String? package}) {
    return AssetImage(_assetName, bundle: bundle, package: package);
  }

  String get path => _assetName;

  String get keyName => _assetName;
}

class AssetGenImageAnimation {
  const AssetGenImageAnimation({
    required this.isAnimation,
    required this.duration,
    required this.frames,
  });

  final bool isAnimation;
  final Duration duration;
  final int frames;
}
