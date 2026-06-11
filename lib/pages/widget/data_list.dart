import 'package:flutter/material.dart';
import 'package:onexray/pages/theme/color.dart';

enum DataListRowTone { normal, selected, running }

class ListSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? hintText;

  const ListSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          return TextField(
            controller: controller,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              suffixIcon: value.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        controller.clear();
                        onChanged("");
                      },
                      icon: const Icon(Icons.close),
                    ),
              hintText: hintText,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              filled: true,
              isDense: true,
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
              style: TextStyle(
                fontSize: 14,
                color: ColorManager.secondaryText(context),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon ?? Icons.add),
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
    this.icon = Icons.inbox_outlined,
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
                style: TextStyle(
                  fontSize: 13,
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
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
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
  final List<Widget> tags;
  final Widget? meta;
  final Widget? trailing;
  final String? statusLabel;
  final IconData? statusIcon;
  final VoidCallback? onTap;
  final DataListRowTone tone;
  final int titleMaxLines;
  final int subtitleMaxLines;

  const DataListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    this.tags = const [],
    this.meta,
    this.trailing,
    this.statusLabel,
    this.statusIcon,
    this.onTap,
    this.tone = DataListRowTone.normal,
    this.titleMaxLines = 1,
    this.subtitleMaxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          vertical: 10,
          horizontal: 16,
        ),
        child: Row(
          children: [
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
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: tone == DataListRowTone.normal
                      ? FontWeight.normal
                      : FontWeight.bold,
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
            style: TextStyle(
              fontSize: 13,
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
        return Theme.of(context).brightness == Brightness.light
            ? const Color(0xFF15803D)
            : const Color(0xFF86EFAC);
    }
  }

  Color _onAccentColor(BuildContext context) {
    switch (tone) {
      case DataListRowTone.normal:
      case DataListRowTone.selected:
        return Theme.of(context).colorScheme.onPrimary;
      case DataListRowTone.running:
        return Theme.of(context).brightness == Brightness.light
            ? Colors.white
            : const Color(0xFF052E16);
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
