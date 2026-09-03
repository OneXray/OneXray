import 'package:flutter/material.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/gen/assets.gen.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/launch/setup/controller.dart';
import 'package:onexray/pages/launch/setup/selectors.dart';
import 'package:onexray/pages/launch/setup/widgets.dart';
import 'package:onexray/pages/servers/import/controller.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/service/launch/setup.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The production presentation, without creating services or changing setup
/// preferences. It is also the isolated entry point for visual verification.
class SetupView extends StatelessWidget {
  const SetupView({
    super.key,
    required this.state,
    required this.requiresInterface,
    required this.supportsScan,
    this.failureText,
    required this.onAction,
    required this.onAddServer,
  });

  final SetupPageState state;
  final bool requiresInterface;
  final bool supportsScan;
  final String? failureText;
  final ValueChanged<SetupAction> onAction;
  final ValueChanged<ServerImportAction> onAddServer;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final mobile =
        MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint;
    final welcome = state.step == SetupStep.welcome;
    final palette = ColorManager.palette(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: SetupBody(
            key: ValueKey(state.step),
            top: welcome ? 32 : 24,
            children: [
              if (welcome || !mobile) ...[
                Text(
                  'OneXray',
                  textAlign: welcome ? TextAlign.center : TextAlign.start,
                  style: AppTypography.setupBrand,
                ),
                SizedBox(height: welcome ? 36 : 24),
              ],
              if (!welcome && state.step != SetupStep.complete) ...[
                _SetupProgress(step: state.step),
                const SizedBox(height: 48),
              ],
              ...switch (state.step) {
                SetupStep.welcome => _welcome(context, mobile),
                SetupStep.system => _system(context, mobile),
                SetupStep.region => _region(context, mobile),
                SetupStep.servers => _servers(context, mobile),
                SetupStep.complete => const <Widget>[],
              },
              if (state.step != SetupStep.system) ..._feedback(context),
              if (state.step == SetupStep.region ||
                  state.step == SetupStep.servers) ...[
                const Spacer(),
                const SizedBox(height: 28),
                Text(
                  state.step == SetupStep.region
                      ? l.prototypeRegionSkipNotice
                      : l.prototypeExistingServersSkip,
                  style: AppTypography.setupSkipNote.copyWith(
                    color: palette.mutedForeground,
                  ),
                ),
              ],
            ],
          ),
        ),
        bottomNavigationBar: state.step == SetupStep.complete
            ? null
            : SetupFooter(children: _actions(l)),
      ),
    );
  }

  List<Widget> _welcome(BuildContext context, bool mobile) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    return [
      Center(child: Assets.appIcon.blue.image(width: 96, height: 96)),
      const SizedBox(height: 26),
      Text(
        l.prototypeWelcome,
        textAlign: TextAlign.center,
        style: mobile
            ? AppTypography.setupWelcomeTitle
            : AppTypography.setupDesktopTitle,
      ),
      const SizedBox(height: 12),
      Text(
        l.prototypeWelcomeSubtitle,
        textAlign: TextAlign.center,
        style:
            (mobile
                    ? AppTypography.setupSubtitle
                    : AppTypography.setupDesktopSubtitle)
                .copyWith(color: palette.mutedStrong),
      ),
      const SizedBox(height: 36),
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: IntrinsicWidth(
            child: Column(
              children: [
                SetupPoint(
                  icon: LucideIcons.shieldCheck,
                  text: l.prototypeNoDataCollection,
                ),
                const SizedBox(height: 24),
                SetupPoint(
                  icon: LucideIcons.userRound,
                  text: l.prototypeBringOwnServers,
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 30),
      Center(
        child: TextButton(
          onPressed: _action(SetupAction.privacy),
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 38),
            padding: EdgeInsets.zero,
            alignment: Alignment.topCenter,
            textStyle: AppTypography.setupPrivacyLink.copyWith(
              decoration: TextDecoration.underline,
            ),
          ),
          child: Text(l.prototypePrivacyPolicy),
        ),
      ),
    ];
  }

  List<Widget> _heading(
    BuildContext context,
    bool mobile,
    String title, [
    String? description,
  ]) => [
    Text(
      title,
      textAlign: mobile ? TextAlign.start : TextAlign.center,
      style: mobile
          ? AppTypography.setupTitle
          : AppTypography.setupDesktopTitle,
    ),
    if (description != null) ...[
      const SizedBox(height: 12),
      Text(
        description,
        textAlign: mobile ? TextAlign.start : TextAlign.center,
        style:
            (mobile
                    ? AppTypography.setupSubtitle
                    : AppTypography.setupDesktopSubtitle)
                .copyWith(color: ColorManager.palette(context).mutedStrong),
      ),
    ],
  ];

  List<Widget> _system(BuildContext context, bool mobile) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    final denied =
        state.permission?.state == PlatformPermissionState.denied ||
        state.failure?.component == 'permission';
    final status = state.authorized
        ? l.prototypeAuthorized
        : denied
        ? l.prototypePermissionNotGranted
        : l.prototypeAwaitingPermission;
    return [
      ..._heading(
        context,
        mobile,
        l.prototypeGetReadyToConnect,
        mobile ? null : l.prototypeSetupOnce,
      ),
      if (state.localReady) ...[
        const SizedBox(height: 30),
        Row(
          mainAxisAlignment: mobile
              ? MainAxisAlignment.start
              : MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.circleCheck, size: 21, color: palette.running),
            const SizedBox(width: 9),
            Flexible(
              child: Text(
                l.prototypeLocalConfigurationReady,
                style: AppTypography.setupReady.copyWith(
                  color: palette.mutedStrong,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
      ] else
        const SizedBox(height: 30),
      DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: palette.border)),
        ),
        child: mobile && !requiresInterface
            ? InkWell(
                onTap: state.authorized
                    ? null
                    : _action(SetupAction.permission),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 170),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          LucideIcons.shieldCheck,
                          size: 36,
                          color: palette.primary,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          l.prototypeAllowAddVpn,
                          textAlign: TextAlign.center,
                          style: AppTypography.setupPermission.copyWith(
                            color: palette.mutedStrong,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : Column(
                children: [
                  _SetupRow(
                    icon: LucideIcons.shieldCheck,
                    title: l.prototypeVpnPermission,
                    description: l.prototypeAllowAddVpn,
                    trailing: Text(
                      status,
                      style: AppTypography.setupHint.copyWith(
                        color: state.authorized
                            ? palette.running
                            : palette.primary,
                      ),
                    ),
                    onTap: state.authorized
                        ? null
                        : _action(SetupAction.permission),
                  ),
                  if (requiresInterface)
                    _SetupRow(
                      icon: LucideIcons.network,
                      title: l.prototypeXrayOutboundInterface,
                      description: state.interfaceName.isEmpty
                          ? l.prototypeNotSelected
                          : state.interfaceName,
                      onTap: _action(SetupAction.chooseInterface),
                    ),
                ],
              ),
      ),
      if (requiresInterface) ...[
        const SizedBox(height: 14),
        Text(
          l.prototypeChooseInterfaceNotice,
          style: AppTypography.setupHint.copyWith(
            color: palette.mutedForeground,
          ),
        ),
      ],
      if (mobile && !requiresInterface) ...[
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.clock3, size: 16, color: palette.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                status,
                style: AppTypography.setupStatus.copyWith(
                  color: palette.mutedStrong,
                ),
              ),
            ),
          ],
        ),
      ],
      ..._feedback(context),
      const SizedBox(height: 56),
      Text(
        l.prototypeSetupDoesNotStartVpn,
        textAlign: TextAlign.center,
        style: AppTypography.setupSubtitle.copyWith(
          color: palette.mutedForeground,
        ),
      ),
    ];
  }

  List<Widget> _region(BuildContext context, bool mobile) {
    final l = AppLocalizations.of(context)!;
    return [
      ..._heading(
        context,
        mobile,
        l.prototypeWhereWillYouUse,
        l.prototypeRegionPurpose,
      ),
      const SizedBox(height: 28),
      _SetupRow(
        icon: LucideIcons.globe2,
        title: setupRegionLabel(l, state.region),
        outlined: true,
        onTap: _action(SetupAction.chooseRegion),
      ),
      const SizedBox(height: 14),
      Text(
        state.regionSuggested
            ? l.prototypeRegionSuggested
            : l.prototypeRegionSelectedManually,
        style: AppTypography.setupHint.copyWith(
          color: ColorManager.palette(context).mutedForeground,
        ),
      ),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          onPressed: _action(SetupAction.detectRegion),
          style: TextButton.styleFrom(
            textStyle: AppTypography.setupPrivacyLink,
          ),
          icon: const Icon(LucideIcons.locateFixed, size: 18),
          label: Text(l.prototypeDetect),
        ),
      ),
    ];
  }

  List<Widget> _servers(BuildContext context, bool mobile) {
    final l = AppLocalizations.of(context)!;
    final methods = [
      (ServerImportAction.paste, LucideIcons.link, l.prototypePasteLink),
      if (supportsScan)
        (ServerImportAction.scan, LucideIcons.qrCode, l.prototypeScanQrCode),
      (
        ServerImportAction.subscription,
        LucideIcons.link,
        l.prototypeAddSubscription,
      ),
      (ServerImportAction.file, LucideIcons.fileInput, l.prototypeImportFile),
      (
        ServerImportAction.json,
        LucideIcons.fileJson,
        l.prototypeAddJsonManually,
      ),
    ];
    return [
      ..._heading(
        context,
        mobile,
        l.prototypeAddServers,
        l.prototypeImportServersSubtitle,
      ),
      if (state.hasServers) ...[
        const SizedBox(height: 24),
        SetupPoint(
          icon: LucideIcons.circleCheck,
          text: l.prototypeServersReadyForHome,
        ),
      ],
      const SizedBox(height: 24),
      for (var index = 0; index < methods.length; index++) ...[
        if (index > 0) const SizedBox(height: 9),
        _SetupRow(
          icon: methods[index].$2,
          title: methods[index].$3,
          outlined: true,
          importMethod: true,
          onTap: state.busy ? null : () => onAddServer(methods[index].$1),
        ),
      ],
    ];
  }

  List<Widget> _feedback(BuildContext context) => [
    if (state.busy) ...[
      const SizedBox(height: 20),
      const LinearProgressIndicator(),
    ],
    if (failureText != null) ...[
      SetupError(text: failureText!),
      if (state.failure?.component != 'permission' &&
          state.failure?.component != 'region')
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: _action(SetupAction.retry),
            child: Text(AppLocalizations.of(context)!.prototypeRetry),
          ),
        ),
    ],
  ];

  VoidCallback? _action(SetupAction action) =>
      state.busy ? null : () => onAction(action);

  List<Widget> _actions(AppLocalizations l) => switch (state.step) {
    SetupStep.welcome => [
      SetupActionButton(
        label: l.prototypeAgreeAndContinue,
        onPressed: _action(SetupAction.acceptPrivacy),
      ),
    ],
    SetupStep.system => [
      SetupActionButton(
        label: l.prototypeBack,
        outline: true,
        onPressed: _action(SetupAction.back),
      ),
      SetupActionButton(
        label: state.authorized ? l.prototypeContinue : l.prototypeSetUpVpn,
        onPressed: state.authorized
            ? state.ready(requiresInterface: requiresInterface)
                  ? _action(SetupAction.continueSystem)
                  : null
            : _action(SetupAction.permission),
      ),
    ],
    SetupStep.region => [
      SetupActionButton(
        label: l.prototypeSkip,
        outline: true,
        onPressed: _action(SetupAction.skipRegion),
      ),
      SetupActionButton(
        label: l.prototypeConfirmAndContinue,
        onPressed: _action(SetupAction.confirmRegion),
      ),
    ],
    SetupStep.servers => [
      SetupActionButton(
        label: l.prototypeAddLater,
        outline: true,
        onPressed: _action(SetupAction.finish),
      ),
      SetupActionButton(
        label: l.prototypeGoToHome,
        onPressed: state.hasServers ? _action(SetupAction.finish) : null,
      ),
    ],
    SetupStep.complete => const [],
  };
}

class _SetupProgress extends StatelessWidget {
  const _SetupProgress({required this.step});
  final SetupStep step;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    final labels = [
      l.prototypeWelcomePrivacy,
      l.prototypeSystemSetup,
      l.prototypeYourRegion,
      l.prototypeAddServers,
    ];
    return Semantics(
      label: l.prototypeSetupProgress,
      child: Column(
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  '${labels[step.index]} ·',
                  style: AppTypography.setupProgress,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '${step.index + 1} / 4',
                textDirection: TextDirection.ltr,
                style: AppTypography.setupProgress,
              ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              for (var index = 0; index < 4; index++) ...[
                if (index > 0) const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: index <= step.index
                          ? palette.primary
                          : palette.border,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SetupRow extends StatelessWidget {
  const _SetupRow({
    required this.icon,
    required this.title,
    this.description,
    this.trailing,
    this.onTap,
    this.outlined = false,
    this.importMethod = false,
  });
  final IconData icon;
  final String title;
  final String? description;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool outlined;
  final bool importMethod;

  @override
  Widget build(BuildContext context) {
    final palette = ColorManager.palette(context);
    final radius = BorderRadius.circular(AppRadii.card);
    return Material(
      color: palette.card,
      shape: outlined
          ? RoundedRectangleBorder(
              borderRadius: radius,
              side: BorderSide(
                color: importMethod ? palette.border : palette.borderStrong,
              ),
            )
          : Border(bottom: BorderSide(color: palette.border)),
      child: InkWell(
        onTap: onTap,
        borderRadius: outlined ? radius : null,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: importMethod
                ? 56
                : outlined
                ? 62
                : 84,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: importMethod
                  ? 13
                  : outlined
                  ? 14
                  : 10,
              vertical: importMethod ? 12 : 16,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: importMethod ? 23 : 24,
                  color: palette.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: importMethod
                            ? AppTypography.setupImport
                            : AppTypography.setupRowTitle,
                      ),
                      if (description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          description!,
                          style: AppTypography.setupSelectorDetail,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                trailing ??
                    Icon(
                      LucideIcons.chevronRightDir,
                      size: 18,
                      color: palette.mutedStrong,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
