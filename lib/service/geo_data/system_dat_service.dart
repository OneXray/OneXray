import 'dart:io';

import 'package:flutter/services.dart';
import 'package:onexray/core/pigeon/constants.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/tools/file.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/gen/assets.gen.dart';
import 'package:path/path.dart' as p;

final class SystemGeoDatService {
  static final SystemGeoDatService _singleton = SystemGeoDatService._internal();

  factory SystemGeoDatService() => _singleton;

  SystemGeoDatService._internal();

  Future<void> checkAssets() async {
    final rootPath = AppHostApi().tunFilesDir;
    if (rootPath.isEmpty) {
      ygLogger("System GeoData asset check skipped: tunFilesDir is empty");
      return;
    }

    final datPath = VpnConstants.datDir;
    await FileTool.checkDir(datPath);

    final dstTimestampPath = p.join(datPath, VpnConstants.systemGeoTimestamp);
    final dstTimestampFile = File(dstTimestampPath);
    final exists = await dstTimestampFile.exists();
    if (!exists) {
      await copyAssetsTo(datPath);
      return;
    }

    var dstTimestamp = await dstTimestampFile.readAsString();
    dstTimestamp = dstTimestamp.trim();
    var srcTimestamp = await rootBundle.loadString(Assets.dat.timestamp);
    srcTimestamp = srcTimestamp.trim();
    if (srcTimestamp.compareTo(dstTimestamp) > 0) {
      await copyAssetsTo(datPath);
    }
  }

  Future<void> copyAssetsTo(String datPath) async {
    await FileTool.checkDir(datPath);
    for (final asset in Assets.dat.values) {
      final data = await rootBundle.load(asset);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      await File(
        p.join(datPath, p.basename(asset)),
      ).writeAsBytes(bytes, flush: true);
    }
  }
}
