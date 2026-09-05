import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/pages/launch/splash/controller.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SplashController(),
      child: BlocConsumer<SplashController, SplashPageState>(
        listenWhen: (previous, current) =>
            previous.route != current.route && current.route != null,
        listener: (context, state) {
          final route = state.route;
          if (route != null) {
            context.go(route);
          }
        },
        builder: (context, state) => Scaffold(
          body: Center(
            child: state.failed
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(AppLocalizations.of(context)!.resultFailed),
                      TextButton(
                        onPressed: context.read<SplashController>().retry,
                        child: Text(AppLocalizations.of(context)!.buttonRetry),
                      ),
                    ],
                  )
                : const CircularProgressIndicator(),
          ),
        ),
      ),
    );
  }
}
