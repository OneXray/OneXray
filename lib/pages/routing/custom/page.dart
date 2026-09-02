import 'package:flutter/material.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/routing/checker.dart';
import 'package:onexray/pages/routing/custom/controller.dart';
import 'package:onexray/pages/widget/page_action_bar.dart';
import 'package:onexray/pages/widget/configuration_transfer.dart';
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
      final l10n = AppLocalizations.of(context)!;
      return PopScope(
        canPop: !controller.busy,
        child: Scaffold(
          appBar: AppBar(
            title: Text(l10n.prototypeCustomRouting),
            leading: BackButton(onPressed: () => controller.close(context)),
            actions: [
              if (controller.original?.original != null)
                IconButton(
                  tooltip: l10n.prototypeDeleteRoute,
                  onPressed: controller.busy
                      ? null
                      : () => controller.delete(context),
                  icon: const Icon(LucideIcons.trash2),
                ),
            ],
          ),
          body: SafeArea(
            child: ResponsiveContent(
              child: controller.loaded
                  ? ReorderableListView.builder(
                      padding: const EdgeInsets.all(16),
                      buildDefaultDragHandles: false,
                      onReorderItem: controller.reorder,
                      header: _header(context),
                      footer: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: ShadButton.outline(
                                leading: const Icon(LucideIcons.plus),
                                onPressed: controller.busy
                                    ? null
                                    : () => controller.editRule(
                                        context,
                                        widget.openRule,
                                      ),
                                child: Text(l10n.prototypeAddRule),
                              ),
                            ),
                          ),
                          Card(
                            child: ListTile(
                              title: Text(l10n.prototypeWhenNoRuleMatches),
                              trailing: Text(l10n.prototypeUseVpn),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (controller.previewTemplate case final template?)
                            RouteChecker(
                              configuration: controller.checkConfiguration,
                              customDraft: template,
                              prepareAssets:
                                  controller.transfer.pending?.copyFilesTo,
                            ),
                        ],
                      ),
                      itemCount: controller.rules.length,
                      itemBuilder: (context, index) => Card(
                        key: ObjectKey(controller.ruleKeys[index]),
                        child: Row(
                          children: [
                            ReorderableDragStartListener(
                              index: index,
                              enabled: !controller.busy,
                              child: Tooltip(
                                message: l10n.prototypeChangeRulePosition(
                                  controller.ruleName(index, l10n),
                                ),
                                child: const SizedBox(
                                  width: 44,
                                  height: 48,
                                  child: Icon(LucideIcons.gripVertical),
                                ),
                              ),
                            ),
                            Expanded(
                              child: ListTile(
                                title: Text(
                                  '${index + 1}. ${controller.ruleName(index, l10n)}',
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      controller.ruleSummary(index),
                                      textDirection: TextDirection.ltr,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(controller.ruleAction(index, l10n)),
                                  ],
                                ),
                                onTap: controller.busy
                                    ? null
                                    : () => controller.editRule(
                                        context,
                                        widget.openRule,
                                        index,
                                      ),
                              ),
                            ),
                            IconButton(
                              tooltip: l10n.prototypeEditRule,
                              onPressed: controller.busy
                                  ? null
                                  : () => controller.editRule(
                                      context,
                                      widget.openRule,
                                      index,
                                    ),
                              icon: const Icon(LucideIcons.pencil),
                            ),
                            IconButton(
                              tooltip: l10n.prototypeDelete,
                              onPressed: controller.busy
                                  ? null
                                  : () => controller.deleteRule(index),
                              icon: const Icon(LucideIcons.trash2),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Center(
                      child: controller.busy
                          ? const CircularProgressIndicator()
                          : Text(l10n.prototypeCannotReadCustomRoute),
                    ),
            ),
          ),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (controller.busy) const LinearProgressIndicator(),
              if (controller.error case final error?)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      error,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
              PageActionBar(
                children: [
                  ShadButton.outline(
                    onPressed: controller.busy
                        ? null
                        : () => controller.close(context),
                    child: Text(l10n.prototypeCancel),
                  ),
                  ShadButton(
                    onPressed:
                        controller.busy ||
                            !controller.loaded ||
                            controller.nameError(l10n) != null
                        ? null
                        : () => controller.save(context),
                    child: Text(l10n.prototypeSave),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _header(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        widget.transferTools?.call(context, controller) ??
            ConfigurationTransferTools(
              controller: controller.transfer,
              disabled: controller.busy,
            ),
        const SizedBox(height: 16),
        TextField(
          controller: controller.name,
          maxLength: 32,
          enabled: !controller.busy,
          decoration: InputDecoration(
            labelText: l10n.prototypeRouteName,
            errorText: controller.nameError(l10n),
          ),
        ),
        const SizedBox(height: 16),
        Text(l10n.prototypeAutomaticEntryServers, style: text.titleMedium),
        const SizedBox(height: 8),
        Text(l10n.prototypeAutomaticEntryServersHint, style: text.bodySmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final count in const [1, 2, 3])
              Tooltip(
                message: l10n.prototypeUseEntryServers(count),
                child: ChoiceChip(
                  label: Text('$count'),
                  selected: controller.entryCount == count,
                  onSelected: controller.busy
                      ? null
                      : (_) => controller.setEntryCount(count),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Text(l10n.prototypeRuleList, style: text.titleMedium),
        const SizedBox(height: 8),
        Text(l10n.prototypeRulesMatchInOrder, style: text.bodySmall),
        const SizedBox(height: 12),
      ],
    );
  }
}
