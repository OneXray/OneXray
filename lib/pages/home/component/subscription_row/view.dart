import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/db/dao/config_query.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/pages/home/component/subscription_row/controller.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/widget/date_view.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/event_bus/state.dart';

class SubscriptionRowView extends StatelessWidget {
  final SubscriptionItem item;
  final VoidCallback? pingCallback;
  final VoidCallback? expandCallback;

  const SubscriptionRowView({
    super.key,
    required this.item,
    required this.pingCallback,
    required this.expandCallback,
  });

  static final _controller = SubscriptionRowController();

  @override
  Widget build(BuildContext context) {
    return _body(context, _controller);
  }

  Widget _body(BuildContext context, SubscriptionRowController controller) {
    if (expandCallback != null) {
      return InkWell(
        onTap: () =>
            controller.updateExpanded(item.subscription, expandCallback!),
        child: _content(context, controller),
      );
    } else {
      return _content(context, controller);
    }
  }

  Widget _content(BuildContext context, SubscriptionRowController controller) {
    final expandIcon = item.subscription.expanded
        ? Icons.expand_less
        : Icons.expand_more;
    return Container(
      padding: EdgeInsetsDirectional.symmetric(vertical: 12, horizontal: 16),
      color: ColorManager.surface(context),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${item.subscription.name} (${item.count})",
                  style: TextStyle(
                    fontSize: 15,
                    color: ColorManager.primaryText(context),
                  ),
                ),
                if (item.subscription.id > DBConstants.defaultId)
                  DateView(date: item.subscription.timestamp),
              ],
            ),
          ),
          if (pingCallback != null)
            BlocBuilder<AppEventBus, AppEventBusState>(
              buildWhen: (prev, curr) => prev.pinging != curr.pinging,
              builder: (context, state) =>
                  _pingButton(context, controller, item.subscription, state),
            ),
          if (item.subscription.id > DBConstants.defaultId)
            IconMenuPicker(
              icon: Icons.more_vert,
              menus: [
                IconMenuId.refresh,
                IconMenuId.share,
                IconMenuId.edit,
                IconMenuId.delete,
                IconMenuId.clean,
              ],
              callback: (menuId) =>
                  controller.moreAction(context, item.subscription, menuId),
            )
          else
            IconMenuPicker(
              icon: Icons.more_vert,
              menus: [IconMenuId.clean],
              callback: (menuId) =>
                  controller.moreAction(context, item.subscription, menuId),
            ),
          if (expandCallback != null) Icon(expandIcon),
        ],
      ),
    );
  }

  Widget _pingButton(
    BuildContext context,
    SubscriptionRowController controller,
    SubscriptionData data,
    AppEventBusState state,
  ) {
    if (state.pinging) {
      return const CircularProgressIndicator();
    } else {
      return IconButton(
        onPressed: () => pingCallback?.call(),
        icon: const Icon(Icons.speed),
      );
    }
  }
}
