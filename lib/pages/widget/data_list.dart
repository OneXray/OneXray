import 'package:flutter/material.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

enum DataListRowTone { normal, selected, running }

class ListSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? hintText;
  final EdgeInsetsGeometry padding;

  const ListSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hintText,
    this.padding = const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          return ShadInput(
            controller: controller,
            placeholder: hintText == null ? null : Text(hintText!),
            leading: const Icon(LucideIcons.search, size: 16),
            trailing: value.text.isEmpty
                ? null
                : ShadIconButton.ghost(
                    icon: const Icon(LucideIcons.x),
                    width: 40,
                    height: 40,
                    iconSize: 15,
                    onPressed: () {
                      controller.clear();
                      onChanged("");
                    },
                  ),
            onChanged: onChanged,
          );
        },
      ),
    );
  }
}

class ListEmptyView extends StatelessWidget {
  final String message;
  final IconData? icon;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  const ListEmptyView({
    super.key,
    required this.message,
    this.icon,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 36, color: ColorManager.secondaryText(context)),
              const SizedBox(height: 12),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.rowValue.copyWith(
                color: ColorManager.secondaryText(context),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon ?? LucideIcons.plus),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class DataListInlineEmptyRow extends StatelessWidget {
  final String message;
  final IconData icon;

  const DataListInlineEmptyRow({
    super.key,
    required this.message,
    this.icon = LucideIcons.inbox,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ColorManager.surface(context),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: ColorManager.secondaryText(context)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.supporting.copyWith(
                  color: ColorManager.secondaryText(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DataListSectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const DataListSectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ColorManager.surface(context),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.listSectionTitle.copyWith(
                    color: ColorManager.primaryText(context),
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                IconTheme.merge(data: _iconTheme(context), child: trailing!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconThemeData _iconTheme(BuildContext context) {
    return IconThemeData(size: 20, color: ColorManager.secondaryText(context));
  }
}

class DataListRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? subtitleWidget;
  final Widget? leading;
  final List<Widget> tags;
  final Widget? meta;
  final Widget? trailing;
  final String? statusLabel;
  final IconData? statusIcon;
  final VoidCallback? onTap;
  final DataListRowTone tone;
  final int titleMaxLines;
  final int subtitleMaxLines;
  final double minHeight;
  final double verticalPadding;
  final double horizontalPadding;

  const DataListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    this.leading,
    this.tags = const [],
    this.meta,
    this.trailing,
    this.statusLabel,
    this.statusIcon,
    this.onTap,
    this.tone = DataListRowTone.normal,
    this.titleMaxLines = 1,
    this.subtitleMaxLines = 2,
    this.minHeight = 56,
    this.verticalPadding = 10,
    this.horizontalPadding = 16,
  });

  @override
  Widget build(BuildContext context) {
    final content = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: EdgeInsetsDirectional.symmetric(
          vertical: verticalPadding,
          horizontal: horizontalPadding,
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              Container(
                width: 31,
                height: 31,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ColorManager.tagBackground(context),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: IconTheme.merge(
                  data: _iconTheme(context),
                  child: leading!,
                ),
              ),
              const SizedBox(width: 11),
            ],
            Expanded(child: _mainContent(context)),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48),
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: IconTheme.merge(
                    data: _iconTheme(context),
                    child: trailing!,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
    return Material(
      color: _background(context),
      child: Stack(
        children: [
          if (tone != DataListRowTone.normal)
            PositionedDirectional(
              start: 0,
              top: 0,
              bottom: 0,
              child: ColoredBox(
                color: _accentColor(context),
                child: const SizedBox(width: 4),
              ),
            ),
          onTap == null
              ? content
              : InkWell(
                  onTap: onTap,
                  hoverColor: _hoverColor(context),
                  focusColor: _hoverColor(context),
                  mouseCursor: SystemMouseCursors.click,
                  child: content,
                ),
        ],
      ),
    );
  }

  Widget _mainContent(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: titleMaxLines,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.rowTitle.copyWith(
                  fontWeight: tone == DataListRowTone.normal
                      ? FontWeight.w500
                      : FontWeight.w600,
                  color: ColorManager.primaryText(context),
                ),
              ),
            ),
            if (statusLabel != null) ...[
              const SizedBox(width: 8),
              _statusBadge(context),
            ],
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            maxLines: subtitleMaxLines,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.supporting.copyWith(
              color: ColorManager.secondaryText(context),
            ),
          ),
        ] else if (subtitleWidget != null) ...[
          const SizedBox(height: 4),
          subtitleWidget!,
        ],
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 4),
          Wrap(spacing: 0, runSpacing: 4, children: tags),
        ],
        ?meta,
      ],
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
          if (statusIcon != null) ...[
            Icon(statusIcon, size: 12, color: _onAccentColor(context)),
            const SizedBox(width: 3),
          ],
          Text(
            statusLabel!,
            style: AppTypography.badge.copyWith(color: _onAccentColor(context)),
          ),
        ],
      ),
    );
  }

  Color _background(BuildContext context) {
    switch (tone) {
      case DataListRowTone.normal:
        return ColorManager.surface(context);
      case DataListRowTone.selected:
        return ColorManager.selected(context);
      case DataListRowTone.running:
        return ColorManager.running(context);
    }
  }

  Color _accentColor(BuildContext context) {
    switch (tone) {
      case DataListRowTone.normal:
      case DataListRowTone.selected:
        return Theme.of(context).colorScheme.primary;
      case DataListRowTone.running:
        return ColorManager.palette(context).runningBadge;
    }
  }

  Color _onAccentColor(BuildContext context) {
    switch (tone) {
      case DataListRowTone.normal:
      case DataListRowTone.selected:
        return Theme.of(context).colorScheme.onPrimary;
      case DataListRowTone.running:
        return ColorManager.palette(context).runningBadgeForeground;
    }
  }

  Color _hoverColor(BuildContext context) {
    return Theme.of(context).colorScheme.primary.withValues(alpha: 0.08);
  }

  IconThemeData _iconTheme(BuildContext context) {
    return IconThemeData(size: 20, color: ColorManager.secondaryText(context));
  }
}

class ActionCluster extends StatelessWidget {
  final List<Widget> children;

  const ActionCluster({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }
}
