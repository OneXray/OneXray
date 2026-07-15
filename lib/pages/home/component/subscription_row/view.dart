import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/db/dao/config_query.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/home/component/subscription_row/controller.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/event_bus/state.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class SubscriptionRowView extends StatelessWidget {
  const SubscriptionRowView({
    super.key,
    required this.item,
    required this.pingCallback,
    required this.expandCallback,
    this.tapCallback,
    this.cleanCallback,
  });

  static final _controller = SubscriptionRowController();

  final SubscriptionItem item;
  final VoidCallback? pingCallback;
  final VoidCallback? expandCallback;
  final VoidCallback? tapCallback;
  final Future<void> Function(SubscriptionData data)? cleanCallback;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 12, 4),
      child: LayoutBuilder(
        builder: (context, constraints) => ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              Expanded(child: _toggleArea(context)),
              const SizedBox(width: 4),
              BlocBuilder<AppEventBus, AppEventBusState>(
                buildWhen: (previous, current) =>
                    previous.pinging != current.pinging,
                builder: (context, state) => _actions(
                  context,
                  state,
                  compact: constraints.maxWidth < 560,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toggleArea(BuildContext context) {
    final callback =
        tapCallback ?? (expandCallback == null ? null : _toggleExpanded);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: callback,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
            child: Row(
              children: [
                if (expandCallback != null) ...[
                  AnimatedRotation(
                    turns: item.subscription.expanded ? 0 : -0.25,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      LucideIcons.chevronDown,
                      size: 17,
                      color: ColorManager.secondaryText(context),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    item.subscription.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.rowTitle.copyWith(
                      color: ColorManager.primaryText(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                ShadBadge.secondary(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  child: Text('${item.count}', style: AppTypography.badge),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _toggleExpanded() {
    final callback = expandCallback;
    if (callback == null) {
      return;
    }
    _controller.updateExpanded(item.subscription, callback);
  }

  Widget _actions(
    BuildContext context,
    AppEventBusState state, {
    required bool compact,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (pingCallback != null) ...[
          _pingButton(context, state, compact: compact),
          const SizedBox(width: 2),
        ],
        _moreMenu(context, disabled: state.pinging),
      ],
    );
  }

  Widget _pingButton(
    BuildContext context,
    AppEventBusState state, {
    required bool compact,
  }) {
    final loading = const SizedBox.square(
      dimension: 15,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
    if (!compact) {
      return ShadButton.ghost(
        height: 40,
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 10),
        leading: state.pinging ? loading : const Icon(LucideIcons.gauge),
        onPressed: state.pinging ? null : pingCallback,
        child: Text(AppLocalizations.of(context)!.pingPageTitle),
      );
    }
    return Tooltip(
      message: AppLocalizations.of(context)!.pingPageTitle,
      child: ShadIconButton.ghost(
        icon: state.pinging ? loading : const Icon(LucideIcons.gauge),
        width: 40,
        height: 40,
        iconSize: 16,
        onPressed: state.pinging ? null : pingCallback,
      ),
    );
  }

  Widget _moreMenu(BuildContext context, {required bool disabled}) {
    final menus = item.subscription.id > DBConstants.defaultId
        ? const [
            IconMenuId.refresh,
            IconMenuId.share,
            IconMenuId.edit,
            IconMenuId.delete,
            IconMenuId.clean,
          ]
        : const [IconMenuId.clean];
    return AppMenuButton<IconMenuId>(
      triggerBuilder: (toggleMenu) => Tooltip(
        message: AppLocalizations.of(context)!.homePageSubscriptionActions,
        child: ShadIconButton.ghost(
          icon: const Icon(LucideIcons.ellipsis),
          width: 40,
          height: 40,
          iconSize: 17,
          onPressed: disabled ? null : toggleMenu,
        ),
      ),
      entries: iconMenuEntries(menus),
      onSelected: (menuId) => _controller.moreAction(
        context,
        item.subscription,
        menuId,
        cleanCallback: cleanCallback,
      ),
    );
  }
}
