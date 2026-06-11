import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/db/dao/config_query.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/pages/home/component/subscription_row/controller.dart';
import 'package:onexray/pages/widget/data_list.dart';
import 'package:onexray/pages/widget/date_view.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/pages/widget/tag_view.dart';
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
    return _content(context, controller);
  }

  Widget _content(BuildContext context, SubscriptionRowController controller) {
    final expandIcon = item.subscription.expanded
        ? Icons.expand_less
        : Icons.expand_more;
    return DataListRow(
      title: item.subscription.name,
      tags: [TagView(tag: "${item.count}")],
      meta: item.subscription.id > DBConstants.defaultId
          ? DateView(date: item.subscription.timestamp)
          : null,
      onTap: expandCallback == null
          ? null
          : () => controller.updateExpanded(item.subscription, expandCallback!),
      trailing: ActionCluster(
        children: [
          if (pingCallback != null)
            BlocBuilder<AppEventBus, AppEventBusState>(
              buildWhen: (prev, curr) => prev.pinging != curr.pinging,
              builder: (context, state) =>
                  _pingButton(context, controller, item.subscription, state),
            ),
          _moreMenu(context, controller),
          if (expandCallback != null) Icon(expandIcon),
        ],
      ),
    );
  }

  Widget _moreMenu(BuildContext context, SubscriptionRowController controller) {
    if (item.subscription.id > DBConstants.defaultId) {
      return IconMenuPicker(
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
      );
    }
    return IconMenuPicker(
      icon: Icons.more_vert,
      menus: [IconMenuId.clean],
      callback: (menuId) =>
          controller.moreAction(context, item.subscription, menuId),
    );
  }

  Widget _pingButton(
    BuildContext context,
    SubscriptionRowController controller,
    SubscriptionData data,
    AppEventBusState state,
  ) {
    if (state.pinging) {
      return const SizedBox.square(
        dimension: 48,
        child: Center(
          child: SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(),
          ),
        ),
      );
    } else {
      return IconButton(
        onPressed: () => pingCallback?.call(),
        icon: const Icon(Icons.speed),
      );
    }
  }
}
