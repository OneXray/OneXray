import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/connect/controller.dart';
import 'package:onexray/pages/routing/widgets.dart';
import 'package:onexray/pages/servers/controller.dart';
import 'package:onexray/pages/servers/page.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/pages/widget/page_action_bar.dart';
import 'package:onexray/pages/widget/responsive_content.dart';

class ServerExitPickerPage extends StatefulWidget {
  const ServerExitPickerPage({super.key, required this.params});

  final ServerExitPickerParams params;

  @override
  State<ServerExitPickerPage> createState() => _ServerExitPickerPageState();
}

class _ServerExitPickerPageState extends State<ServerExitPickerPage> {
  late final controller = ServerExitPickerController(widget.params);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) controller.initialize(context, services: false);
    });
  }

  @override
  void dispose() {
    unawaited(controller.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ServerExitPickerView(controller: controller);
}

class ServerExitPickerView extends StatelessWidget {
  const ServerExitPickerView({super.key, required this.controller});

  final ServerExitPickerController controller;

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: controller,
    child: BlocBuilder<ServerExitPickerController, ConnectPageState>(
      builder: (context, _) {
        final l = AppLocalizations.of(context)!;
        final palette = ColorManager.palette(context);
        final mobile =
            MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint;
        final groups = controller.selectionGroups(l);
        return Scaffold(
          appBar: AppBar(title: Text(l.prototypeVpnFinalExit)),
          body: SafeArea(
            child: ServerLoadState(
              controller: controller,
              child: ResponsiveContent(
                desktopMaxWidth:
                    AppLayout.routingEditorMaxWidth + AppSpacing.page * 2,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    mobile ? AppSpacing.mobilePage : AppSpacing.page,
                    mobile ? 12 : AppSpacing.desktopPageTop,
                    mobile ? AppSpacing.mobilePage : AppSpacing.page,
                    mobile ? 18 : AppSpacing.desktopPageBottom,
                  ),
                  children: [
                    RoutingCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SelectionRow(
                            icon: LucideIcons.shield,
                            title: l.prototypeNoAdditionalExit,
                            detail: l.prototypeEntryConnectsDirectly,
                            selected: controller.selectedId == null,
                            onTap: controller.busy
                                ? null
                                : () => controller.selectDraft(null),
                          ),
                          _search(context, mobile),
                          _grouping(context, mobile),
                          for (final group in groups) ...[
                            Container(
                              padding: const EdgeInsets.fromLTRB(14, 10, 14, 7),
                              color: palette.muted,
                              child: Text(
                                group.name.toUpperCase(),
                                style: AppTypography.routingSelectionGroup
                                    .copyWith(color: palette.mutedForeground),
                              ),
                            ),
                            for (final row in group.visibleRows)
                              _SelectionRow(
                                key: ValueKey('final-exit:${row.id}'),
                                icon: LucideIcons.server,
                                title: controller.serverName(row),
                                detail: controller.exitRowDetail(l, row),
                                protocol: controller.protocol(row),
                                selected: controller.selectedId == row.id,
                                onTap:
                                    controller.busy ||
                                        !controller.canSelect(row)
                                    ? null
                                    : () => controller.selectDraft(row),
                              ),
                          ],
                          if (groups.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 28,
                              ),
                              child: Text(
                                l.prototypeNoMatchingServers,
                                textAlign: TextAlign.center,
                                style: AppTypography.routingSelectionInput
                                    .copyWith(color: palette.mutedForeground),
                              ),
                            ),
                          Container(
                            constraints: const BoxConstraints(minHeight: 52),
                            padding: EdgeInsets.symmetric(
                              horizontal: mobile ? 12 : 14,
                              vertical: 10,
                            ),
                            color: palette.muted,
                            child: Row(
                              children: [
                                Icon(
                                  LucideIcons.info,
                                  size: 17,
                                  color: palette.mutedForeground,
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    l.prototypeFinalExitSelectionNote,
                                    style: AppTypography.routingSelectionNote
                                        .copyWith(
                                          color: palette.mutedForeground,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          bottomNavigationBar: PageActionBar(
            maxWidth: AppLayout.routingEditorMaxWidth,
            children: [
              if (!mobile)
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l.prototypeCancel),
                ),
              FilledButton(
                onPressed: controller.canFinish
                    ? () => controller.complete(context)
                    : null,
                child: Text(l.prototypeDone),
              ),
            ],
          ),
        );
      },
    ),
  );

  Widget _search(BuildContext context, bool mobile) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    return Container(
      constraints: BoxConstraints(minHeight: mobile ? 54 : 58),
      padding: EdgeInsets.symmetric(horizontal: mobile ? 12 : 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.search, size: 18, color: palette.mutedForeground),
          const SizedBox(width: 10),
          Expanded(
            child: RoutingSearchField(
              label: l.prototypeSearchServers,
              hint: l.prototypeSearchSubscriptionsServers,
              controller: controller.search,
              onChanged: controller.searchChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _grouping(BuildContext context, bool mobile) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    final control = Container(
      width: mobile ? double.infinity : null,
      margin: EdgeInsets.symmetric(horizontal: mobile ? 12 : 14, vertical: 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: SizedBox(
        height: 41,
        child: Row(
          children: [
            for (final grouping in ServerGrouping.values)
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 112),
                  child: Semantics(
                    button: true,
                    selected: controller.grouping == grouping,
                    child: Material(
                      color: controller.grouping == grouping
                          ? palette.selectedSurface
                          : palette.card,
                      child: InkWell(
                        onTap: () => controller.groupBy(grouping),
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 13),
                          foregroundDecoration: BoxDecoration(
                            border: controller.grouping == grouping
                                ? Border.all(color: palette.primary)
                                : grouping == ServerGrouping.location
                                ? BorderDirectional(
                                    end: BorderSide(color: palette.border),
                                  )
                                : null,
                          ),
                          child: Text(
                            grouping == ServerGrouping.location
                                ? l.prototypeByNodeLocation
                                : l.prototypeBySubscription,
                            style: AppTypography.subscriptionField.copyWith(
                              color: controller.grouping == grouping
                                  ? palette.primary
                                  : palette.mutedStrong,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: mobile ? control : IntrinsicWidth(child: control),
    );
  }
}

class _SelectionRow extends StatelessWidget {
  const _SelectionRow({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    required this.selected,
    this.protocol,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final bool selected;
  final String? protocol;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = ColorManager.palette(context);
    final mobile =
        MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint;
    return Opacity(
      opacity: onTap == null ? .48 : 1,
      child: Semantics(
        button: true,
        selected: selected,
        enabled: onTap != null,
        child: Material(
          color: selected ? palette.selectedSurface : palette.card,
          child: InkWell(
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 62),
              padding: EdgeInsets.symmetric(
                horizontal: mobile ? 12 : 14,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: palette.border)),
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: icon == LucideIcons.shield ? 20 : 19,
                    color: palette.mutedStrong,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: AppTypography.routingSelectionTitle.copyWith(
                            color: palette.foreground,
                          ),
                        ),
                        if (protocol != null && protocol!.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: palette.surfaceHover,
                              border: Border.all(color: palette.border),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              protocol!,
                              textDirection: TextDirection.ltr,
                              style: AppTypography.serverProtocol.copyWith(
                                color: palette.mutedStrong,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 3),
                        Text(
                          detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.routingSelectionDescription
                              .copyWith(color: palette.mutedForeground),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 11),
                  Icon(
                    selected ? LucideIcons.check : LucideIcons.circle,
                    size: selected ? 19 : 18,
                    color: palette.primary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
