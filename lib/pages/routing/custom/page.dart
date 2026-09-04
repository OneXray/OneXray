import 'package:flutter/material.dart';
import 'package:onexray/pages/widget/button_progress.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/routing/checker.dart';
import 'package:onexray/pages/routing/custom/controller.dart';
import 'package:onexray/pages/routing/custom/rule_page.dart';
import 'package:onexray/pages/routing/widgets.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/pages/widget/configuration_transfer.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/pages/widget/page_action_bar.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/service/routing/state.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class CustomRoutingEditorPage extends StatefulWidget {
  final int? profileId;
  final String? initialText;
  final String? initialName;
  final OpenCustomRule openRule;
  final Widget Function(BuildContext, CustomRoutingEditorController)?
  transferTools;
  const CustomRoutingEditorPage({
    super.key,
    this.profileId,
    this.initialText,
    this.initialName,
    required this.openRule,
    this.transferTools,
  });

  @override
  State<CustomRoutingEditorPage> createState() =>
      _CustomRoutingEditorPageState();
}

class _CustomRoutingEditorPageState extends State<CustomRoutingEditorPage> {
  late final controller = CustomRoutingEditorController(
    profileId: widget.profileId,
    initialText: widget.initialText,
    initialName: widget.initialName,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    controller.setInlineEditing(
      MediaQuery.sizeOf(context).width > AppLayout.mobileBreakpoint,
    );
    if (!_started) {
      _started = true;
      controller.load(context);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final l = AppLocalizations.of(context)!;
      final mobile =
          MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint;
      final name = controller.name.text.trim();
      return Scaffold(
        appBar: AppBar(
          title: Text(name.isEmpty ? l.prototypeCustomRouting : name),
          leading: BackButton(onPressed: () => controller.close(context)),
        ),
        body: SafeArea(
          child: controller.loaded
              ? LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      mobile ? 14 : 28,
                      mobile ? 12 : AppSpacing.desktopPageTop,
                      mobile ? 14 : 28,
                      mobile ? 18 : AppSpacing.desktopPageBottom,
                    ),
                    child: ResponsiveContent(
                      desktopMaxWidth: AppLayout.routingMaxWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          RoutingCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 13,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              spacing: mobile ? 8 : 0,
                              children: [
                                widget.transferTools?.call(
                                      context,
                                      controller,
                                    ) ??
                                    ConfigurationTransferTools(
                                      controller: controller.transfer,
                                      disabled: controller.busy,
                                    ),
                                Padding(
                                  padding: mobile
                                      ? EdgeInsets.zero
                                      : const EdgeInsets.fromLTRB(
                                          22,
                                          10,
                                          22,
                                          0,
                                        ),
                                  child: Text(
                                    l.prototypeCustomImportHint,
                                    style:
                                        (mobile
                                                ? AppTypography.actionHelp
                                                : AppTypography.shareHint)
                                            .copyWith(
                                              color: ColorManager.palette(
                                                context,
                                              ).mutedForeground,
                                            ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _identity(context, mobile),
                          SizedBox(height: mobile ? 12 : 16),
                          LayoutBuilder(
                            builder: (context, layout) {
                              final list = RoutingCard(
                                key: const ValueKey('custom-rule-list'),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: mobile
                                        ? (constraints.maxHeight > 26
                                              ? constraints.maxHeight - 26
                                              : 0)
                                        : 0,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (!mobile)
                                        RoutingCardHeader(
                                          title: l.prototypeRuleList,
                                          description:
                                              l.prototypeRulesMatchInOrder,
                                        ),
                                      RoutingEntryCountRow(
                                        value: controller.entryCount,
                                        onChanged: controller.editingBlocked
                                            ? null
                                            : controller.setEntryCount,
                                      ),
                                      ReorderableListView.builder(
                                        shrinkWrap: true,
                                        primary: false,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        padding: EdgeInsets.zero,
                                        buildDefaultDragHandles: false,
                                        onReorderItem: controller.reorder,
                                        itemCount: controller.rules.length,
                                        itemBuilder: (context, index) =>
                                            _rule(context, index, mobile),
                                      ),
                                      _fallback(context, mobile),
                                      Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: OutlinedButton.icon(
                                          onPressed: controller.editingBlocked
                                              ? null
                                              : () => controller.editRule(
                                                  context,
                                                  widget.openRule,
                                                ),
                                          style: OutlinedButton.styleFrom(
                                            minimumSize: const Size.fromHeight(
                                              43,
                                            ),
                                            visualDensity: mobile
                                                ? null
                                                : VisualDensity.standard,
                                            foregroundColor:
                                                ColorManager.palette(context)
                                                    .primary,
                                            side: BorderSide(
                                              color: Color.lerp(
                                                ColorManager.palette(context)
                                                    .border,
                                                ColorManager.palette(context)
                                                    .primary,
                                                .55,
                                              )!,
                                            ),
                                            textStyle: AppTypography.ruleAdd,
                                          ),
                                          icon: const Icon(
                                            LucideIcons.plus,
                                            size: 17,
                                          ),
                                          label: Text(l.prototypeAddRule),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          12,
                                          0,
                                          12,
                                          12,
                                        ),
                                        child: RoutingCard(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              _dns(context, mobile),
                                              if (controller.previewState
                                                  case final profile?)
                                                RouteChecker(
                                                  configuration: controller
                                                      .checkConfiguration,
                                                  customDraft: profile,
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                              if (mobile) return list;
                              final inline = controller.inlineRule;
                              final editor = inline == null
                                  ? null
                                  : CustomRoutingRuleForm(controller: inline);
                              if (layout.maxWidth < 876) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  spacing: 16,
                                  children: [list, ?editor],
                                );
                              }
                              final available = layout.maxWidth - 16;
                              final left = (available * .46).clamp(
                                390.0,
                                available - 470,
                              );
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(width: left, child: list),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: editor ?? const SizedBox.shrink(),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : Center(
                  child: controller.busy
                      ? const CircularProgressIndicator()
                      : Text(l.prototypeCannotReadCustomRoute),
                ),
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (controller.error case final error?)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    error,
                    style: AppTypography.actionHelp.copyWith(
                      color: ColorManager.palette(context).destructive,
                    ),
                  ),
                ),
              ),
            PageActionBar(
              children: [
                if (!mobile)
                  ShadButton.outline(
                    onPressed: () => controller.close(context),
                    child: Text(l.prototypeCancel),
                  ),
                ShadButton(
                  enabled:
                      !controller.busy &&
                      controller.loaded &&
                      controller.nameError(l) == null,
                  onPressed:
                      controller.busy ||
                          !controller.loaded ||
                          controller.nameError(l) != null
                      ? null
                      : () => controller.save(context),
                  child: ButtonProgress(
                    busy: controller.saving,
                    child: Text(l.prototypeSave),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );

  Widget _identity(BuildContext context, bool mobile) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    final error = controller.nameError(l);
    final field = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        Text(
          l.prototypeRouteName,
          style: AppTypography.routeIdentityLabel.copyWith(
            color: palette.mutedStrong,
          ),
        ),
        ShadInput(
          controller: controller.name,
          enabled: controller.loaded,
          maxLength: 32,
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          style: AppTypography.routeIdentityLabel,
          decoration: error == null
              ? null
              : ShadDecoration(
                  border: ShadBorder.all(color: palette.destructive, width: 1),
                ),
        ),
        if (error != null)
          Text(
            error,
            style: AppTypography.conditionRelation.copyWith(
              color: palette.destructive,
            ),
          ),
      ],
    );
    final delete = OutlinedButton.icon(
      onPressed: controller.busy ? null : () => controller.delete(context),
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.destructive,
        minimumSize: const Size(0, 38),
        visualDensity: mobile ? null : VisualDensity.standard,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        textStyle: AppTypography.ruleAdd,
      ),
      icon: controller.deleting
          ? const ButtonProgressIndicator()
          : const Icon(LucideIcons.trash2, size: 16),
      label: Text(l.prototypeDeleteRoute),
    );
    return RoutingCard(
      padding: mobile
          ? const EdgeInsets.all(12)
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Row(
            spacing: mobile ? 10 : 16,
            children: [
              Expanded(child: field),
              Flexible(
                flex: 0,
                child: Text(
                  l.prototypeCustomRouteCount(controller.routeCount),
                  style: AppTypography.routeCount.copyWith(
                    color: palette.mutedForeground,
                  ),
                ),
              ),
              if (!mobile && controller.original?.original != null) delete,
            ],
          ),
          if (mobile && controller.original?.original != null) delete,
        ],
      ),
    );
  }

  Widget _rule(BuildContext context, int index, bool mobile) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    final selected = controller.selectedRuleKey == controller.ruleKeys[index];
    final action = controller.rules[index].action;
    final actionColor = action == RoutingRuleAction.direct
        ? palette.running
        : action == RoutingRuleAction.block
        ? palette.destructive
        : palette.primary;
    final position = l.prototypeChangeRulePosition(
      controller.ruleName(index, l),
    );
    return Container(
      key: ObjectKey(controller.ruleKeys[index]),
      constraints: BoxConstraints(minHeight: mobile ? 72 : 68),
      decoration: BoxDecoration(
        color: selected ? palette.selectedSurface : palette.card,
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      foregroundDecoration: selected
          ? BoxDecoration(
              border: Border.all(
                color: Color.lerp(palette.border, palette.primary, .58)!,
              ),
            )
          : null,
      padding: EdgeInsets.symmetric(horizontal: mobile ? 7 : 10),
      child: Row(
        spacing: 8,
        children: [
          AppMenuButton<int>(
            entries: [
              for (var target = 0; target < controller.rules.length; target++)
                AppMenuEntry.item(
                  value: target,
                  title: l.prototypeRulePosition(target + 1),
                ),
            ],
            onSelected: (target) => controller.reorder(index, target),
            triggerBuilder: (open) => ReorderableDelayedDragStartListener(
              index: index,
              enabled: !controller.editingBlocked,
              child: Tooltip(
                message: position,
                child: IconButton(
                  onPressed: controller.editingBlocked ? null : open,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(28, 36),
                    maximumSize: const Size(28, 36),
                    padding: EdgeInsets.zero,
                    foregroundColor: palette.mutedForeground,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(LucideIcons.gripVertical, size: 17),
                ),
              ),
            ),
          ),
          SizedBox(
            width: mobile ? 18 : 20,
            child: Text(
              (index + 1).toString(),
              textAlign: TextAlign.center,
              style: AppTypography.ruleNumber.copyWith(
                color: palette.mutedStrong,
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: controller.editingBlocked
                  ? null
                  : () => controller.editRule(context, widget.openRule, index),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: mobile ? 70 : 66),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    spacing: 8,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: 4,
                          children: [
                            Text(
                              controller.ruleName(index, l),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: mobile
                                  ? AppTypography.ruleTitleMobile
                                  : AppTypography.ruleTitleDesktop,
                            ),
                            Text(
                              controller.ruleSummary(index, l),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  (mobile
                                          ? AppTypography.ruleSummary
                                          : AppTypography.ruleSummaryDesktop)
                                      .copyWith(color: palette.mutedForeground),
                            ),
                            if (mobile)
                              Text(
                                controller.ruleAction(index, l),
                                style: AppTypography.ruleAction.copyWith(
                                  color: actionColor,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (!mobile)
                        Text(
                          controller.ruleAction(index, l),
                          style: AppTypography.ruleAction.copyWith(
                            color: actionColor,
                          ),
                        ),
                      Icon(
                        LucideIcons.chevronRightDir,
                        size: 17,
                        color: palette.foreground,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: l.prototypeDelete,
            onPressed: controller.editingBlocked
                ? null
                : () => controller.deleteRule(index),
            style: IconButton.styleFrom(
              minimumSize: const Size.square(34),
              maximumSize: const Size.square(34),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: palette.mutedForeground,
            ),
            icon: const Icon(LucideIcons.trash2, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _fallback(BuildContext context, bool mobile) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    return Container(
      constraints: BoxConstraints(minHeight: mobile ? 62 : 61),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        spacing: 10,
        children: [
          Icon(LucideIcons.globe, size: 19, color: palette.mutedStrong),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 3,
              children: [
                Text(
                  l.prototypeOtherTraffic,
                  style: mobile
                      ? AppTypography.ruleAdd
                      : AppTypography.routingSelectionTitle,
                ),
                Text(
                  l.prototypeWhenNoRuleMatches,
                  style:
                      (mobile
                              ? AppTypography.conditionRelation
                              : AppTypography.ruleSummaryDesktop)
                          .copyWith(color: palette.mutedForeground),
                ),
              ],
            ),
          ),
          Text(
            l.prototypeUseVpn,
            style: AppTypography.ruleAction.copyWith(color: palette.primary),
          ),
        ],
      ),
    );
  }

  Widget _dns(BuildContext context, bool mobile) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      child: Row(
        spacing: 10,
        children: [
          Icon(LucideIcons.globe, size: 18, color: palette.primary),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 3,
              children: [
                Text(
                  l.dnsPageTitle,
                  style: mobile
                      ? AppTypography.ruleAdd
                      : AppTypography.routingSelectionTitle,
                ),
                Text(
                  l.prototypeAutomaticFollowsEachRule,
                  style:
                      (mobile
                              ? AppTypography.conditionRelation
                              : AppTypography.ruleSummaryDesktop)
                          .copyWith(color: palette.mutedForeground),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
