import 'package:flutter/material.dart';
import 'package:onexray/pages/widget/button_progress.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/routing/checker.dart';
import 'package:onexray/pages/routing/custom/controller.dart';
import 'package:onexray/pages/routing/widgets.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/pages/widget/configuration_transfer.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/pages/widget/page_action_bar.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
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
                      12,
                      mobile ? 14 : 28,
                      18,
                    ),
                    child: ResponsiveContent(
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
                              spacing: 8,
                              children: [
                                widget.transferTools?.call(
                                      context,
                                      controller,
                                    ) ??
                                    ConfigurationTransferTools(
                                      controller: controller.transfer,
                                      disabled: controller.busy,
                                    ),
                                Text(
                                  l.prototypeCustomImportHint,
                                  style: AppTypography.actionHelp.copyWith(
                                    color: ColorManager.palette(context)
                                        .mutedForeground,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _identity(context, mobile),
                          const SizedBox(height: 12),
                          RoutingCard(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: mobile
                                    ? (constraints.maxHeight > 26
                                          ? constraints.maxHeight - 26
                                          : 0)
                                    : 0,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (!mobile)
                                    RoutingCardHeader(
                                      title: l.prototypeRuleList,
                                      description: l.prototypeRulesMatchInOrder,
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
                                        _rule(context, index),
                                  ),
                                  _fallback(context),
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
                                        minimumSize: const Size.fromHeight(43),
                                        foregroundColor: ColorManager.palette(
                                          context,
                                        ).primary,
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
                                          _dns(context),
                                          if (controller.previewTemplate
                                              case final template?)
                                            RouteChecker(
                                              configuration:
                                                  controller.checkConfiguration,
                                              customDraft: template,
                                              prepareAssets: controller
                                                  .transfer
                                                  .pending
                                                  ?.copyFilesTo,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
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

  Widget _rule(BuildContext context, int index) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    final selected = controller.selectedRuleKey == controller.ruleKeys[index];
    final action = controller.rules[index]['outboundTag'];
    final actionColor = action == 'direct'
        ? palette.running
        : action == 'block'
        ? palette.destructive
        : palette.primary;
    final position = l.prototypeChangeRulePosition(
      controller.ruleName(index, l),
    );
    return Container(
      key: ObjectKey(controller.ruleKeys[index]),
      constraints: const BoxConstraints(minHeight: 72),
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
      padding: const EdgeInsets.symmetric(horizontal: 7),
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
            width: 18,
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
                constraints: const BoxConstraints(minHeight: 70),
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
                              style: AppTypography.ruleTitleMobile,
                            ),
                            Text(
                              controller.ruleSummary(index, l),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.ruleSummary.copyWith(
                                color: palette.mutedForeground,
                              ),
                            ),
                            Text(
                              controller.ruleAction(index, l),
                              style: AppTypography.ruleAction.copyWith(
                                color: actionColor,
                              ),
                            ),
                          ],
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

  Widget _fallback(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 62),
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
                Text(l.prototypeOtherTraffic, style: AppTypography.ruleAdd),
                Text(
                  l.prototypeWhenNoRuleMatches,
                  style: AppTypography.conditionRelation.copyWith(
                    color: palette.mutedForeground,
                  ),
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

  Widget _dns(BuildContext context) {
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
                Text(l.dnsPageTitle, style: AppTypography.ruleAdd),
                Text(
                  l.prototypeAutomaticFollowsEachRule,
                  style: AppTypography.conditionRelation.copyWith(
                    color: palette.mutedForeground,
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
