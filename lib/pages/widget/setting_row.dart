import 'package:flutter/material.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/pages/widget/section.dart';

class SettingSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final bool separated;

  const SettingSection({
    super.key,
    required this.title,
    required this.children,
    this.separated = true,
  });

  @override
  Widget build(BuildContext context) {
    return SectionView(
      title: title,
      child: Column(
        children: _buildSettingChildren(context, children, separated),
      ),
    );
  }
}

class SettingSubsection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final bool separated;

  const SettingSubsection({
    super.key,
    required this.title,
    required this.children,
    this.separated = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 4),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: ColorManager.sectionTitle(context),
              ),
            ),
          ),
        ..._buildSettingChildren(context, children, separated),
      ],
    );
  }
}

List<Widget> _buildSettingChildren(
  BuildContext context,
  List<Widget> children,
  bool separated,
) {
  if (!separated || children.length < 2) {
    return children;
  }
  final views = <Widget>[];
  for (var i = 0; i < children.length; i++) {
    if (i > 0) {
      views.add(
        Divider(height: 1, indent: 16, color: ColorManager.border(context)),
      );
    }
    views.add(children[i]);
  }
  return views;
}

class SettingRow extends StatelessWidget {
  final String title;
  final String? value;
  final String? subtitle;
  final Widget? subtitleWidget;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;
  final bool showChevron;
  final int titleMaxLines;
  final int valueMaxLines;

  const SettingRow({
    super.key,
    required this.title,
    this.value,
    this.subtitle,
    this.subtitleWidget,
    this.leading,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.showChevron = false,
    this.titleMaxLines = 2,
    this.valueMaxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              IconTheme.merge(data: _iconTheme(context), child: leading!),
              const SizedBox(width: 12),
            ],
            Expanded(flex: value == null ? 1 : 5, child: _title(context)),
            if (value != null) ...[
              const SizedBox(width: 12),
              Expanded(flex: 4, child: _value(context)),
            ],
            if (trailing != null) ...[
              const SizedBox(width: 8),
              IconTheme.merge(data: _iconTheme(context), child: trailing!),
            ] else if (showChevron) ...[
              const SizedBox(width: 8),
              IconTheme.merge(
                data: _iconTheme(context),
                child: const Icon(Icons.chevron_right),
              ),
            ],
          ],
        ),
      ),
    );
    if (onTap == null || !enabled) {
      return content;
    }
    return Material(
      type: MaterialType.transparency,
      child: InkWell(onTap: onTap, child: content),
    );
  }

  Widget _title(BuildContext context) {
    final color = enabled
        ? ColorManager.primaryText(context)
        : Theme.of(context).disabledColor;
    final titleStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(fontSize: 14, color: color);
    final subtitleStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: ColorManager.secondaryText(context));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: titleMaxLines,
          overflow: TextOverflow.ellipsis,
          style: titleStyle,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: subtitleStyle,
          ),
        ] else if (subtitleWidget != null) ...[
          const SizedBox(height: 4),
          subtitleWidget!,
        ],
      ],
    );
  }

  Widget _value(BuildContext context) {
    return Text(
      value!,
      maxLines: valueMaxLines,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.end,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontSize: 14,
        color: ColorManager.secondaryText(context),
      ),
    );
  }

  IconThemeData _iconTheme(BuildContext context) {
    return IconThemeData(size: 20, color: ColorManager.secondaryText(context));
  }
}

class ReorderDragHandle extends StatelessWidget {
  final int index;
  final String tooltip;

  const ReorderDragHandle({
    super.key,
    required this.index,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return ReorderableDragStartListener(
      index: index,
      child: Tooltip(
        message: tooltip,
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: SizedBox(
            width: 40,
            height: 48,
            child: Icon(Icons.drag_handle, size: 20),
          ),
        ),
      ),
    );
  }
}

class SwitchSettingRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const SwitchSettingRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SettingRow(
      title: title,
      subtitle: subtitle,
      enabled: onChanged != null,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}

class CheckboxSettingRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool?>? onChanged;

  const CheckboxSettingRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SettingRow(
      title: title,
      subtitle: subtitle,
      enabled: onChanged != null,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      trailing: Checkbox(value: value, onChanged: onChanged),
    );
  }
}

class SelectSettingRow<T extends Object> extends StatelessWidget {
  final String title;
  final String value;
  final List<T> selections;
  final TextSelectCallback<T> onSelected;

  const SelectSettingRow({
    super.key,
    required this.title,
    required this.value,
    required this.selections,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SettingRow(
      title: title,
      trailing: TextMenuPicker<T>(
        title: value,
        selections: selections,
        callback: onSelected,
      ),
    );
  }
}

class SliderSettingRow extends StatelessWidget {
  final String title;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String? label;
  final ValueChanged<double>? onChanged;

  const SliderSettingRow({
    super.key,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 16),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  color: ColorManager.primaryText(context),
                ),
              ),
            ),
            Expanded(
              flex: 5,
              child: Slider(
                min: min,
                max: max,
                divisions: divisions,
                label: label,
                value: value,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TextFieldSettingRow extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hintText;
  final String? helperText;
  final TextInputType? keyboardType;
  final int? maxLines;
  final bool enabled;

  const TextFieldSettingRow({
    super.key,
    required this.controller,
    required this.label,
    this.hintText,
    this.helperText,
    this.keyboardType,
    this.maxLines = 1,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 16,
        vertical: 6,
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        enabled: enabled,
        decoration: InputDecoration(
          label: Text(label),
          hintText: hintText,
          helperText: helperText,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
        ),
      ),
    );
  }
}

class TextFieldActionSettingRow extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hintText;
  final TextInputType? keyboardType;
  final int? maxLines;
  final bool enabled;
  final Widget trailing;

  const TextFieldActionSettingRow({
    super.key,
    required this.controller,
    required this.label,
    this.hintText,
    this.keyboardType,
    this.maxLines = 1,
    this.enabled = true,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: 16,
        end: 8,
        top: 6,
        bottom: 6,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              maxLines: maxLines,
              enabled: enabled,
              decoration: InputDecoration(
                label: Text(label),
                hintText: hintText,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
              ),
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class NavigationSettingRow extends StatelessWidget {
  final String title;
  final String? value;
  final String? subtitle;
  final Widget? subtitleWidget;
  final int valueMaxLines;
  final VoidCallback onTap;

  const NavigationSettingRow({
    super.key,
    required this.title,
    this.value,
    this.subtitle,
    this.subtitleWidget,
    this.valueMaxLines = 1,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SettingRow(
      title: title,
      value: value,
      subtitle: subtitle,
      subtitleWidget: subtitleWidget,
      valueMaxLines: valueMaxLines,
      onTap: onTap,
      showChevron: true,
    );
  }
}
