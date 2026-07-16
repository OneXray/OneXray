import 'package:flutter/material.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/pages/launch/route.dart';
import 'package:onexray/pages/main/url.dart';
import 'package:onexray/service/launch/bootstrap.dart';

class SplashPageState {
  final String? route;

  const SplashPageState({this.route});

  factory SplashPageState.initial() => const SplashPageState();

  SplashPageState navigate(String route) => SplashPageState(route: route);
}

class SplashController extends PageCubit<SplashPageState> {
  SplashController() : super(SplashPageState.initial()) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _initRouter());
  }

  Future<void> _initRouter() async {
    try {
      final destination = await LaunchBootstrapService().resolveDestination();
      if (isPageActive) {
        emit(state.navigate(destination.route));
      }
    } catch (e, stackTrace) {
      ygLogger("initRouter error: $e\n$stackTrace");
      if (isPageActive) {
        emit(state.navigate(RouterPath.privacy));
      }
    }
  }
}
