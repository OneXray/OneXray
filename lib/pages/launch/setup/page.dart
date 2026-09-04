import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/launch/setup/controller.dart';
import 'package:onexray/pages/launch/setup/view.dart';
import 'package:onexray/pages/servers/import/controller.dart';
import 'package:onexray/service/launch/setup.dart';

export 'controller.dart' show SetupAction, SetupPageState;
export 'privacy.dart' show SetupPrivacyPage, SetupPrivacyView;
export 'view.dart' show SetupView;

class SetupPage extends StatelessWidget {
  final Future<void> Function(BuildContext, ServerImportAction) addServers;
  const SetupPage({super.key, required this.addServers});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => SetupController(),
    child: BlocConsumer<SetupController, SetupPageState>(
      listenWhen: (previous, next) => previous.step != next.step,
      listener: (context, state) {
        if (state.step == SetupStep.complete) {
          context.read<SetupController>().goConnect(context);
        }
      },
      builder: (context, state) {
        final controller = context.read<SetupController>();
        return SetupView(
          state: state,
          requiresInterface: controller.service.requiresInterface,
          supportsScan: AppPlatform.isMobile,
          failureText: state.failure == null
              ? null
              : controller.failureText(AppLocalizations.of(context)!),
          onAction: (action) => controller.handleAction(context, action),
          onAddServer: (action) =>
              controller.addServers(context, action, addServers),
        );
      },
    ),
  );
}
