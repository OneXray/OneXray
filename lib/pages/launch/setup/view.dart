import 'package:material_ui/material_ui.dart';
import 'package:onexray/gen/assets.gen.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/launch/setup/controller.dart';
import 'package:onexray/pages/launch/setup/selectors.dart';
import 'package:onexray/pages/launch/setup/widgets.dart';
import 'package:onexray/pages/shared/widgets/button_progress.dart';
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
    this.failureText,
    required this.onAction,
  });

  final SetupPageState state;
  final bool requiresInterface;
  final String? failureText;
  final ValueChanged<SetupAction> onAction;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final mobile =
        MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint;
    final welcome = state.step == SetupStep.welcome;
    final content = <Widget>[
      ...switch (state.step) {
        SetupStep.welcome => _welcome(context, mobile),
        SetupStep.configuration => _configuration(context, mobile),
        SetupStep.complete => const <Widget>[],
      },
      ..._feedback(context),
    ];
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: mobile
              ? SetupBody(
                  key: ValueKey(state.step),
                  top: welcome ? 32 : 24,
                  children: [
                    if (welcome) ...[
                      Text(
                        'OneXray',
                        textAlign: TextAlign.center,
                        style: AppTypography.setupBrand,
                      ),
                      const SizedBox(height: 36),
                    ],
                    if (!welcome && state.step != SetupStep.complete) ...[
                      _SetupProgress(step: state.step),
                      const SizedBox(height: 48),
                    ],
                    ...content,
                  ],
                )
              : SetupDesktopBody(
                  key: ValueKey(state.step),
                  progress: state.step == SetupStep.complete
                      ? const SizedBox.shrink()
                      : _SetupProgress(step: state.step),
                  bodyTop: welcome ? 46 : 48,
                  children: content,
                ),
        ),
        bottomNavigationBar: state.step == SetupStep.complete
            ? null
            : SetupFooter(
                note: !mobile && state.step == SetupStep.configuration
                    ? l.prototypeSetupDoesNotStartVpn
                    : null,
                children: _actions(l),
              ),
      ),
    );
  }

  List<Widget> _welcome(BuildContext context, bool mobile) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    return [
      Center(child: Assets.appIcon.blue.image(width: 96, height: 96)),
      SizedBox(height: mobile ? 26 : 24),
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
      SizedBox(height: mobile ? 36 : 34),
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
                SizedBox(height: mobile ? 24 : 20),
                SetupPoint(
                  icon: LucideIcons.userRound,
                  text: l.prototypeBringOwnServers,
                ),
              ],
            ),
          ),
        ),
      ),
      SizedBox(height: mobile ? 30 : 28),
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

  List<Widget> _configuration(BuildContext context, bool mobile) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    return [
      ..._heading(context, mobile, l.prototypeGetReadyToConnect),
      const SizedBox(height: 28),
      if (requiresInterface) ...[
        _SetupRow(
          icon: LucideIcons.network,
          title: l.prototypeXrayOutboundInterface,
          description: state.interfaceName.isEmpty
              ? l.prototypeNotSelected
              : state.interfaceName,
          busy: state.activeAction == SetupAction.chooseInterface,
          onTap: _action(SetupAction.chooseInterface),
        ),
        const SizedBox(height: 10),
        Text(
          l.prototypeInterfaceSelectionNotice,
          style: AppTypography.setupSkipNote.copyWith(
            color: palette.mutedForeground,
          ),
        ),
        const SizedBox(height: 24),
      ],
      _SetupRow(
        icon: LucideIcons.globe2,
        title: switch (state.regions) {
          null => l.prototypeChooseCountryRegion,
          [] => l.prototypeNoDirectRegions,
          [final code, ...] => setupRegionLabel(l, code),
        },
        description: l.prototypeRegionPurpose,
        busy: state.activeAction == SetupAction.chooseRegion,
        onTap: _action(SetupAction.chooseRegion),
      ),
      if (state.regions == null) ...[
        const SizedBox(height: 10),
        Text(
          l.prototypeRegionSkipNotice,
          style: AppTypography.setupSkipNote.copyWith(
            color: palette.mutedForeground,
          ),
        ),
      ],
    ];
  }

  List<Widget> _feedback(BuildContext context) => [
    if (state.busy && state.activeAction == null) ...[
      const SizedBox(height: 20),
      const LinearProgressIndicator(),
    ],
    if (failureText != null) ...[
      SetupError(text: failureText!),
      if (state.failure?.component != 'region')
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: _action(SetupAction.retry),
            child: ButtonProgress(
              busy: state.activeAction == SetupAction.retry,
              child: Text(AppLocalizations.of(context)!.prototypeRetry),
            ),
          ),
        ),
    ],
  ];

  VoidCallback? _action(SetupAction action) =>
      state.busy &&
          action != SetupAction.privacy &&
          (state.activeAction == null || state.activeAction == action)
      ? null
      : () => onAction(action);

  List<Widget> _actions(AppLocalizations l) => switch (state.step) {
    SetupStep.welcome => [
      SetupActionButton(
        label: l.prototypeAgreeAndContinue,
        busy: state.activeAction == SetupAction.acceptPrivacy,
        onPressed: _action(SetupAction.acceptPrivacy),
      ),
    ],
    SetupStep.configuration => [
      SetupActionButton(
        label: l.prototypeBack,
        outline: true,
        onPressed: _action(SetupAction.back),
      ),
      SetupActionButton(
        label: l.prototypeGoToHome,
        busy: state.activeAction == SetupAction.finish,
        onPressed: state.ready(requiresInterface: requiresInterface)
            ? _action(SetupAction.finish)
            : null,
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
    final labels = [l.prototypeWelcomePrivacy, l.prototypeSystemSetup];
    final mobile =
        MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint;
    return Semantics(
      label: l.prototypeSetupProgress,
      child: mobile
          ? Column(
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
                      '${step.index + 1} / ${labels.length}',
                      textDirection: TextDirection.ltr,
                      style: AppTypography.setupProgress,
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                Row(
                  children: [
                    for (var index = 0; index < labels.length; index++) ...[
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
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < labels.length; index++)
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: index == 0
                                  ? const SizedBox.shrink()
                                  : Divider(height: 1, color: palette.border),
                            ),
                            const SizedBox(width: 14),
                            Container(
                              width: 28,
                              height: 28,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: index <= step.index
                                    ? palette.primary
                                    : palette.card,
                                border: Border.all(
                                  color: index <= step.index
                                      ? palette.primary
                                      : palette.borderStrong,
                                ),
                              ),
                              child: index < step.index
                                  ? Icon(
                                      LucideIcons.check,
                                      size: 15,
                                      color: palette.primaryForeground,
                                    )
                                  : Text(
                                      '${index + 1}',
                                      style: AppTypography.setupStepActive
                                          .copyWith(
                                            color: index == step.index
                                                ? palette.primaryForeground
                                                : palette.mutedForeground,
                                          ),
                                    ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: index == labels.length - 1
                                  ? const SizedBox.shrink()
                                  : Divider(height: 1, color: palette.border),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          labels[index],
                          textAlign: TextAlign.center,
                          style:
                              (index == step.index
                                      ? AppTypography.setupStepActive
                                      : AppTypography.setupStepLabel)
                                  .copyWith(
                                    color: index == step.index
                                        ? palette.foreground
                                        : index < step.index
                                        ? palette.mutedStrong
                                        : palette.mutedForeground,
                                  ),
                        ),
                      ],
                    ),
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
    required this.description,
    this.onTap,
    this.busy = false,
  });
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final mobile =
        MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint;
    final palette = ColorManager.palette(context);
    final radius = BorderRadius.circular(AppRadii.card);
    return Material(
      color: palette.card,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: palette.borderStrong),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: mobile ? 62 : 68),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: mobile ? 16 : 18,
            ),
            child: Row(
              children: [
                if (busy)
                  const ButtonProgressIndicator()
                else
                  Icon(icon, size: mobile ? 24 : 26, color: palette.primary),
                SizedBox(width: mobile ? 12 : 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: mobile
                            ? AppTypography.setupRowTitle
                            : AppTypography.setupDesktopRowTitle,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: mobile
                            ? AppTypography.setupSelectorDetail
                            : AppTypography.setupDesktopRowDetail,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
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
