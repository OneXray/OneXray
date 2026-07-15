import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/db/dao/config_query.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/home/component/config_row/controller.dart';
import 'package:onexray/pages/home/component/config_row/enum.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/service/db/config_reader.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class SelectableConfigGridCard extends StatelessWidget {
  const SelectableConfigGridCard({
    super.key,
    required this.item,
    required this.onSelect,
    this.selectedId,
  });

  final ConfigItem item;
  final int? selectedId;
  final ValueChanged<CoreConfigData> onSelect;

  @override
  Widget build(BuildContext context) {
    final data = item.config;
    final runningId = context.select<AppEventBus, int>(
      (eventBus) => eventBus.state.runningId,
    );
    final status = data.id == runningId
        ? ConfigRowStatus.running
        : data.id == selectedId
        ? ConfigRowStatus.selected
        : ConfigRowStatus.unselected;
    return ConfigGridCard(
      data: data,
      status: status,
      moreMenus: const [
        IconMenuId.edit,
        IconMenuId.share,
        IconMenuId.copy,
        IconMenuId.delete,
      ],
      tapCallback: () => onSelect(data),
    );
  }
}

class ConfigGridCard extends StatelessWidget {
  const ConfigGridCard({
    super.key,
    required this.data,
    required this.status,
    required this.moreMenus,
    required this.tapCallback,
  });

  static final _controller = ConfigRowController();
  static double get mainAxisExtent => AppPlatform.isMobile ? 96 : 108;

  final CoreConfigData data;
  final ConfigRowStatus status;
  final List<IconMenuId> moreMenus;
  final VoidCallback? tapCallback;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(8);
    return ShadCard(
      width: double.infinity,
      height: double.infinity,
      padding: EdgeInsets.zero,
      radius: radius,
      backgroundColor: _background(context),
      border: ShadBorder.all(
        color: status == ConfigRowStatus.unselected
            ? ColorManager.border(context)
            : _borderAccentColor(context),
        width: status == ConfigRowStatus.unselected ? 1 : 1.5,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: tapCallback,
          hoverColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: 0.06),
          mouseCursor: tapCallback == null
              ? MouseCursor.defer
              : SystemMouseCursors.click,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 9, 8, 10),
            child: _content(context),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final detail = data.readConnectionDetail(context);
    final delay = data.readDelayLabel(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  ShadBadge.outline(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    child: Text(
                      data.readProtocolLabel(),
                      style: AppTypography.badge,
                    ),
                  ),
                  if (_statusLabel(context) case final label?) ...[
                    const SizedBox(width: 6),
                    Flexible(child: _statusBadge(context, label)),
                  ],
                ],
              ),
            ),
            if (moreMenus.isNotEmpty)
              AppMenuButton<IconMenuId>(
                triggerBuilder: (toggleMenu) => ShadIconButton.ghost(
                  icon: const Icon(LucideIcons.ellipsis),
                  width: 30,
                  height: 30,
                  iconSize: 17,
                  onPressed: toggleMenu,
                ),
                entries: iconMenuEntries(moreMenus),
                onSelected: (menuId) =>
                    _controller.moreAction(context, data, menuId),
              ),
          ],
        ),
        const SizedBox(height: 1),
        Text(
          data.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.sectionTitle.copyWith(
            color: ColorManager.primaryText(context),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                detail.isEmpty ? ' ' : detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.supporting.copyWith(
                  color: ColorManager.secondaryText(context),
                ),
              ),
            ),
            if (delay.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                delay,
                style: AppTypography.numeric.copyWith(
                  color: _delayColor(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _statusBadge(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 7,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: _accentColor(context).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.badge.copyWith(color: _accentColor(context)),
      ),
    );
  }

  String? _statusLabel(BuildContext context) {
    return switch (status) {
      ConfigRowStatus.unselected => null,
      ConfigRowStatus.selected => AppLocalizations.of(
        context,
      )!.listStatusSelected,
      ConfigRowStatus.running => AppLocalizations.of(
        context,
      )!.listStatusRunning,
    };
  }

  Color _background(BuildContext context) {
    return switch (status) {
      ConfigRowStatus.unselected => ColorManager.surface(context),
      ConfigRowStatus.selected => ColorManager.selected(context),
      ConfigRowStatus.running => ColorManager.running(context),
    };
  }

  Color _accentColor(BuildContext context) {
    return switch (status) {
      ConfigRowStatus.unselected ||
      ConfigRowStatus.selected => Theme.of(context).colorScheme.primary,
      ConfigRowStatus.running => ColorManager.palette(context).runningBadge,
    };
  }

  Color _borderAccentColor(BuildContext context) {
    return switch (status) {
      ConfigRowStatus.unselected ||
      ConfigRowStatus.selected => Theme.of(context).colorScheme.primary,
      ConfigRowStatus.running => ColorManager.palette(context).running,
    };
  }

  Color _delayColor(BuildContext context) {
    if (data.delay > 0 && data.delay < 1000) {
      return ColorManager.palette(context).runningText;
    }
    return ColorManager.secondaryText(context);
  }
}
