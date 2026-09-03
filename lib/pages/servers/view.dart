import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/servers/controller.dart';
import 'package:onexray/pages/servers/menus.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/service/connection/settings.dart';

class ServerBrowser extends StatelessWidget {
  final ServersController controller;
  final ScrollController scroll;
  const ServerBrowser({
    super.key,
    required this.controller,
    required this.scroll,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final groups = controller.groups(l);
    final favorites = controller.favorites(l);
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 840;
        if (constraints.maxWidth <= AppLayout.mobileBreakpoint) {
          return _mobileBrowser(context, groups, favorites);
        }
        final selectedGroup =
            groups
                .where((row) => row.id == controller.activeGroupId)
                .firstOrNull ??
            groups.firstOrNull;
        final browse = ListView(
          controller: scroll,
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              leading: const Icon(LucideIcons.sparkles),
              title: Text(l.prototypeAutomaticRecommended),
              subtitle: Text(l.prototypeChooseBySpeedAvailability),
              selected: controller.selected(const ServerSelection.automatic()),
              onTap: controller.busy
                  ? null
                  : () => controller.choose(
                      context,
                      const ServerSelection.automatic(),
                    ),
            ),
            if (favorites.isNotEmpty) ...[
              ServerSectionTitle(l.prototypeFavorites),
              for (final row in favorites)
                ServerNodeRow(controller: controller, row: row),
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
                        trailing: const Icon(LucideIcons.chevronRightDir),
                        onTap: () =>
                            controller.browse(context, group, mobile: mobile),
                      ),
                      Wrap(
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ServerUseButton(controller: controller, group: group),
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

  Widget _mobileBrowser(
    BuildContext context,
    List<ServerGroup> groups,
    List<CoreConfigData> favorites,
  ) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    final current = controller.currentSelectionSummary(l);
    final currentGroupId = controller.currentGroupId;
    final activeGroup =
        groups
            .where((group) => group.id == controller.activeGroupId)
            .firstOrNull ??
        groups.where((group) => group.id == currentGroupId).firstOrNull ??
        groups.firstOrNull;
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.card),
      borderSide: BorderSide(color: palette.border),
    );
    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 22),
      children: [
        DefaultTabController(
          length: ServerGrouping.values.length,
          initialIndex: controller.grouping.index,
          child: TabBar(
            onTap: (index) => controller.groupBy(ServerGrouping.values[index]),
            labelStyle: AppTypography.selectedAdvancedTab,
            unselectedLabelStyle: AppTypography.advancedTab,
            unselectedLabelColor: palette.mutedStrong,
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: [
              Tab(height: 38, text: l.prototypeByNodeLocation),
              Tab(height: 38, text: l.prototypeBySubscription),
            ],
          ),
        ),
        const SizedBox(height: 15),
        SizedBox(
          height: 43,
          child: TextField(
            controller: controller.search,
            onChanged: controller.searchChanged,
            textAlignVertical: TextAlignVertical.center,
            style: AppTypography.serverBody.copyWith(color: palette.foreground),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsetsDirectional.only(end: 13),
              hintText: l.prototypeSearchSubscriptionsServers,
              hintStyle: AppTypography.serverBody.copyWith(
                color: palette.mutedForeground,
              ),
              prefixIconConstraints: const BoxConstraints.tightFor(
                width: 41,
                height: 43,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsetsDirectional.only(start: 13, end: 10),
                child: Icon(
                  LucideIcons.search,
                  size: 18,
                  color: palette.mutedForeground,
                ),
              ),
              border: inputBorder,
              enabledBorder: inputBorder,
              focusedBorder: inputBorder.copyWith(
                borderSide: BorderSide(color: palette.primary),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (controller.actionBusy) const LinearProgressIndicator(),
        Material(
          color: palette.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.card),
            side: BorderSide(color: palette.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _automaticRow(context),
              if (current != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Color.lerp(
                      palette.card,
                      palette.selectedSurface,
                      .45,
                    ),
                    border: Border(top: BorderSide(color: palette.border)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.circleCheck,
                        size: 20,
                        color: palette.running,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.prototypeCurrentSelection,
                              style: AppTypography.serverSelectionLabel
                                  .copyWith(color: palette.mutedForeground),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              current.title,
                              style: AppTypography.serverSelectionTitle
                                  .copyWith(color: palette.foreground),
                            ),
                            if (current.detail.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                current.detail,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.serverSelectionDetail
                                    .copyWith(color: palette.mutedForeground),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              if (favorites.isNotEmpty) ...[
                _listHeading(context, l.prototypeFavorites),
                for (final row in favorites)
                  ServerNodeRow(controller: controller, row: row),
              ],
              if (controller.servers.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
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
              _listHeading(
                context,
                controller.grouping == ServerGrouping.location
                    ? l.prototypeByNodeLocation
                    : l.prototypeBySubscription,
              ),
              for (final group in groups)
                _groupRow(context, group, active: group.id == activeGroup?.id),
              if (groups.isEmpty && controller.search.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 28,
                  ),
                  child: Text(
                    controller.grouping == ServerGrouping.location
                        ? l.prototypeNoMatchingLocations
                        : l.prototypeNoMatchingSubscriptions,
                    textAlign: TextAlign.center,
                    style: AppTypography.settingsInput.copyWith(
                      color: palette.mutedForeground,
                    ),
                  ),
                ),
              InkWell(
                onTap: controller.busy
                    ? null
                    : () => controller.openSources(context),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 52),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.refreshCw,
                          size: 17,
                          color: palette.primary,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            l.prototypeUpdatesAndSources,
                            style: AppTypography.serverBody.copyWith(
                              color: palette.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _listHeading(BuildContext context, String title) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(16, 17, 16, 8),
    child: Text(
      title.toUpperCase(),
      style: AppTypography.serverSectionTitle.copyWith(
        color: ColorManager.palette(context).mutedForeground,
      ),
    ),
  );

  Widget _automaticRow(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    final selected = controller.selected(const ServerSelection.automatic());
    final result = controller.automaticResult(l);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected
            ? Color.lerp(palette.card, palette.selectedSurface, .72)
            : palette.card,
        child: InkWell(
          onTap: controller.busy
              ? null
              : () => controller.choose(
                  context,
                  const ServerSelection.automatic(),
                ),
          child: Container(
            constraints: const BoxConstraints(minHeight: 82),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: palette.border)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: palette.selectedSurface,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    LucideIcons.zap,
                    size: 20,
                    color: palette.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.prototypeAutomaticRecommended,
                        style: AppTypography.serverTitle.copyWith(
                          color: palette.foreground,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l.prototypeChooseBySpeedAvailability,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.serverDetail.copyWith(
                          color: palette.mutedForeground,
                        ),
                      ),
                      if (result != null) ...[
                        const SizedBox(height: 5),
                        Text(
                          result,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.serverSelectionHealth.copyWith(
                            color: palette.running,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  selected
                      ? LucideIcons.circleCheck
                      : LucideIcons.chevronRightDir,
                  size: selected ? 21 : 18,
                  color: selected ? palette.running : palette.foreground,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _groupRow(
    BuildContext context,
    ServerGroup group, {
    required bool active,
  }) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    return Material(
      color: active ? palette.muted : palette.card,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: palette.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => controller.browse(context, group, mobile: true),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 66),
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 6, 10),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: palette.surfaceHover,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: group.country == null
                            ? Icon(
                                LucideIcons.layers,
                                size: 17,
                                color: palette.primary,
                              )
                            : Text(
                                group.country!,
                                textDirection: TextDirection.ltr,
                                style: AppTypography.serverRegionCode.copyWith(
                                  color: palette.mutedStrong,
                                ),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group.name,
                              style: AppTypography.serverTitle.copyWith(
                                color: palette.foreground,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              controller.summary(l, group),
                              style: AppTypography.serverGroupDetail.copyWith(
                                color: palette.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        LucideIcons.chevronRightDir,
                        size: 18,
                        color: palette.foreground,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ServerUseButton(
                controller: controller,
                group: group,
                inline: true,
              ),
            ),
            if (group.source != null)
              SizedBox(
                width: 42,
                child: SourceMenu(
                  controller: controller,
                  source: group.source!,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ServerGroupView extends StatelessWidget {
  final ServersController controller;
  final ServerGroup group;
  final bool groupPage;
  const ServerGroupView({
    super.key,
    required this.controller,
    required this.group,
    this.groupPage = false,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint) {
      return _mobileGroup(context);
    }
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
            ServerUseButton(controller: controller, group: group),
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
          ServerNodeRow(controller: controller, row: row),
      ],
    );
  }

  Widget _mobileGroup(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    return ListView(
      key: PageStorageKey('servers:${group.id}'),
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 22),
      children: [
        Material(
          color: palette.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.card),
            side: BorderSide(color: palette.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 17,
                    vertical: 15,
                  ),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: palette.border)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: palette.surfaceHover,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: group.country == null
                                ? Icon(
                                    LucideIcons.layers3,
                                    size: 20,
                                    color: palette.primary,
                                  )
                                : Text(
                                    group.country!.isEmpty
                                        ? '—'
                                        : group.country!,
                                    style: AppTypography.serverGroupCode
                                        .copyWith(color: palette.mutedStrong),
                                  ),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                controller.summary(l, group),
                                style: AppTypography.serverGroupSummary
                                    .copyWith(color: palette.mutedForeground),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          OutlinedButton(
                            onPressed: controller.busy || group.rows.isEmpty
                                ? null
                                : () => controller.test(context, group.rows),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(
                                0,
                                AppLayout.mobileButtonMinHeight,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 15,
                              ),
                              foregroundColor: palette.foreground,
                              backgroundColor: palette.card,
                              side: BorderSide(color: palette.borderStrong),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadii.control,
                                ),
                              ),
                              textStyle: AppTypography.serverGroupAction,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.standard,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(LucideIcons.refreshCw, size: 16),
                                const SizedBox(width: 8),
                                Text(l.prototypeTestServers),
                              ],
                            ),
                          ),
                          ServerUseButton(controller: controller, group: group),
                          if (group.source != null)
                            SizedBox(
                              width: 36,
                              child: SourceMenu(
                                controller: controller,
                                source: group.source!,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (group.visibleRows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 28,
                    ),
                    child: Text(
                      l.prototypeNoServersYet,
                      textAlign: TextAlign.center,
                      style: AppTypography.rowValue.copyWith(
                        color: palette.mutedForeground,
                      ),
                    ),
                  ),
                for (final row in group.visibleRows)
                  ServerNodeRow(
                    controller: controller,
                    row: row,
                    detail: group.country != null
                        ? controller.sourceName(l, row)
                        : controller.countryName(l, row.countryCode),
                    showDivider: row != group.visibleRows.last,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ServerUseButton extends StatelessWidget {
  final ServersController controller;
  final ServerGroup group;
  final bool inline;
  const ServerUseButton({
    super.key,
    required this.controller,
    required this.group,
    this.inline = false,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final count = controller.entryCount(group.selection);
    final enabled = controller.canUse(group);
    final selected = controller.selected(group.selection);
    final VoidCallback? choose = controller.busy || !enabled
        ? null
        : () => controller.choose(context, group.selection);
    if (inline ||
        MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint) {
      final palette = ColorManager.palette(context);
      return Semantics(
        label: '${l.prototypeUseEntryServers(count)}: ${group.name}',
        button: true,
        selected: selected,
        enabled: choose != null,
        onTap: choose,
        excludeSemantics: true,
        child: Tooltip(
          message: enabled
              ? l.prototypeUseEntryServers(count)
              : l.prototypeNotEnoughServers,
          child: Opacity(
            opacity: choose == null ? .52 : 1,
            child: OutlinedButton(
              onPressed: choose,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, AppLayout.mobileButtonMinHeight),
                padding: const EdgeInsets.symmetric(horizontal: 9),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.standard,
                foregroundColor: selected
                    ? palette.primary
                    : palette.foreground,
                backgroundColor: selected
                    ? palette.selectedSurface
                    : palette.card,
                side: BorderSide(
                  color: selected
                      ? Color.lerp(palette.border, palette.primary, .48)!
                      : inline
                      ? palette.border
                      : palette.borderStrong,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.control),
                ),
                textStyle: inline
                    ? AppTypography.serverUseLabel
                    : AppTypography.serverGroupAction,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    selected ? LucideIcons.circleCheck : LucideIcons.zap,
                    size: inline ? 15 : 16,
                  ),
                  const SizedBox(width: 6),
                  Text(l.prototypeUse),
                  const SizedBox(width: 6),
                  Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      color: selected
                          ? palette.primarySolid
                          : palette.surfaceHover,
                    ),
                    child: Text(
                      '$count',
                      style:
                          (inline
                                  ? AppTypography.serverUseCount
                                  : AppTypography.serverGroupUseCount)
                              .copyWith(
                                color: selected
                                    ? palette.primaryForeground
                                    : palette.mutedStrong,
                              ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Tooltip(
      message: enabled
          ? l.prototypeUseEntryServers(count)
          : l.prototypeNotEnoughServers,
      child: OutlinedButton.icon(
        onPressed: choose,
        icon: Icon(selected ? LucideIcons.check : LucideIcons.network),
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
  final String? detail;
  final bool showDivider;
  const ServerNodeRow({
    super.key,
    required this.controller,
    required this.row,
    this.detail,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final running = controller.runningEntries.contains(row.id);
    final chosen = controller.chosen(row);
    final enabled = controller.canChoose(row);
    final colors = Theme.of(context).colorScheme;
    final protocol = controller.protocol(row);
    if (MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint) {
      return _mobileRow(
        context,
        running: running,
        chosen: chosen,
        enabled: enabled,
        protocol: protocol,
      );
    }
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
                    : () => controller.chooseRow(context, row),
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
                      if (controller.exitConflict(row))
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

  Widget _mobileRow(
    BuildContext context, {
    required bool running,
    required bool chosen,
    required bool enabled,
    required String protocol,
  }) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    final conflict = controller.exitConflict(row);
    final rowDetail = detail ?? controller.countryName(l, row.countryCode);
    return Container(
      foregroundDecoration: running
          ? BoxDecoration(
              border: BorderDirectional(
                start: BorderSide(color: palette.primary, width: 3),
              ),
            )
          : null,
      child: Material(
        color: running || chosen
            ? Color.lerp(palette.card, palette.selectedSurface, .72)
            : palette.card,
        child: Column(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 62),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 42,
                      child: Opacity(
                        opacity: enabled ? 1 : .65,
                        child: IconButton(
                          tooltip: row.favorite
                              ? l.prototypeRemoveFavorite
                              : l.prototypeAddFavorite,
                          onPressed: controller.busy
                              ? null
                              : () => controller.toggleFavorite(context, row),
                          isSelected: row.favorite,
                          style: IconButton.styleFrom(
                            foregroundColor: palette.restarting,
                            iconSize: 17,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(42, 42),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: const RoundedRectangleBorder(),
                          ),
                          icon: const Icon(LucideIcons.star),
                          selectedIcon: const Icon(LucideIcons.star600),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Opacity(
                        opacity: enabled ? 1 : .65,
                        child: Semantics(
                          selected: chosen,
                          child: InkWell(
                            onTap: controller.busy || conflict
                                ? null
                                : enabled
                                ? () => controller.chooseRow(context, row)
                                : () =>
                                      ServerMenu.open(context, controller, row),
                            child: Padding(
                              padding: const EdgeInsetsDirectional.fromSTEB(
                                0,
                                9,
                                4,
                                9,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    LucideIcons.server,
                                    size: 19,
                                    color: palette.foreground,
                                  ),
                                  const SizedBox(width: 11),
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          controller.serverName(row),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.serverNodeTitle
                                              .copyWith(
                                                color: palette.foreground,
                                              ),
                                        ),
                                        if (protocol.isNotEmpty) ...[
                                          const SizedBox(height: 3),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: palette.surfaceHover,
                                              border: Border.all(
                                                color: palette.border,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              protocol,
                                              textDirection: TextDirection.ltr,
                                              style: AppTypography
                                                  .serverProtocol
                                                  .copyWith(
                                                    color: palette.mutedStrong,
                                                  ),
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 3),
                                        Text(
                                          '$rowDetail · ${controller.health(l, row)}',
                                          style: AppTypography.metadata
                                              .copyWith(
                                                color: palette.mutedForeground,
                                              ),
                                        ),
                                        if (conflict) ...[
                                          const SizedBox(height: 3),
                                          Text(
                                            l.prototypeFinalExitEntryConflict,
                                            style: AppTypography.metadata
                                                .copyWith(
                                                  color:
                                                      palette.mutedForeground,
                                                ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 11),
                                  if (running)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          LucideIcons.circleCheck,
                                          size: 15,
                                          color: palette.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          l.prototypeConnected,
                                          style: AppTypography
                                              .serverConnectedBadge
                                              .copyWith(color: palette.primary),
                                        ),
                                      ],
                                    )
                                  else if (chosen)
                                    Icon(
                                      LucideIcons.circleCheck,
                                      size: 20,
                                      color: palette.running,
                                    )
                                  else
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
                    ),
                    SizedBox(
                      width: 42,
                      child: ServerMenu(controller: controller, row: row),
                    ),
                  ],
                ),
              ),
            ),
            if (showDivider)
              Divider(height: 1, thickness: 1, color: palette.border),
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

  static Future<void> open(
    BuildContext context,
    ServersController controller,
    CoreConfigData row,
  ) async {
    final l = AppLocalizations.of(context)!;
    final action = await showServerActionsMenu(
      context,
      name: controller.serverName(row),
      source: controller.sourceName(l, row),
    );
    if (context.mounted && action != null) {
      await controller.serverAction(context, row, action);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint) {
      return IconButton(
        tooltip: '${l.prototypeMoreActions}: ${controller.serverName(row)}',
        onPressed: controller.busy
            ? null
            : () => open(context, controller, row),
        style: IconButton.styleFrom(
          foregroundColor: ColorManager.palette(context).mutedStrong,
          iconSize: 18,
          padding: EdgeInsets.zero,
          minimumSize: const Size(42, 42),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: const RoundedRectangleBorder(),
        ),
        icon: const Icon(LucideIcons.ellipsis),
      );
    }
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

  static Future<void> open(
    BuildContext context,
    ServersController controller,
    SubscriptionData source,
  ) async {
    final action = await showSourceActionsMenu(
      context,
      name: source.name,
      count: controller.sourceCount(source.id),
    );
    if (context.mounted && action != null) {
      await controller.sourceAction(context, source, action);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint) {
      return IconButton(
        tooltip: '${l.prototypeMoreActions}: ${source.name}',
        onPressed: controller.busy
            ? null
            : () => open(context, controller, source),
        style: IconButton.styleFrom(
          foregroundColor: ColorManager.palette(context).mutedStrong,
          iconSize: 18,
          padding: EdgeInsets.zero,
          minimumSize: const Size(36, 42),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: const RoundedRectangleBorder(),
        ),
        icon: const Icon(LucideIcons.ellipsis),
      );
    }
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
