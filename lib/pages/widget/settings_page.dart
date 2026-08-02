import 'package:flutter/material.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';
import 'package:re_highlight/styles/atom-one-light.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class SettingsPageScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final VoidCallback? onSave;
  final bool saveLoading;
  final String? saveLabel;
  final List<Widget> actions;

  const SettingsPageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.onSave,
    this.saveLoading = false,
    this.saveLabel,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          ...actions,
          if (onSave != null || saveLoading) _saveButton(context),
        ],
      ),
      body: SafeArea(child: body),
    );
  }

  Widget _saveButton(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final icon = saveLoading
        ? const SizedBox.square(
            dimension: 15,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(LucideIcons.save);
    if (compact || saveLabel == null) {
      final button = ShadIconButton(
        icon: icon,
        onPressed: saveLoading ? null : onSave,
      );
      final label = saveLabel;
      return label == null ? button : Tooltip(message: label, child: button);
    }
    return ShadButton(
      leading: icon,
      onPressed: saveLoading ? null : onSave,
      child: Text(saveLabel!),
    );
  }
}

class SettingsPageScroll extends StatelessWidget {
  final Widget child;
  final double desktopMaxWidth;
  final EdgeInsetsGeometry padding;

  const SettingsPageScroll({
    super.key,
    required this.child,
    this.desktopMaxWidth = 1040,
    this.padding = const EdgeInsetsDirectional.only(bottom: 24),
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: padding,
      child: ResponsiveContent(desktopMaxWidth: desktopMaxWidth, child: child),
    );
  }
}

class SettingsActionBar extends StatelessWidget {
  final List<Widget> actions;
  final double compactBreakpoint;
  final double desktopActionWidth;

  const SettingsActionBar({
    super.key,
    required this.actions,
    this.compactBreakpoint = 600,
    this.desktopActionWidth = 156,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < compactBreakpoint;
        return Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 64),
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: compact ? 12 : 22,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: ColorManager.surface(context),
            border: Border(
              top: BorderSide(color: ColorManager.border(context)),
            ),
          ),
          child: Row(
            mainAxisAlignment: compact
                ? MainAxisAlignment.start
                : MainAxisAlignment.end,
            children: _buildActions(compact),
          ),
        );
      },
    );
  }

  List<Widget> _buildActions(bool compact) {
    final widgets = <Widget>[];
    for (var index = 0; index < actions.length; index++) {
      if (index > 0) {
        widgets.add(const SizedBox(width: 10));
      }
      widgets.add(
        compact
            ? Expanded(child: actions[index])
            : SizedBox(width: desktopActionWidth, child: actions[index]),
      );
    }
    return widgets;
  }
}

class SettingsChoiceIndicator extends StatelessWidget {
  final bool selected;

  const SettingsChoiceIndicator({super.key, required this.selected});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? primary : Colors.transparent,
        border: Border.all(
          color: selected ? primary : ColorManager.border(context),
        ),
        shape: BoxShape.circle,
      ),
      child: selected
          ? Icon(
              LucideIcons.check,
              size: 13,
              color: Theme.of(context).colorScheme.onPrimary,
            )
          : null,
    );
  }
}

class SettingsChoiceRow extends StatelessWidget {
  final String title;
  final String? description;
  final Widget? leading;
  final bool selected;
  final VoidCallback? onTap;

  const SettingsChoiceRow({
    super.key,
    required this.title,
    this.description,
    this.leading,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SettingRow(
      title: title,
      subtitle: description,
      leading: leading,
      onTap: onTap,
      trailing: SettingsChoiceIndicator(selected: selected),
    );
  }
}

class AppConfirmationDialog extends StatelessWidget {
  final String title;
  final String content;
  final String cancelLabel;
  final String confirmLabel;
  final bool destructive;

  const AppConfirmationDialog({
    super.key,
    required this.title,
    required this.content,
    required this.cancelLabel,
    required this.confirmLabel,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final confirm = destructive
        ? ShadButton.destructive(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          )
        : ShadButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          );
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: ShadCard(
          width: double.infinity,
          padding: EdgeInsets.zero,
          radius: const BorderRadius.all(Radius.circular(8)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(18, 17, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      content,
                      style: AppTypography.supporting.copyWith(
                        color: ColorManager.secondaryText(context),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ColorManager.tagBackground(
                    context,
                  ).withValues(alpha: 0.45),
                  border: Border(
                    top: BorderSide(color: ColorManager.border(context)),
                  ),
                ),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ShadButton.outline(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(cancelLabel),
                    ),
                    confirm,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsPageIntro extends StatelessWidget {
  final String title;
  final String? description;
  final Widget? trailing;

  const SettingsPageIntro({
    super.key,
    required this.title,
    this.description,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 22, 16, 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.panelTitle),
                if (description != null && description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description!,
                    style: AppTypography.supporting.copyWith(
                      color: ColorManager.secondaryText(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 16), trailing!],
        ],
      ),
    );
  }
}

class SettingsSectionNavigationItem<T extends Object> {
  final T value;
  final String title;
  final String description;
  final String group;
  final IconData icon;

  const SettingsSectionNavigationItem({
    required this.value,
    required this.title,
    required this.description,
    required this.group,
    required this.icon,
  });
}

class SettingsJsonEditor extends StatefulWidget {
  final TextEditingController controller;
  final int lineCount;
  final bool valid;
  final String validLabel;
  final String invalidLabel;
  final String linesLabel;
  final String spacesLabel;

  const SettingsJsonEditor({
    super.key,
    required this.controller,
    required this.lineCount,
    required this.valid,
    required this.validLabel,
    required this.invalidLabel,
    required this.linesLabel,
    required this.spacesLabel,
  });

  @override
  State<SettingsJsonEditor> createState() => _SettingsJsonEditorState();
}

class _SettingsJsonEditorState extends State<SettingsJsonEditor> {
  final _editorScrollController = ScrollController();
  final _lineScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _editorScrollController.addListener(_syncLineNumbers);
  }

  @override
  void dispose() {
    _editorScrollController
      ..removeListener(_syncLineNumbers)
      ..dispose();
    _lineScrollController.dispose();
    super.dispose();
  }

  void _syncLineNumbers() {
    if (!_lineScrollController.hasClients) {
      return;
    }
    final target = _editorScrollController.offset.clamp(
      _lineScrollController.position.minScrollExtent,
      _lineScrollController.position.maxScrollExtent,
    );
    _lineScrollController.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsJsonEditorFrame(
      valid: widget.valid,
      validLabel: widget.validLabel,
      invalidLabel: widget.invalidLabel,
      linesLabel: widget.linesLabel,
      spacesLabel: widget.spacesLabel,
      editor: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 45,
            color: ColorManager.tagBackground(context).withValues(alpha: 0.45),
            child: SingleChildScrollView(
              controller: _lineScrollController,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsetsDirectional.fromSTEB(7, 13, 7, 24),
              child: Text(
                List.generate(
                  widget.lineCount,
                  (index) => index + 1,
                ).join("\n"),
                textAlign: TextAlign.end,
                style: AppTypography.code.copyWith(
                  color: ColorManager.secondaryText(context),
                ),
              ),
            ),
          ),
          VerticalDivider(width: 1, color: ColorManager.border(context)),
          Expanded(
            child: TextField(
              controller: widget.controller,
              scrollController: _editorScrollController,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsetsDirectional.fromSTEB(13, 13, 16, 24),
              ),
              keyboardType: TextInputType.multiline,
              style: AppTypography.code,
              minLines: null,
              maxLines: null,
              expands: true,
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsCodeEditor extends StatelessWidget {
  final CodeLineEditingController controller;
  final bool valid;
  final String validLabel;
  final String invalidLabel;
  final String linesLabel;
  final String spacesLabel;

  const SettingsCodeEditor({
    super.key,
    required this.controller,
    required this.valid,
    required this.validLabel,
    required this.invalidLabel,
    required this.linesLabel,
    required this.spacesLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final codeTheme = Map<String, TextStyle>.from(
      dark ? atomOneDarkTheme : atomOneLightTheme,
    );
    codeTheme["root"] = codeTheme["root"]!.copyWith(
      backgroundColor: Colors.transparent,
    );

    return _SettingsJsonEditorFrame(
      valid: valid,
      validLabel: validLabel,
      invalidLabel: invalidLabel,
      linesLabel: linesLabel,
      spacesLabel: spacesLabel,
      editor: CodeEditor(
        controller: controller,
        wordWrap: false,
        padding: const EdgeInsetsDirectional.fromSTEB(12, 13, 16, 24),
        style: CodeEditorStyle(
          fontFamily: AppFontFamily.mono,
          fontSize: AppTypography.code.fontSize!,
          fontHeight: AppTypography.code.height!,
          textColor: colorScheme.onSurface,
          backgroundColor: ColorManager.surface(context),
          selectionColor: colorScheme.primary.withValues(alpha: 0.2),
          cursorColor: colorScheme.primary,
          cursorLineColor: colorScheme.primary.withValues(alpha: 0.05),
          codeTheme: CodeHighlightTheme(
            languages: {"json": CodeHighlightThemeMode(mode: langJson)},
            theme: codeTheme,
          ),
        ),
        indicatorBuilder: (context, editingController, _, notifier) {
          final textStyle = AppTypography.code.copyWith(
            color: ColorManager.secondaryText(context),
          );
          return Container(
            color: ColorManager.tagBackground(context).withValues(alpha: 0.45),
            padding: const EdgeInsetsDirectional.fromSTEB(8, 13, 8, 24),
            child: DefaultCodeLineNumber(
              controller: editingController,
              notifier: notifier,
              textStyle: textStyle,
              focusedTextStyle: textStyle.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        },
        leadingDivider: Container(
          width: 1,
          color: ColorManager.border(context),
        ),
      ),
    );
  }
}

class _SettingsJsonEditorFrame extends StatelessWidget {
  final Widget editor;
  final bool valid;
  final String validLabel;
  final String invalidLabel;
  final String linesLabel;
  final String spacesLabel;

  const _SettingsJsonEditorFrame({
    required this.editor,
    required this.valid,
    required this.validLabel,
    required this.invalidLabel,
    required this.linesLabel,
    required this.spacesLabel,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = valid
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;
    return ShadCard(
      width: double.infinity,
      height: double.infinity,
      padding: EdgeInsets.zero,
      radius: const BorderRadius.all(Radius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(13, 10, 13, 9),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    LucideIcons.braces,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "xray.json",
                        style: AppTypography.supporting.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        "UTF-8 · JSON",
                        style: AppTypography.badge.copyWith(
                          color: ColorManager.secondaryText(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    valid ? validLabel : invalidLabel,
                    style: AppTypography.badge.copyWith(color: statusColor),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: ColorManager.border(context)),
          Expanded(child: editor),
          Divider(height: 1, color: ColorManager.border(context)),
          Container(
            constraints: const BoxConstraints(minHeight: 31),
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
            color: ColorManager.tagBackground(context).withValues(alpha: 0.45),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    valid ? validLabel : invalidLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.badge.copyWith(
                      color: ColorManager.secondaryText(context),
                    ),
                  ),
                ),
                Text(
                  linesLabel,
                  style: AppTypography.badge.copyWith(
                    color: ColorManager.secondaryText(context),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  spacesLabel,
                  style: AppTypography.badge.copyWith(
                    color: ColorManager.secondaryText(context),
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

class SettingsPageActionBar extends StatelessWidget {
  final List<Widget> children;

  const SettingsPageActionBar({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsetsDirectional.fromSTEB(16, 9, 16, 9),
      decoration: BoxDecoration(
        color: ColorManager.surface(context),
        border: Border(top: BorderSide(color: ColorManager.border(context))),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.end, children: children),
    );
  }
}

class SettingsSectionNavigation<T extends Object> extends StatelessWidget {
  final bool compact;
  final T selected;
  final List<SettingsSectionNavigationItem<T>> items;
  final ValueChanged<T> onSelected;

  const SettingsSectionNavigation({
    super.key,
    required this.compact,
    required this.selected,
    required this.items,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return compact ? _compactNavigation(context) : _rail(context);
  }

  Widget _rail(BuildContext context) {
    final groups = <String>[];
    for (final item in items) {
      if (!groups.contains(item.group)) {
        groups.add(item.group);
      }
    }
    return ColoredBox(
      color: ColorManager.tagBackground(context).withValues(alpha: 0.45),
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(10, 14, 10, 18),
        children: [
          for (final group in groups) ...[
            _groupLabel(context, group),
            for (final item in items.where((item) => item.group == group))
              _navigationItem(context, item),
          ],
        ],
      ),
    );
  }

  Widget _compactNavigation(BuildContext context) {
    return Container(
      height: 58,
      color: ColorManager.tagBackground(context).withValues(alpha: 0.35),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 10,
          vertical: 8,
        ),
        child: Row(
          children: [
            for (var index = 0; index < items.length; index++) ...[
              if (index > 0) const SizedBox(width: 5),
              _navigationItem(context, items[index], compact: true),
            ],
          ],
        ),
      ),
    );
  }

  Widget _compactTitle(
    BuildContext context,
    SettingsSectionNavigationItem<T> item,
    Color foreground,
  ) {
    return Text(
      item.title,
      maxLines: 1,
      softWrap: false,
      style: AppTypography.navigationLabel.copyWith(color: foreground),
    );
  }

  Widget _railTitle(
    BuildContext context,
    SettingsSectionNavigationItem<T> item,
    Color foreground,
  ) {
    return Flexible(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.navigationLabel.copyWith(color: foreground),
          ),
          if (item.description.isNotEmpty)
            Text(
              item.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.badge.copyWith(
                color: ColorManager.secondaryText(context),
              ),
            ),
        ],
      ),
    );
  }

  Widget _navigationItem(
    BuildContext context,
    SettingsSectionNavigationItem<T> item, {
    bool compact = false,
  }) {
    final isSelected = selected == item.value;
    final foreground = isSelected
        ? Theme.of(context).colorScheme.primary
        : ColorManager.secondaryText(context);
    return Material(
      color: isSelected
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.09)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => onSelected(item.value),
        child: SizedBox(
          height: compact ? 40 : 48,
          child: Padding(
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: compact ? 12 : 10,
            ),
            child: Row(
              mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
              children: [
                Icon(item.icon, size: 17, color: foreground),
                const SizedBox(width: 8),
                compact
                    ? _compactTitle(context, item, foreground)
                    : _railTitle(context, item, foreground),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _groupLabel(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(10, 13, 10, 5),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.badge.copyWith(
          color: ColorManager.secondaryText(context),
        ),
      ),
    );
  }
}

class SettingsResponsiveColumns extends StatelessWidget {
  final List<Widget> first;
  final List<Widget> second;
  final double breakpoint;
  final int firstFlex;
  final int secondFlex;

  const SettingsResponsiveColumns({
    super.key,
    required this.first,
    required this.second,
    this.breakpoint = 840,
    this.firstFlex = 4,
    this.secondFlex = 6,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(children: [...first, ...second]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: firstFlex,
              child: Column(children: first),
            ),
            Expanded(
              flex: secondFlex,
              child: Column(children: second),
            ),
          ],
        );
      },
    );
  }
}

class SettingsOverviewGrid extends StatelessWidget {
  final List<Widget> children;
  final int columns;
  final double breakpoint;

  const SettingsOverviewGrid({
    super.key,
    required this.children,
    this.columns = 2,
    this.breakpoint = 760,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint || columns == 1) {
          return Column(children: children);
        }
        final rows = <Widget>[];
        for (var index = 0; index < children.length; index += columns) {
          final rowChildren = <Widget>[];
          for (var column = 0; column < columns; column++) {
            final childIndex = index + column;
            rowChildren.add(
              Expanded(
                child: childIndex < children.length
                    ? children[childIndex]
                    : const SizedBox.shrink(),
              ),
            );
          }
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rowChildren,
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }
}

class SettingsChoiceChips<T extends Object> extends StatelessWidget {
  final List<T> options;
  final Set<T> selected;
  final String Function(T option) labelBuilder;
  final ValueChanged<T> onToggle;

  const SettingsChoiceChips({
    super.key,
    required this.options,
    required this.selected,
    required this.labelBuilder,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: options.map((option) {
        final active = selected.contains(option);
        return ShadButton.raw(
          variant: active
              ? ShadButtonVariant.primary
              : ShadButtonVariant.outline,
          size: ShadButtonSize.sm,
          onPressed: () => onToggle(option),
          leading: active ? const Icon(LucideIcons.check, size: 14) : null,
          child: Text(labelBuilder(option)),
        );
      }).toList(),
    );
  }
}

class SettingsBadge extends StatelessWidget {
  final String label;
  final bool selected;

  const SettingsBadge({super.key, required this.label, this.selected = false});

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? Theme.of(context).colorScheme.onPrimary
        : ColorManager.secondaryText(context);
    final background = selected
        ? Theme.of(context).colorScheme.primary
        : ColorManager.tagBackground(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 20),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 7,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.badge.copyWith(color: foreground),
      ),
    );
  }
}
