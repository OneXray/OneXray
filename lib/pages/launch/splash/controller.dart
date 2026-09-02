import 'package:flutter/material.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/pages/launch/route.dart';
import 'package:onexray/service/launch/bootstrap.dart';
import 'package:onexray/service/app_startup/service.dart';

class SplashPageState {
  final String? route;
  final bool failed;

  const SplashPageState({this.route, this.failed = false});

  factory SplashPageState.initial() => const SplashPageState();

  SplashPageState navigate(String route) => SplashPageState(route: route);
}

class SplashController extends PageCubit<SplashPageState> {
  SplashController() : super(SplashPageState.initial()) {
    WidgetsBinding.instance.addPostFrameCallback((_) => retry());
  }

  Future<void> retry() async {
    emit(const SplashPageState());
    try {
      final destination = await LaunchBootstrapService().resolveDestination();
      if (isPageActive) {
        emit(state.navigate(destination.route));
      }
    } catch (e, stackTrace) {
      ygLogger("initRouter error: $e\n$stackTrace");
      try {
        await AppStartupService().showMainWindow();
      } catch (_) {
        // Keep the original preparation failure and its retry path.
      }
      if (isPageActive) {
        emit(const SplashPageState(failed: true));
      }
    }
  }
}
