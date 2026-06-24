import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/db/dao/config_query.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/home/component/config_row/controller.dart';
import 'package:onexray/pages/home/component/config_row/enum.dart';
import 'package:onexray/pages/home/home/controller.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/service/db/config_reader.dart';
import 'package:onexray/service/event_bus/service.dart';

class SelectableConfigGridCard extends StatelessWidget {
  const SelectableConfigGridCard({super.key, required this.item});

  final ConfigItem item;

  @override
  Widget build(BuildContext context) {
    final data = item.config;
    final homeController = context.read<HomeController>();
    final selectedConfigId = context.select<HomeController, int>(
      (controller) => controller.state.configId,
    );
    final runningId = context.select<AppEventBus, int>(
      (eventBus) => eventBus.state.runningId,
    );
    final status = data.id == runningId
        ? ConfigRowStatus.running
        : data.id == selectedConfigId
        ? ConfigRowStatus.selected
        : ConfigRowStatus.unselected;
    return ConfigGridCard(
      data: data,
      status: status,
      moreMenus: [
        IconMenuId.edit,
        IconMenuId.share,
        IconMenuId.copy,
        IconMenuId.delete,
      ],
      tapCallback: () => homeController.updateConfigId(context, data.id),
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

  final CoreConfigData data;
  final ConfigRowStatus status;
  final List<IconMenuId> moreMenus;
  final VoidCallback? tapCallback;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadiusDirectional.circular(8);
    return Material(
      color: _background(context),
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: tapCallback,
        hoverColor: _hoverColor(context),
        focusColor: _hoverColor(context),
        mouseCursor: tapCallback == null
            ? MouseCursor.defer
            : SystemMouseCursors.click,
        child: Stack(
          children: [
            if (status != ConfigRowStatus.unselected)
              PositionedDirectional(
                start: 0,
                top: 0,
                bottom: 0,
                child: ColoredBox(
                  color: _accentColor(context),
                  child: const SizedBox(width: 4),
                ),
              ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  border: Border.all(color: ColorManager.border(context)),
                ),
                padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 8, 10),
                child: _content(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                data.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.2,
                  fontWeight: status == ConfigRowStatus.unselected
                      ? FontWeight.w600
                      : FontWeight.w800,
                  color: ColorManager.primaryText(context),
                ),
              ),
            ),
            if (moreMenus.isNotEmpty)
              SizedBox.square(
                dimension: 36,
                child: IconTheme.merge(
                  data: IconThemeData(
                    size: 20,
                    color: ColorManager.secondaryText(context),
                  ),
                  child: IconMenuPicker(
                    icon: Icons.more_vert,
                    menus: moreMenus,
                    callback: (menuId) =>
                        _controller.moreAction(context, data, menuId),
                  ),
                ),
              ),
          ],
        ),
        const Spacer(),
        if (_statusLabel(context) != null) ...[
          _statusBadge(context),
          const SizedBox(height: 6),
        ],
        _tagArea(context),
      ],
    );
  }

  Widget _tagArea(BuildContext context) {
    final labels = _tagLabels(context);
    return SizedBox(
      height: 42,
      child: Column(
        children: [
          _tagRow(context, labels[0]),
          const SizedBox(height: 4),
          _tagRow(context, labels[1]),
        ],
      ),
    );
  }

  Widget _tagRow(BuildContext context, String label) {
    return SizedBox(
      height: 19,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: _tagSlot(context, label),
      ),
    );
  }

  Widget _tagSlot(BuildContext context, String tag) {
    if (tag.isEmpty) {
      return const SizedBox.shrink();
    }
    return _compactTag(context, tag);
  }

  List<String> _tagLabels(BuildContext context) {
    final tags = data.readTags(context).take(2).toList();
    while (tags.length < 2) {
      tags.add("");
    }
    return tags;
  }

  Widget _compactTag(BuildContext context, String tag) {
    return Container(
      decoration: ShapeDecoration(
        color: ColorManager.tagBackground(context),
        shape: StadiumBorder(
          side: BorderSide(color: ColorManager.border(context), width: 1),
        ),
      ),
      padding: const EdgeInsetsDirectional.symmetric(
        vertical: 2,
        horizontal: 6,
      ),
      child: Text(
        tag,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          color: ColorManager.secondaryText(context),
        ),
      ),
    );
  }

  Widget _statusBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 6,
        vertical: 2,
      ),
      decoration: ShapeDecoration(
        color: _accentColor(context),
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon, size: 12, color: _onAccentColor(context)),
          const SizedBox(width: 3),
          Text(
            _statusLabel(context)!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: _onAccentColor(context),
            ),
          ),
        ],
      ),
    );
  }

  String? _statusLabel(BuildContext context) {
    switch (status) {
      case ConfigRowStatus.unselected:
        return null;
      case ConfigRowStatus.selected:
        return AppLocalizations.of(context)!.listStatusSelected;
      case ConfigRowStatus.running:
        return AppLocalizations.of(context)!.listStatusRunning;
    }
  }

  IconData get _statusIcon {
    switch (status) {
      case ConfigRowStatus.unselected:
        return Icons.circle_outlined;
      case ConfigRowStatus.selected:
        return Icons.check;
      case ConfigRowStatus.running:
        return Icons.radio_button_checked;
    }
  }

  Color _background(BuildContext context) {
    switch (status) {
      case ConfigRowStatus.unselected:
        return ColorManager.surface(context);
      case ConfigRowStatus.selected:
        return ColorManager.selected(context);
      case ConfigRowStatus.running:
        return ColorManager.running(context);
    }
  }

  Color _accentColor(BuildContext context) {
    switch (status) {
      case ConfigRowStatus.unselected:
      case ConfigRowStatus.selected:
        return Theme.of(context).colorScheme.primary;
      case ConfigRowStatus.running:
        return Theme.of(context).brightness == Brightness.light
            ? const Color(0xFF15803D)
            : const Color(0xFF86EFAC);
    }
  }

  Color _onAccentColor(BuildContext context) {
    switch (status) {
      case ConfigRowStatus.unselected:
      case ConfigRowStatus.selected:
        return Theme.of(context).colorScheme.onPrimary;
      case ConfigRowStatus.running:
        return Theme.of(context).brightness == Brightness.light
            ? Colors.white
            : const Color(0xFF052E16);
    }
  }

  Color _hoverColor(BuildContext context) {
    return Theme.of(context).colorScheme.primary.withValues(alpha: 0.08);
  }
}
