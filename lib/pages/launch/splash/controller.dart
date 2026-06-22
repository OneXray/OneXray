import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/pages/launch/route.dart';
import 'package:onexray/pages/main/url.dart';
import 'package:onexray/service/launch/bootstrap.dart';

class SplashState {
  final String? route;

  const SplashState({this.route});

  factory SplashState.initial() => const SplashState();

  SplashState navigate(String route) => SplashState(route: route);
}

class SplashController extends Cubit<SplashState> {
  SplashController() : super(SplashState.initial()) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _initRouter());
  }

  Future<void> _initRouter() async {
    try {
      final destination = await LaunchBootstrapService().resolveDestination();
      if (!isClosed) {
        emit(state.navigate(destination.route));
      }
    } catch (e, stackTrace) {
      ygLogger("initRouter error: $e\n$stackTrace");
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: e,
          stack: stackTrace,
          library: "OneXray launch",
          context: ErrorDescription("while initializing the launch router"),
        ),
      );
      if (!isClosed) {
        emit(state.navigate(RouterPath.privacy));
      }
    }
  }
}
