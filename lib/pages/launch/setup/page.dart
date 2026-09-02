import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/launch/setup/controller.dart';
import 'package:onexray/pages/launch/setup/selectors.dart';
import 'package:onexray/pages/widget/page_action_bar.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/service/launch/setup.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class SetupPage extends StatelessWidget {
  final Future<void> Function(BuildContext) addServers;
  const SetupPage({super.key, required this.addServers});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => SetupController(),
    child: BlocConsumer<SetupController, SetupPageState>(
      listenWhen: (previous, next) => previous.step != next.step,
      listener: (context, state) {
        if (state.step == SetupStep.complete) {
          context.read<SetupController>().goHome(context);
        }
      },
      builder: (context, state) {
        final controller = context.read<SetupController>();
        final l10n = AppLocalizations.of(context)!;
        final steps = [
          l10n.prototypeWelcomePrivacy,
          l10n.prototypeSystemSetup,
          l10n.prototypeYourRegion,
          l10n.prototypeAddServers,
        ];
        return PopScope(
          canPop: false,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('OneXray'),
              automaticallyImplyLeading: false,
            ),
            body: SafeArea(
              child: SettingsPageScroll(
                desktopMaxWidth: 760,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      label: l10n.prototypeSetupProgress,
                      child: Wrap(
                        spacing: 18,
                        runSpacing: 10,
                        children: [
                          for (var index = 0; index < steps.length; index++)
                            Text(
                              '${index + 1}. ${steps[index]}',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: index == state.step.index
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                  ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 36),
                    ..._content(context, controller, state),
                    if (state.busy) ...[
                      const SizedBox(height: 20),
                      const LinearProgressIndicator(),
                    ],
                    if (state.failure != null) ...[
                      const SizedBox(height: 20),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          controller.failureText(l10n),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                      if (state.failure!.component != 'permission' &&
                          state.failure!.component != 'region')
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton(
                            onPressed: state.busy ? null : controller.retry,
                            child: Text(l10n.prototypeRetry),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            bottomNavigationBar: PageActionBar(
              children: _actions(context, controller, state),
            ),
          ),
        );
      },
    ),
  );

  List<Widget> _content(
    BuildContext context,
    SetupController controller,
    SetupPageState state,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final titleStyle = Theme.of(context).textTheme.headlineSmall;
    switch (state.step) {
      case SetupStep.welcome:
        return [
          Icon(
            LucideIcons.shieldCheck,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(l10n.prototypeWelcome, style: titleStyle),
          const SizedBox(height: 8),
          Text(l10n.prototypeWelcomeSubtitle),
          const SizedBox(height: 28),
          ListTile(
            leading: const Icon(LucideIcons.shieldCheck),
            title: Text(l10n.prototypeNoDataCollection),
          ),
          ListTile(
            leading: const Icon(LucideIcons.userRound),
            title: Text(l10n.prototypeBringOwnServers),
          ),
          Text(l10n.prototypeConfiguredSourcesNotice),
          const SizedBox(height: 12),
          Text(l10n.prototypeRegionPrivacyNotice),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: state.busy ? null : controller.openPrivacy,
              child: Text(l10n.prototypeReadFullPrivacyPolicy),
            ),
          ),
        ];
      case SetupStep.system:
        return [
          Text(l10n.prototypeGetReadyToConnect, style: titleStyle),
          const SizedBox(height: 8),
          Text(l10n.prototypeSetupOnce),
          const SizedBox(height: 24),
          if (state.localReady)
            ListTile(
              leading: const Icon(LucideIcons.circleCheck),
              title: Text(l10n.prototypeLocalConfigurationReady),
            ),
          ListTile(
            leading: const Icon(LucideIcons.shieldCheck),
            title: Text(l10n.prototypeVpnPermission),
            subtitle: Text(
              state.authorized
                  ? l10n.prototypeAuthorized
                  : l10n.prototypeAllowAddVpn,
            ),
            trailing: state.authorized
                ? const Icon(LucideIcons.circleCheck)
                : const Icon(LucideIcons.chevronRight),
            onTap: state.busy || state.authorized
                ? null
                : controller.requestPermission,
          ),
          if (controller.service.requiresInterface) ...[
            ListTile(
              leading: const Icon(LucideIcons.network),
              title: Text(l10n.prototypeXrayOutboundInterface),
              subtitle: Text(
                state.interfaceName.isEmpty
                    ? l10n.prototypeNotSelected
                    : state.interfaceName,
              ),
              trailing: const Icon(LucideIcons.chevronRight),
              onTap: state.busy
                  ? null
                  : () => controller.chooseInterface(context),
            ),
            Text(l10n.prototypeChooseInterfaceNotice),
          ],
          const SizedBox(height: 24),
          Text(l10n.prototypeSetupDoesNotStartVpn),
        ];
      case SetupStep.region:
        return [
          Text(l10n.prototypeWhereWillYouUse, style: titleStyle),
          const SizedBox(height: 8),
          Text(l10n.prototypeRegionPurpose),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(LucideIcons.globe2),
            title: Text(setupRegionLabel(l10n, state.region)),
            subtitle: Text(state.region),
            trailing: const Icon(LucideIcons.chevronRight),
            onTap: state.busy ? null : () => controller.chooseRegion(context),
          ),
          Text(
            state.regionSuggested
                ? l10n.prototypeRegionSuggested
                : l10n.prototypeRegionSelectedManually,
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: state.busy ? null : controller.detectRegion,
              icon: const Icon(LucideIcons.locateFixed),
              label: Text(l10n.prototypeDetect),
            ),
          ),
          const SizedBox(height: 20),
          Text(l10n.prototypeRegionSkipNotice),
        ];
      case SetupStep.servers:
        return [
          Text(l10n.prototypeAddServers, style: titleStyle),
          const SizedBox(height: 8),
          Text(l10n.prototypeImportServersSubtitle),
          const SizedBox(height: 24),
          if (state.hasServers)
            ListTile(
              leading: const Icon(LucideIcons.circleCheck),
              title: Text(l10n.prototypeServersReadyForHome),
            ),
          ListTile(
            leading: const Icon(LucideIcons.plus),
            title: Text(l10n.prototypeAddServers),
            subtitle: Text(l10n.prototypeChooseAddMethod),
            trailing: const Icon(LucideIcons.chevronRight),
            onTap: state.busy
                ? null
                : () => controller.addServers(context, addServers),
          ),
          const SizedBox(height: 20),
          Text(l10n.prototypeExistingServersSkip),
        ];
      case SetupStep.complete:
        return const [];
    }
  }

  List<Widget> _actions(
    BuildContext context,
    SetupController controller,
    SetupPageState state,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return switch (state.step) {
      SetupStep.welcome => [
        ShadButton(
          onPressed: state.busy ? null : controller.acceptPrivacy,
          child: Text(l10n.prototypeAgreeAndContinue),
        ),
      ],
      SetupStep.system => [
        ShadButton.outline(
          onPressed: state.busy ? null : controller.showWelcome,
          child: Text(l10n.prototypeBack),
        ),
        ShadButton(
          onPressed: state.busy
              ? null
              : state.authorized
              ? (controller.ready ? controller.continueSystem : null)
              : controller.requestPermission,
          child: Text(
            state.authorized ? l10n.prototypeContinue : l10n.prototypeSetUpVpn,
          ),
        ),
      ],
      SetupStep.region => [
        ShadButton.outline(
          onPressed: state.busy
              ? null
              : () => controller.continueRegion(confirm: false),
          child: Text(l10n.prototypeSkip),
        ),
        ShadButton(
          onPressed: state.busy
              ? null
              : () => controller.continueRegion(confirm: true),
          child: Text(l10n.prototypeConfirmAndContinue),
        ),
      ],
      SetupStep.servers => [
        ShadButton.outline(
          onPressed: state.busy ? null : controller.finish,
          child: Text(l10n.prototypeAddLater),
        ),
        ShadButton(
          onPressed: state.busy || !state.hasServers ? null : controller.finish,
          child: Text(l10n.prototypeGoToHome),
        ),
      ],
      SetupStep.complete => const [],
    };
  }
}
