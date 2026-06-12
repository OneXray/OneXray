import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/pages/main/url.dart';
import 'package:onexray/service/event_bus/service.dart';

Future<void> initRouter(BuildContext context) async {
  await _initTheme(context);
  final privacyAccepted = await PreferencesKey().readPrivacyAccepted();
  if (!context.mounted) {
    return;
  }
  if (privacyAccepted) {
    await checkFirstRun(context);
  } else {
    context.go(RouterPath.privacy);
  }
}

Future<void> checkFirstRun(BuildContext context) async {
  await _initState(context);
  final firstRun = await PreferencesKey().readFirstRun();
  if (!context.mounted) {
    return;
  }
  if (firstRun) {
    context.go(RouterPath.firstRun);
  } else {
    context.go(RouterPath.home);
  }
}

Future<void> _initTheme(BuildContext context) async {
  final eventBus = context.read<AppEventBus>();
  await eventBus.asyncInitTheme();
}

Future<void> _initState(BuildContext context) async {
  final eventBus = context.read<AppEventBus>();
  await eventBus.asyncInitState();
}
