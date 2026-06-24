import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/db/dao/config_query.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/pages/subscriptions/nodes/params.dart';
import 'package:onexray/service/ping/service.dart';
import 'package:onexray/pages/main/navigation.dart';

class SubscriptionListController extends Cubit<void> {
  SubscriptionListController()
    : rowsStream = AppDatabase().coreConfigDao.allOutboundRowsStream(),
      super(null);

  final Stream<List<ConfigQueryRow>> rowsStream;

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
}
