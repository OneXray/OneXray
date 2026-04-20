import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/tools/file.dart';
import 'package:onexray/gen/assets.gen.dart';
import 'package:onexray/pages/main/url.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/core/pigeon/constants.dart';
import 'package:path/path.dart' as p;

Future<void> initRouter(BuildContext context) async {
  await _initTheme(context);
  final privacyAccepted = await PreferencesKey().readPrivacyAccepted();
  if (context.mounted) {
    if (privacyAccepted) {
      await checkFirstRun(context);
    } else {
      context.go(RouterPath.privacy);
    }
  }
}

Future<void> checkFirstRun(BuildContext context) async {
  await _initApp(context);
  final firstRun = await PreferencesKey().readFirstRun();
  if (context.mounted) {
    if (firstRun) {
      context.go(RouterPath.firstRun);
    } else {
      context.go(RouterPath.home);
    }
  }
}

Future<void> _initApp(BuildContext context) async {
  if (context.mounted) {
    await _initService(context);
  }
  await _checkSystemDat();
}

Future<void> _initTheme(BuildContext context) async {
  final eventBus = context.read<AppEventBus>();
  await eventBus.asyncInitTheme();
}

Future<void> _initService(BuildContext context) async {
  final eventBus = context.read<AppEventBus>();
  await eventBus.asyncInitService(context);
}

Future<void> _checkSystemDat() async {
  final datPath = VpnConstants.datDir;
  await FileTool.checkDir(datPath);

  final dstTimestampPath = p.join(datPath, VpnConstants.systemGeoTimestamp);
  final dstTimestampFile = File(dstTimestampPath);
  final exists = await dstTimestampFile.exists();
  if (exists) {
    var dstTimestamp = await dstTimestampFile.readAsString();
    dstTimestamp = dstTimestamp.trim();
    var srcTimestamp = await rootBundle.loadString(Assets.dat.timestamp);
    srcTimestamp = srcTimestamp.trim();
    if (srcTimestamp.compareTo(dstTimestamp) > 0) {
      await FileTool.copyAssets(Assets.dat.values, datPath);
    }
  } else {
    await FileTool.copyAssets(Assets.dat.values, datPath);
  }
}
