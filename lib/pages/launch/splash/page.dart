import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/pages/launch/splash/controller.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SplashController(),
      child: BlocListener<SplashController, SplashState>(
        listenWhen: (previous, current) =>
            previous.route != current.route && current.route != null,
        listener: (context, state) {
          final route = state.route;
          if (route != null) {
            context.go(route);
          }
        },
        child: const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
    );
  }
}
