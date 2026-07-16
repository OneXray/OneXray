import 'package:flutter/material.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:onexray/core/db/dao/config_query.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/pages/home/component/subscription_row/controller.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/pages/subscriptions/nodes/params.dart';
import 'package:onexray/service/ping/service.dart';
import 'package:onexray/pages/main/navigation.dart';

class SubscriptionListController extends PageCubit<void> {
  SubscriptionListController()
    : rowsStream = AppDatabase().coreConfigDao.allOutboundRowsStream().map(
        (rows) => rows
            .whereType<SubscriptionItem>()
            .where((item) => item.subscription.id > DBConstants.defaultId)
            .toList(),
      ),
      super(null);

  final Stream<List<SubscriptionItem>> rowsStream;
  final _rowController = SubscriptionRowController();

  void addSubscription(BuildContext context) {
    context.pushScoped(AppSecondaryDestination.subscriptionAdd);
  }

  void openNodes(BuildContext context, int subId) {
    final params = SubscriptionNodesParams(subId: subId);
    context.pushScoped(
      AppSecondaryDestination.subscriptionNodes,
      extra: params,
    );
  }

  Future<void> ping(int subId) async {
    await PingService().pingOutboundConfigs(subId);
  }

  Future<void> moreAction(
    BuildContext context,
    SubscriptionData data,
    IconMenuId menuId,
  ) async {
    await _rowController.moreAction(context, data, menuId);
  }
}
