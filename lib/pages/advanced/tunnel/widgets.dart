import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/advanced/tunnel/controller.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/widget/page_action_bar.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';

class PolicyDetailScaffold extends StatelessWidget {
  final String title;
  final PolicyEditorController controller;
  final Widget body;
  final bool canSave;

  const PolicyDetailScaffold({
    super.key,
    required this.title,
    required this.controller,
    required this.body,
    this.canSave = true,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return PopScope(
      canPop: !controller.blocked,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          leading: BackButton(onPressed: () => controller.cancel(context)),
        ),
        body: SafeArea(child: SettingsPageScroll(child: body)),
        bottomNavigationBar: PolicyActions(
          controller: controller,
          canSave: canSave,
          cancel: () => controller.cancel(context),
          save: () => controller.save(context),
          cancelLabel: l.prototypeCancel,
        ),
      ),
    );
  }
}

class PolicyActions extends StatelessWidget {
  final PolicyEditorController controller;
  final bool canSave;
  final VoidCallback cancel;
  final VoidCallback save;
  final String cancelLabel;
  const PolicyActions({
    super.key,
    required this.controller,
    required this.cancel,
    required this.save,
    required this.cancelLabel,
    this.canSave = true,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (controller.error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              controller.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        PageActionBar(
          children: [
            OutlinedButton(
              onPressed: controller.blocked ? null : cancel,
              child: Text(cancelLabel),
            ),
            FilledButton(
              onPressed: controller.blocked || !canSave ? null : save,
              child: controller.busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(controller.saveLabel(l)),
            ),
          ],
        ),
      ],
    );
  }
}

class PolicyToggle extends StatelessWidget {
  final PolicyEditorController controller;
  final String? section;
  final String field;
  final String title;
  final String? subtitle;
  final bool supported;
  const PolicyToggle({
    super.key,
    required this.controller,
    required this.field,
    required this.title,
    this.section,
    this.subtitle,
    this.supported = true,
  });

  @override
  Widget build(BuildContext context) => SettingRow(
    title: title,
    subtitle: subtitle,
    titleMaxLines: 4,
    trailing: Switch.adaptive(
      value:
          (section == null
                  ? controller.value
                  : controller.group(section!))[field]
              as bool,
      onChanged: controller.blocked || !supported
          ? null
          : (value) => controller.update(field, value, section: section),
    ),
  );
}

class PolicyValueRow extends StatelessWidget {
  final String title;
  final String value;
  const PolicyValueRow({super.key, required this.title, required this.value});

  @override
  Widget build(BuildContext context) => SettingRow(
    title: title,
    subtitleWidget: SelectableText(
      value,
      textDirection: TextDirection.ltr,
      style: AppTypography.code,
    ),
  );
}

/// One item per field. Controllers own list edits; this widget owns text cursors.
class PolicyStringList extends StatefulWidget {
  final String label;
  final List<String> values;
  final ValueChanged<List<String>> onChanged;
  final bool enabled;
  final String addLabel;
  final String removeLabel;
  final int? maxItems;
  const PolicyStringList({
    super.key,
    required this.label,
    required this.values,
    required this.onChanged,
    required this.addLabel,
    required this.removeLabel,
    this.enabled = true,
    this.maxItems,
  });

  @override
  State<PolicyStringList> createState() => _PolicyStringListState();
}

class _PolicyStringListState extends State<PolicyStringList> {
  late final List<TextEditingController> fields = widget.values
      .map((value) => TextEditingController(text: value))
      .toList();
  final _retired = <TextEditingController>[];

  void publish() =>
      widget.onChanged(fields.map((field) => field.text).toList());

  void add() {
    setState(() => fields.add(TextEditingController()));
    publish();
  }

  void remove(int index) {
    setState(() => _retired.add(fields.removeAt(index)));
    publish();
  }

  @override
  void dispose() {
    for (final field in [...fields, ..._retired]) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < fields.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: ObjectKey(fields[index]),
                    controller: fields[index],
                    enabled: widget.enabled,
                    autocorrect: false,
                    enableSuggestions: false,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: '${widget.label} ${index + 1}',
                    ),
                    onChanged: (_) => publish(),
                  ),
                ),
                IconButton(
                  tooltip: '${widget.removeLabel} ${index + 1}',
                  onPressed: widget.enabled ? () => remove(index) : null,
                  icon: const Icon(LucideIcons.circleX),
                ),
              ],
            ),
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed:
                widget.enabled &&
                    (widget.maxItems == null ||
                        fields.length < widget.maxItems!)
                ? add
                : null,
            icon: const Icon(LucideIcons.plus),
            label: Text(widget.addLabel),
          ),
        ),
      ],
    ),
  );
}
