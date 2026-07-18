import 'package:flutter/material.dart';
import 'package:onexray/core/db/dao/config_query.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/widget/data_list.dart';
import 'package:onexray/pages/widget/date_view.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class SubscriptionListView extends StatelessWidget {
  const SubscriptionListView({
    super.key,
    required this.items,
    required this.emptyMessage,
    required this.addLabel,
    required this.pingLabel,
    required this.pinging,
    required this.onAdd,
    required this.onOpen,
    required this.onPing,
    required this.onAction,
  });

  final List<SubscriptionItem> items;
  final String emptyMessage;
  final String addLabel;
  final String pingLabel;
  final bool pinging;
  final VoidCallback onAdd;
  final ValueChanged<SubscriptionData> onOpen;
  final ValueChanged<SubscriptionData> onPing;
  final void Function(SubscriptionData, IconMenuId) onAction;

  @override
  Widget build(BuildContext context) {
    return ResponsiveContent(
      desktopMaxWidth: 940,
      child: items.isEmpty
          ? ListEmptyView(
              message: emptyMessage,
              icon: LucideIcons.rss,
              actionLabel: addLabel,
              actionIcon: LucideIcons.plus,
              onAction: onAdd,
            )
          : ListView.separated(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 18, 16, 28),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _SubscriptionListCard(
                item: items[index],
                pingLabel: pingLabel,
                pinging: pinging,
                onOpen: onOpen,
                onPing: onPing,
                onAction: onAction,
              ),
            ),
    );
  }
}

class _SubscriptionListCard extends StatelessWidget {
  const _SubscriptionListCard({
    required this.item,
    required this.pingLabel,
    required this.pinging,
    required this.onOpen,
    required this.onPing,
    required this.onAction,
  });

  final SubscriptionItem item;
  final String pingLabel;
  final bool pinging;
  final ValueChanged<SubscriptionData> onOpen;
  final ValueChanged<SubscriptionData> onPing;
  final void Function(SubscriptionData, IconMenuId) onAction;

  @override
  Widget build(BuildContext context) {
    final data = item.subscription;
    final radius = BorderRadius.circular(8);
    return ShadCard(
      width: double.infinity,
      padding: EdgeInsets.zero,
      radius: radius,
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 62),
        child: Row(
          children: [
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: radius,
                  onTap: () => onOpen(data),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      15,
                      10,
                      8,
                      10,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.rowTitle.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: ColorManager.primaryText(context),
                                ),
                              ),
                              DateView(date: data.timestamp),
                            ],
                          ),
                        ),
                        const SizedBox(width: 9),
                        ShadBadge.secondary(
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          child: Text(
                            "${item.count}",
                            style: AppTypography.badge,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: pingLabel,
                    child: ShadIconButton.ghost(
                      icon: pinging
                          ? const SizedBox.square(
                              dimension: 15,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(LucideIcons.gauge),
                      width: 36,
                      height: 36,
                      iconSize: 17,
                      onPressed: pinging ? null : () => onPing(data),
                    ),
                  ),
                  AppMenuButton<IconMenuId>(
                    triggerBuilder: (toggleMenu) => ShadIconButton.ghost(
                      icon: const Icon(LucideIcons.ellipsis),
                      width: 36,
                      height: 36,
                      iconSize: 18,
                      onPressed: toggleMenu,
                    ),
                    entries:
                        const [
                            IconMenuId.refresh,
                            IconMenuId.share,
                            IconMenuId.edit,
                            IconMenuId.delete,
                          ].map((menu) => menu.menuEntry).toList()
                          ..add(const AppMenuEntry<IconMenuId>.separator())
                          ..add(IconMenuId.clean.menuEntry),
                    onSelected: (menuId) => onAction(data, menuId),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
