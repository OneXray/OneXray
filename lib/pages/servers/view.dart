import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/servers/controller.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/service/connection/settings.dart';

class ServerBrowser extends StatelessWidget {
  final ServersController controller;
  final ScrollController scroll;
  final bool picker;
  final ServerExitPickerParams? exitPicker;
  const ServerBrowser({
    super.key,
    required this.controller,
    required this.scroll,
    this.picker = false,
    this.exitPicker,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final groups = controller.groups(l);
    final favorites = controller.favorites(l);
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 840;
        final selectedGroup =
            groups
                .where((row) => row.id == controller.activeGroupId)
                .firstOrNull ??
            groups.firstOrNull;
        final browse = ListView(
          controller: scroll,
          padding: const EdgeInsets.all(16),
          children: [
            if (exitPicker != null)
              ListTile(
                leading: const Icon(LucideIcons.circleSlash),
                title: Text(l.prototypeNoAdditionalExit),
                subtitle: Text(l.prototypeEntryConnectsDirectly),
                selected: exitPicker!.selectedId == null,
                onTap: () => controller.chooseExit(context, null),
              )
            else
              ListTile(
                leading: const Icon(LucideIcons.sparkles),
                title: Text(l.prototypeAutomaticRecommended),
                subtitle: Text(l.prototypeChooseBySpeedAvailability),
                selected: controller.selected(
                  const ServerSelection.automatic(),
                ),
                onTap: controller.busy
                    ? null
                    : () => controller.choose(
                        context,
                        const ServerSelection.automatic(),
                        picker: picker,
                      ),
              ),
            if (favorites.isNotEmpty) ...[
              ServerSectionTitle(l.prototypeFavorites),
              for (final row in favorites)
                ServerNodeRow(
                  controller: controller,
                  row: row,
                  picker: picker,
                  exitPicker: exitPicker,
                ),
              const SizedBox(height: 16),
            ],
            if (controller.servers.isEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    const Icon(LucideIcons.server),
                    const SizedBox(height: 12),
                    Text(
                      l.prototypeNoServersYet,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l.prototypeAddProviderSubscriptionHint,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: controller.busy
                          ? null
                          : () => controller.addServers(context),
                      icon: const Icon(LucideIcons.plus),
                      label: Text(l.prototypeAddServers),
                    ),
                  ],
                ),
              ),
            ],
            for (final group in groups)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: !mobile && selectedGroup?.id == group.id
                    ? Theme.of(context).colorScheme.secondaryContainer
                    : null,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: 4,
                    end: 4,
                    bottom: 4,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ListTile(
                        leading: Icon(
                          controller.grouping == ServerGrouping.location
                              ? LucideIcons.globe
                              : LucideIcons.folder,
                        ),
                        title: Text(group.name),
                        subtitle: Text(controller.summary(l, group)),
                        trailing: const Icon(LucideIcons.chevronRight),
                        onTap: () => controller.browse(
                          context,
                          group,
                          mobile: mobile,
                          picker: picker,
                          exitPicker: exitPicker,
                        ),
                      ),
                      Wrap(
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (exitPicker == null)
                            ServerUseButton(
                              controller: controller,
                              group: group,
                              picker: picker,
                            ),
                          if (group.source != null)
                            SourceMenu(
                              controller: controller,
                              source: group.source!,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            if (groups.isEmpty && controller.search.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  controller.grouping == ServerGrouping.location
                      ? l.prototypeNoMatchingLocations
                      : l.prototypeNoMatchingSubscriptions,
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        );
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ServerGrouping>(
                      segments: [
                        ButtonSegment(
                          value: ServerGrouping.location,
                          label: Text(l.prototypeByNodeLocation),
                        ),
                        ButtonSegment(
                          value: ServerGrouping.subscription,
                          label: Text(l.prototypeBySubscription),
                        ),
                      ],
                      selected: {controller.grouping},
                      showSelectedIcon: false,
                      onSelectionChanged: (values) =>
                          controller.groupBy(values.single),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller.search,
                    onChanged: controller.searchChanged,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(LucideIcons.search),
                      hintText: controller.grouping == ServerGrouping.location
                          ? l.prototypeSearchLocationsServers
                          : l.prototypeSearchSubscriptionsServers,
                      suffixIcon: controller.search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: l.prototypeClear,
                              onPressed: () {
                                controller.search.clear();
                                controller.searchChanged('');
                              },
                              icon: const Icon(LucideIcons.x),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            if (controller.actionBusy) const LinearProgressIndicator(),
            Expanded(
              child: mobile
                  ? browse
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(width: 350, child: browse),
                        const VerticalDivider(width: 1),
                        Expanded(
                          child: selectedGroup == null
                              ? const SizedBox.shrink()
                              : ServerGroupView(
                                  controller: controller,
                                  group: selectedGroup,
                                  picker: picker,
                                  exitPicker: exitPicker,
                                ),
                        ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

class ServerGroupView extends StatelessWidget {
  final ServersController controller;
  final ServerGroup group;
  final bool picker;
  final bool groupPage;
  final ServerExitPickerParams? exitPicker;
  const ServerGroupView({
    super.key,
    required this.controller,
    required this.group,
    this.picker = false,
    this.groupPage = false,
    this.exitPicker,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return ListView(
      key: PageStorageKey('servers:${group.id}'),
      padding: const EdgeInsets.all(16),
      children: [
        if (!groupPage)
          Text(group.name, style: Theme.of(context).textTheme.titleLarge),
        Text(
          controller.summary(l, group),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: controller.busy || group.rows.isEmpty
                  ? null
                  : () => controller.test(context, group.rows),
              icon: const Icon(LucideIcons.gauge),
              label: Text(l.prototypeTestServers),
            ),
            if (exitPicker == null)
              ServerUseButton(
                controller: controller,
                group: group,
                picker: picker,
                groupPage: groupPage,
              ),
            if (group.source != null)
              SourceMenu(controller: controller, source: group.source!),
          ],
        ),
        const Divider(height: 28),
        if (group.visibleRows.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l.prototypeNoServersYet),
          ),
        for (final row in group.visibleRows)
          ServerNodeRow(
            controller: controller,
            row: row,
            picker: picker,
            groupPage: groupPage,
            exitPicker: exitPicker,
          ),
      ],
    );
  }
}

class ServerUseButton extends StatelessWidget {
  final ServersController controller;
  final ServerGroup group;
  final bool picker;
  final bool groupPage;
  const ServerUseButton({
    super.key,
    required this.controller,
    required this.group,
    this.picker = false,
    this.groupPage = false,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final count = controller.entryCount(group.selection);
    final enabled = controller.canUse(group);
    return Tooltip(
      message: enabled
          ? l.prototypeUseEntryServers(count)
          : l.prototypeNotEnoughServers,
      child: OutlinedButton.icon(
        onPressed: controller.busy || !enabled
            ? null
            : () => controller.choose(
                context,
                group.selection,
                picker: picker,
                groupPage: groupPage,
              ),
        icon: Icon(
          controller.selected(group.selection)
              ? LucideIcons.check
              : LucideIcons.network,
        ),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.prototypeUse),
            const SizedBox(width: 6),
            Badge(
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              textColor: Theme.of(context).colorScheme.onSecondaryContainer,
              label: Text('$count'),
            ),
          ],
        ),
      ),
    );
  }
}

class ServerNodeRow extends StatelessWidget {
  final ServersController controller;
  final CoreConfigData row;
  final bool picker;
  final bool groupPage;
  final ServerExitPickerParams? exitPicker;
  const ServerNodeRow({
    super.key,
    required this.controller,
    required this.row,
    this.picker = false,
    this.groupPage = false,
    this.exitPicker,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final running = controller.runningEntries.contains(row.id);
    final chosen = controller.chosen(row, exitPicker: exitPicker);
    final enabled = controller.canChoose(row, exitPicker: exitPicker);
    final colors = Theme.of(context).colorScheme;
    final protocol = controller.protocol(row);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: running ? colors.primaryContainer : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: running ? colors.primary : colors.outlineVariant,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: controller.busy || !enabled
                    ? null
                    : () => controller.chooseRow(
                        context,
                        row,
                        picker: picker,
                        groupPage: groupPage,
                        exitPicker: exitPicker,
                      ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (chosen) ...[
                            Icon(
                              LucideIcons.circleCheck,
                              color: colors.primary,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              controller.serverName(row),
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                        ],
                      ),
                      if (protocol.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            protocol,
                            textDirection: TextDirection.ltr,
                            style: AppTypography.badge,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        '${controller.countryName(l, row.countryCode)} · ${controller.sourceName(l, row)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        '${running ? '${l.prototypeConnected} · ' : ''}${controller.health(l, row)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: running
                              ? colors.primary
                              : colors.onSurfaceVariant,
                        ),
                      ),
                      if (controller.exitConflict(row, exitPicker: exitPicker))
                        Text(
                          l.prototypeFinalExitEntryConflict,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: row.favorite
                      ? l.prototypeRemoveFavorite
                      : l.prototypeAddFavorite,
                  onPressed: controller.busy
                      ? null
                      : () => controller.toggleFavorite(context, row),
                  isSelected: row.favorite,
                  icon: const Icon(LucideIcons.star),
                  selectedIcon: Icon(LucideIcons.star, color: colors.primary),
                ),
                ServerMenu(controller: controller, row: row),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ServerMenu extends StatelessWidget {
  final ServersController controller;
  final CoreConfigData row;
  const ServerMenu({super.key, required this.controller, required this.row});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return PopupMenuButton<ServerAction>(
      tooltip: l.prototypeMoreActions,
      enabled: !controller.busy,
      icon: const Icon(LucideIcons.ellipsis),
      onSelected: (action) => controller.serverAction(context, row, action),
      itemBuilder: (_) => [
        PopupMenuItem(value: ServerAction.edit, child: Text(l.prototypeEdit)),
        PopupMenuItem(
          value: ServerAction.test,
          child: Text(l.prototypeTestAgain),
        ),
        if (row.subId != 0)
          PopupMenuItem(
            value: ServerAction.copy,
            child: Text(l.prototypeSaveAsLocalServer),
          ),
        PopupMenuItem(value: ServerAction.share, child: Text(l.prototypeShare)),
        PopupMenuItem(
          value: ServerAction.delete,
          child: Text(l.prototypeDelete),
        ),
      ],
    );
  }
}

class SourceMenu extends StatelessWidget {
  final ServersController controller;
  final SubscriptionData source;
  const SourceMenu({super.key, required this.controller, required this.source});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return PopupMenuButton<SourceAction>(
      tooltip: l.prototypeMoreActions,
      enabled: !controller.busy,
      icon: const Icon(LucideIcons.ellipsis),
      onSelected: (action) => controller.sourceAction(context, source, action),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: SourceAction.update,
          child: Text(l.prototypeCheckForUpdates),
        ),
        PopupMenuItem(
          value: SourceAction.test,
          child: Text(l.prototypeTestServers),
        ),
        PopupMenuItem(value: SourceAction.edit, child: Text(l.prototypeEdit)),
        PopupMenuItem(value: SourceAction.share, child: Text(l.prototypeShare)),
        PopupMenuItem(
          value: SourceAction.delete,
          child: Text(l.prototypeDelete),
        ),
      ],
    );
  }
}

class ServerSectionTitle extends StatelessWidget {
  final String title;
  const ServerSectionTitle(this.title, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(title, style: Theme.of(context).textTheme.titleSmall),
  );
}
