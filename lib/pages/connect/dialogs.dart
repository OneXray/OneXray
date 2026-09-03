import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/pages/widget/adaptive_dialog.dart';
import 'package:onexray/service/connection/settings.dart';

Future<T?> showConnectDialog<T>(BuildContext context, WidgetBuilder builder) =>
    showAppDialog<T>(context, builder);

typedef ConnectDialog = AppDialog;

class ConnectDialogButton extends StatelessWidget {
  const ConnectDialogButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.secondary = false,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool secondary;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final palette = ColorManager.palette(context);
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 16), const SizedBox(width: 8)],
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    );
    if (secondary) {
      return OutlinedButton(
        onPressed: onPressed,
        style: ButtonStyle(
          side: WidgetStatePropertyAll(BorderSide(color: palette.borderStrong)),
        ),
        child: child,
      );
    }
    return FilledButton(
      onPressed: onPressed,
      style: destructive ? AppTheme.destructiveButton(context) : null,
      child: child,
    );
  }
}

class ConnectCallout extends StatelessWidget {
  const ConnectCallout({
    super.key,
    required this.icon,
    required this.text,
    this.warning = false,
  });
  final IconData icon;
  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final palette = ColorManager.palette(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: warning ? palette.destructiveSurface : palette.muted,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadii.card)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: icon == LucideIcons.lockKeyhole ? 17 : 21,
            color: warning ? palette.destructive : palette.primary,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              text,
              style: AppTypography.dialogCallout.copyWith(
                color: warning ? palette.destructive : palette.mutedStrong,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

typedef ConnectTrafficChoice = ({TrafficMode mode, int? id, bool edit});
typedef ConnectCustomChoice = ({int id, String name, int? ruleCount});

class ConnectTrafficMethodDialog extends StatelessWidget {
  const ConnectTrafficMethodDialog({
    super.key,
    required this.current,
    required this.customRoutes,
  });
  final ConnectionSettings current;
  final List<ConnectCustomChoice> customRoutes;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    void choose(TrafficMode mode, int? id, {bool edit = false}) =>
        Navigator.of(context).pop((mode: mode, id: id, edit: edit));
    final mobile =
        MediaQuery.sizeOf(context).width < AppLayout.mobileBreakpoint;
    return ConnectDialog(
      title: l.prototypeChooseTrafficMethod,
      subtitle: l.prototypeTrafficMethodQuestion,
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          mobile ? 14 : 20,
          18,
          mobile ? 14 : 20,
          20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MethodOption(
              title: l.prototypeSmartRoutingRecommended,
              description: l.prototypeSmartRoutingDescription,
              selected: current.trafficMode == TrafficMode.smart,
              onPressed: () => choose(TrafficMode.smart, null),
              onEdit: () => choose(TrafficMode.smart, null, edit: true),
            ),
            const SizedBox(height: 10),
            _MethodOption(
              title: l.prototypeAllViaVpn,
              description: l.prototypeAllViaVpnDescription,
              selected: current.trafficMode == TrafficMode.allVpn,
              onPressed: () => choose(TrafficMode.allVpn, null),
            ),
            const SizedBox(height: 19),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.prototypeCustomRouting,
                          style: AppTypography.dialogGroupTitle,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          l.prototypeChooseNamedRoute,
                          style: AppTypography.dialogGroupMeta.copyWith(
                            color: palette.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${customRoutes.length}/3',
                    textDirection: TextDirection.ltr,
                    style: AppTypography.dialogGroupMeta.copyWith(
                      color: palette.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            for (final route in customRoutes) ...[
              const SizedBox(height: 10),
              _MethodOption(
                title: route.name,
                description: route.ruleCount == null
                    ? l.prototypeCannotReadCustomRoute
                    : l.prototypeRuleCount(route.ruleCount!),
                selected:
                    current.trafficMode == TrafficMode.custom &&
                    current.customId == route.id,
                onPressed: () => choose(TrafficMode.custom, route.id),
                onEdit: () => choose(TrafficMode.custom, route.id, edit: true),
              ),
            ],
            if (customRoutes.isEmpty || customRoutes.length >= 3)
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 20, 2, 10),
                child: Text(
                  customRoutes.isEmpty
                      ? l.prototypeNoCustomRoutes
                      : l.prototypeCustomRouteLimit,
                  style: AppTypography.dialogGroupMeta.copyWith(
                    color: palette.mutedForeground,
                  ),
                ),
              ),
            if (customRoutes.length < 3) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => choose(TrafficMode.custom, null, edit: true),
                style: OutlinedButton.styleFrom(
                  foregroundColor: palette.primary,
                  textStyle: AppTypography.dialogAddAction,
                  minimumSize: const Size.fromHeight(42),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  side: BorderSide(color: palette.borderStrong),
                  shape: AppDashedBorder(
                    borderRadius: const BorderRadius.all(
                      Radius.circular(AppRadii.card),
                    ),
                  ),
                ),
                icon: const Icon(LucideIcons.plus, size: 17),
                label: Text(l.prototypeNewCustomRoute),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MethodOption extends StatelessWidget {
  const _MethodOption({
    required this.title,
    required this.description,
    required this.selected,
    required this.onPressed,
    this.onEdit,
  });
  final String title, description;
  final bool selected;
  final VoidCallback onPressed;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final palette = ColorManager.palette(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 82),
      decoration: BoxDecoration(
        color: selected ? palette.selectedSurface : palette.card,
        border: Border.all(
          color: selected
              ? Color.lerp(palette.border, palette.primary, 0.48)!
              : palette.border,
        ),
        borderRadius: const BorderRadius.all(Radius.circular(AppRadii.card)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              selected: selected,
              child: TextButton(
                onPressed: onPressed,
                style: TextButton.styleFrom(
                  foregroundColor: palette.foreground,
                  minimumSize: const Size(0, 80),
                  padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 0, 12),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: palette.selectedSurface,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        LucideIcons.shieldCheck,
                        size: 21,
                        color: palette.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: AppTypography.dialogOptionTitle),
                          const SizedBox(height: 4),
                          Text(
                            description,
                            style: AppTypography.dialogOptionDescription
                                .copyWith(color: palette.mutedForeground),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          if (onEdit != null) ...[
            TextButton(
              onPressed: onEdit,
              style: TextButton.styleFrom(
                foregroundColor: palette.primary,
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: AppTypography.dialogOptionEdit,
              ),
              child: Text(AppLocalizations.of(context)!.prototypeEdit),
            ),
            const SizedBox(width: 10),
          ],
          Icon(
            selected ? LucideIcons.circleCheck : LucideIcons.arrowRightDir,
            size: selected ? 21 : 18,
            color: selected ? palette.running : palette.foreground,
          ),
          const SizedBox(width: 14),
        ],
      ),
    );
  }
}

class ConnectExplanation extends StatelessWidget {
  const ConnectExplanation({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 22, color: ColorManager.palette(context).primary),
      const SizedBox(width: 12),
      Expanded(child: Text(text, style: AppTypography.dialogBody)),
    ],
  );
}
